/**
 * BidStream — Pagos con Mercado Pago (escrow completo).
 *
 * Flujo:
 *  1. Depósito de garantía: el postor paga un depósito fijo (DEPOSIT_AMOUNT)
 *     antes de poder pujar. Se retiene en la cuenta de la plataforma.
 *  2. Pago del ganador: al cerrar la subasta se genera una preferencia de
 *     cobro por (precio final − depósito). Tiene WINNER_PAYMENT_WINDOW_HOURS
 *     horas para pagar.
 *  3. Liquidación: cuando el pago del ganador se aprueba (webhook), el lote
 *     queda 'paid', el depósito queda 'applied' y se crea un payout 'ready'
 *     al vendedor por (precio final − comisión).
 *  4. Castigo: si el ganador no paga a tiempo, su depósito se transfiere al
 *     vendedor como compensación y el usuario acumula strikes (2 = baneo).
 *  5. Reembolso: el postor puede pedir el reembolso de su depósito si no
 *     está ganando ninguna subasta activa ni debe pagos pendientes.
 *
 * Variables de entorno (functions/.env):
 *   MP_ACCESS_TOKEN         token de producción o pruebas de Mercado Pago
 *   MP_WEBHOOK_SECRET       secreto configurado en el panel de MP (webhooks)
 *   WEBHOOK_URL             URL pública de mpWebhook
 *   SITE_URL                URL de la app web (para back_urls)
 *   DEPOSIT_AMOUNT          monto del depósito en MXN (default 200)
 *   COMMISSION_PCT          comisión de la plataforma 0-1 (default 0.10)
 *   WINNER_PAYMENT_WINDOW_HOURS  horas para que el ganador pague (default 24)
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { MercadoPagoConfig, Preference, Payment } = require("mercadopago");

// En producción index.js ya inicializó la app; este guarda permite cargar
// el módulo de forma aislada (p. ej. en pruebas) sin romper.
if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const REGION = "us-central1";

const DEPOSIT_AMOUNT = Number(process.env.DEPOSIT_AMOUNT || 200);
const COMMISSION_PCT = Number(process.env.COMMISSION_PCT || 0.10);
const WINNER_PAYMENT_WINDOW_HOURS = Number(process.env.WINNER_PAYMENT_WINDOW_HOURS || 24);
const SITE_URL = process.env.SITE_URL || "https://bidstream.web.app";
const WEBHOOK_URL = process.env.WEBHOOK_URL || "";

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

function mpClient() {
  const token = process.env.MP_ACCESS_TOKEN;
  if (!token) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Mercado Pago no está configurado en el servidor."
    );
  }
  return new MercadoPagoConfig({ accessToken: token });
}

function money(n) {
  return `$${Number(n).toLocaleString("es-MX", { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
}

// ---------------------------------------------------------------------
// Validación de firma del webhook (pure, para poder probarla).
// MP manda cabeceras: x-signature: "ts=...,v1=..." y x-request-id.
// El HMAC se calcula sobre: id:{data.id};request-id:{x-request-id};ts:{ts};
// ---------------------------------------------------------------------
function validateMpSignature({ xSignature, xRequestId, dataId, secret }) {
  if (!xSignature || !xRequestId || !secret || !dataId) return false;
  const parts = {};
  for (const pair of String(xSignature).split(",")) {
    const idx = pair.indexOf("=");
    if (idx > 0) parts[pair.slice(0, idx).trim()] = pair.slice(idx + 1).trim();
  }
  if (!parts.ts || !parts.v1) return false;
  const manifest = `id:${dataId};request-id:${xRequestId};ts:${parts.ts};`;
  const expected = crypto.createHmac("sha256", secret).update(manifest).digest("hex");
  try {
    return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(parts.v1));
  } catch (_) {
    return false;
  }
}

async function createPreference({ email, title, amount, externalReference }) {
  const preference = new Preference(mpClient());
  const res = await preference.create({
    body: {
      items: [
        {
          id: externalReference,
          title,
          quantity: 1,
          currency_id: "MXN",
          unit_price: round2(amount),
        },
      ],
      payer: { email: email || undefined },
      external_reference: externalReference,
      binary_mode: true,
      statement_descriptor: "BIDSTREAM",
      notification_url: WEBHOOK_URL || undefined,
      back_urls: {
        success: `${SITE_URL}/#/deposito`,
        pending: `${SITE_URL}/#/deposito`,
        failure: `${SITE_URL}/#/deposito`,
      },
      auto_return: "approved",
    },
  });
  return res;
}

async function recordPayment(data) {
  const ref = await db.collection("payments").add({
    ...data,
    created_time: FieldValue.serverTimestamp(),
    updated_time: FieldValue.serverTimestamp(),
  });
  return ref.id;
}

async function updatePaymentByMpId(mpPaymentId, patch) {
  const snap = await db
    .collection("payments")
    .where("mp_payment_id", "==", mpPaymentId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  await snap.docs[0].ref.update({ ...patch, updated_time: FieldValue.serverTimestamp() });
  return snap.docs[0];
}

function notificationRef(uid) {
  return db.collection("users").doc(uid).collection("notifications").doc();
}

// ---------------------------------------------------------------------
// createDeposit — el postor genera su depósito de garantía.
// Devuelve { initPoint, amount } para abrir el checkout de MP.
// ---------------------------------------------------------------------
exports.createDeposit = functions.region(REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
  }
  if (context.auth.token.email_verified !== true) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Verifica tu correo electrónico antes de continuar."
    );
  }
  const uid = context.auth.uid;
  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || !user.full_name || !user.phone || user.accepted_terms !== true) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Completa tu perfil (nombre, teléfono y términos) antes de continuar."
    );
  }
  if (user.banned === true) {
    throw new functions.https.HttpsError("permission-denied", "Tu cuenta está suspendida.");
  }
  if (user.deposit && user.deposit.status === "held") {
    throw new functions.https.HttpsError("already-exists", "Ya tienes un depósito en garantía.");
  }

  const pref = await createPreference({
    email: user.email,
    title: "Depósito de garantía para pujar — BidStream",
    amount: DEPOSIT_AMOUNT,
    externalReference: `deposit:${uid}`,
  });

  await recordPayment({
    kind: "deposit",
    uid,
    amount: DEPOSIT_AMOUNT,
    currency: "MXN",
    status: "pending",
    mp_preference_id: pref.id,
    mp_payment_id: null,
  });

  return { initPoint: pref.init_point, amount: DEPOSIT_AMOUNT };
});

// ---------------------------------------------------------------------
// startWinnerPayment — la llama closeLot al cerrar una subasta con
// ganador. Genera la preferencia de cobro por (precio final − depósito)
// y marca el lote como 'payment_status: pending' con fecha límite.
// Si el depósito cubre todo el precio, liquida de inmediato.
// ---------------------------------------------------------------------
async function startWinnerPayment(lotRef, lot, winnerUid, winner) {
  const finalPrice = round2(Number(lot.current_bid) || 0);
  const deposit =
    winner.deposit && winner.deposit.status === "held"
      ? round2(Number(winner.deposit.amount) || 0)
      : 0;
  const remaining = round2(finalPrice - deposit);
  const dueTime = Timestamp.fromMillis(
    Date.now() + WINNER_PAYMENT_WINDOW_HOURS * 3600 * 1000
  );

  if (remaining <= 0) {
    // El depósito cubre el precio completo: no hay nada que cobrar.
    await db.collection("users").doc(winnerUid).update({
      "deposit.status": "applied",
      "deposit.updated_time": FieldValue.serverTimestamp(),
    });
    await lotRef.update({ payment_status: "paid", payment_due_time: null });
    await settlePaidLot(lotRef.id, lot);
    return { url: null, amount: 0, alreadySettled: true };
  }

  const pref = await createPreference({
    email: winner.email,
    title: `Pago de subasta ganada: ${lot.title}`,
    amount: remaining,
    externalReference: `win:${lotRef.id}:${winnerUid}`,
  });

  await recordPayment({
    kind: "winner_payment",
    uid: winnerUid,
    lot_id: lotRef.id,
    amount: remaining,
    currency: "MXN",
    status: "pending",
    mp_preference_id: pref.id,
    mp_payment_id: null,
  });

  await lotRef.update({
    payment_status: "pending",
    winner_payment_url: pref.init_point,
    payment_due_time: dueTime,
  });

  return { url: pref.init_point, amount: remaining, alreadySettled: false };
}

// ---------------------------------------------------------------------
// settlePaidLot — el ganador pagó: marca el lote, aplica el depósito y
// crea el payout al vendedor (precio final − comisión). Avisa a ambos.
// ---------------------------------------------------------------------
async function settlePaidLot(lotId, lot) {
  const finalPrice = round2(Number(lot.current_bid) || 0);
  const commission = round2(finalPrice * COMMISSION_PCT);
  const sellerAmount = round2(finalPrice - commission);
  const batch = db.batch();

  batch.set(db.collection("payments").doc(), {
    kind: "payout",
    uid: lot.seller_uid,
    lot_id: lotId,
    amount: sellerAmount,
    commission,
    currency: "MXN",
    status: "ready", // la transferencia al vendedor se hace desde el panel de MP
    note: "Transferir manualmente o vía Transfers API; marcar 'sent' al pagar.",
    created_time: FieldValue.serverTimestamp(),
    updated_time: FieldValue.serverTimestamp(),
  });

  batch.set(notificationRef(lot.seller_uid), {
    type: "paid",
    title: `¡Cobrada! ${lot.title}`,
    body: `Recibimos ${money(finalPrice)}. Te transferiremos ${money(sellerAmount)} (comisión ${money(commission)}). Coordina la entrega con el comprador.`,
    lot_id: lotId,
    read: false,
    created_time: FieldValue.serverTimestamp(),
  });

  if (lot.winner_uid) {
    batch.set(notificationRef(lot.winner_uid), {
      type: "payment_confirmed",
      title: `Pago confirmado: ${lot.title}`,
      body: `Tu pago quedó registrado. Contacta al vendedor para coordinar la entrega.`,
      lot_id: lotId,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
}

// ---------------------------------------------------------------------
// forfeitWin — el ganador no pagó a tiempo: su depósito se transfiere al
// vendedor como compensación y el usuario suma un strike (2 = baneo).
// ---------------------------------------------------------------------
async function forfeitWin(lotRef) {
  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(lotRef);
    if (!snap.exists) return null;
    const lot = snap.data();
    if (lot.status !== "ended" || lot.payment_status !== "pending") return null;
    if (lot.payment_due_time && lot.payment_due_time.toMillis() > Date.now()) return null;

    tx.update(lotRef, { payment_status: "forfeited", winner_payment_url: null });

    const winnerRef = db.collection("users").doc(lot.winner_uid);
    const winnerSnap = await tx.get(winnerRef);
    const winner = winnerSnap.exists ? winnerSnap.data() : {};
    const depositAmount = winner.deposit
      ? round2(Number(winner.deposit.amount) || 0)
      : 0;
    const strikes = (winner.strikes || 0) + 1;

    tx.update(winnerRef, {
      "deposit.status": "forfeited",
      "deposit.updated_time": FieldValue.serverTimestamp(),
      strikes,
      ...(strikes >= 2 ? { banned: true } : {}),
    });

    tx.set(db.collection("payments").doc(), {
      kind: "payout",
      reason: "deposit_forfeit",
      uid: lot.seller_uid,
      lot_id: lotRef.id,
      amount: depositAmount,
      currency: "MXN",
      status: "ready",
      note: "Depósito del ganador incumplido; transferir al vendedor como compensación.",
      created_time: FieldValue.serverTimestamp(),
      updated_time: FieldValue.serverTimestamp(),
    });

    return { lot, depositAmount, strikes };
  });

  if (!outcome) return false;

  const { lot, depositAmount, strikes } = outcome;
  const batch = db.batch();
  batch.set(notificationRef(lot.seller_uid), {
    type: "win_unpaid",
    title: `El ganador no pagó: ${lot.title}`,
    body: `Su depósito de ${money(depositAmount)} se te transfiere como compensación. Puedes republicar el lote.`,
    lot_id: lotRef.id,
    read: false,
    created_time: FieldValue.serverTimestamp(),
  });
  batch.set(notificationRef(lot.winner_uid), {
    type: "strike",
    title: "No completaste tu pago",
    body: `Perdiste la subasta "${lot.title}" y tu depósito de ${money(depositAmount)} se transfirió al vendedor. ${
      strikes >= 2 ? "Tu cuenta fue suspendida." : "Otro incumplimiento suspenderá tu cuenta."
    }`,
    lot_id: lotRef.id,
    read: false,
    created_time: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return true;
}

// ---------------------------------------------------------------------
// expireUnpaidWins — cada hora castiga las subastas ganadas no pagadas.
// ---------------------------------------------------------------------
exports.expireUnpaidWins = functions
  .region(REGION)
  .pubsub.schedule("every 60 minutes")
  .onRun(async () => {
    const snap = await db
      .collection("lots")
      .where("status", "==", "ended")
      .where("payment_status", "==", "pending")
      .where("payment_due_time", "<=", Timestamp.now())
      .limit(100)
      .get();
    let forfeited = 0;
    for (const doc of snap.docs) {
      try {
        if (await forfeitWin(doc.ref)) forfeited++;
      } catch (err) {
        functions.logger.error(`No se pudo castigar ${doc.id}`, err);
      }
    }
    functions.logger.info(`Subastas incumplidas castigadas: ${forfeited}`);
    return null;
  });

// ---------------------------------------------------------------------
// requestDepositRefund — el postor pide reembolso. Solo se permite si no
// está ganando ninguna subasta activa ni tiene pagos pendientes.
// ---------------------------------------------------------------------
exports.requestDepositRefund = functions.region(REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
  }
  const uid = context.auth.uid;

  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || !user.deposit || user.deposit.status !== "held" || !user.deposit.mp_payment_id) {
    throw new functions.https.HttpsError("failed-precondition", "No tienes un depósito reembolsable.");
  }

  // ¿Va ganando algo ahora mismo?
  const winning = await db
    .collection("lots")
    .where("highest_bidder_uid", "==", uid)
    .limit(20)
    .get();
  if (winning.docs.some((d) => d.data().status === "active")) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Estás ganando una subasta activa. Pierde la puja o espera a que termine antes de pedir el reembolso."
    );
  }

  // ¿Debe un pago de ganador pendiente?
  const pendingWins = await db
    .collection("lots")
    .where("winner_uid", "==", uid)
    .limit(20)
    .get();
  if (pendingWins.docs.some((d) => d.data().payment_status === "pending")) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Tienes un pago pendiente de una subasta ganada. Complétalo o espera a que venza."
    );
  }

  // Idempotencia: si ya hay un reembolso en proceso, no repetir.
  const existing = await db
    .collection("payments")
    .where("mp_payment_id", "==", user.deposit.mp_payment_id)
    .where("kind", "==", "refund")
    .limit(1)
    .get();
  if (!existing.empty) {
    throw new functions.https.HttpsError("already-exists", "Tu reembolso ya está en proceso.");
  }

  try {
    await new Payment(mpClient()).refund({ id: user.deposit.mp_payment_id });
  } catch (err) {
    functions.logger.error("Reembolso rechazado por MP", err);
    throw new functions.https.HttpsError("internal", "Mercado Pago rechazó el reembolso. Intenta más tarde o contacta a soporte.");
  }

  const batch = db.batch();
  batch.update(db.collection("users").doc(uid), {
    "deposit.status": "refunded",
    "deposit.updated_time": FieldValue.serverTimestamp(),
  });
  batch.set(db.collection("payments").doc(), {
    kind: "refund",
    uid,
    amount: user.deposit.amount,
    currency: "MXN",
    status: "approved",
    mp_payment_id: user.deposit.mp_payment_id,
    created_time: FieldValue.serverTimestamp(),
    updated_time: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { ok: true, amount: user.deposit.amount };
});

// ---------------------------------------------------------------------
// mpWebhook — notificaciones de Mercado Pago. Valida la firma, y según
// el external_reference aplica el depósito o liquida la subasta ganada.
// ---------------------------------------------------------------------
async function handlePaymentNotification(paymentId) {
  const payment = await new Payment(mpClient()).get({ id: paymentId });
  const status = payment.status; // approved | rejected | ...
  const externalReference = payment.external_reference || "";
  const amount = round2(Number(payment.transaction_amount) || 0);

  if (externalReference.startsWith("deposit:")) {
    const uid = externalReference.split(":")[1];
    if (status === "approved") {
      const dup = await updatePaymentByMpId(paymentId, { status: "approved" });
      if (dup) return; // idempotente
      await db.collection("users").doc(uid).update({
        deposit: {
          status: "held",
          amount,
          mp_payment_id: paymentId,
          held_at: FieldValue.serverTimestamp(),
          updated_time: FieldValue.serverTimestamp(),
        },
      });
      await recordPayment({
        kind: "deposit",
        uid,
        amount,
        currency: "MXN",
        status: "approved",
        mp_payment_id: paymentId,
      });
    } else if (status === "rejected" || status === "cancelled") {
      await updatePaymentByMpId(paymentId, { status });
    }
    return;
  }

  if (externalReference.startsWith("win:")) {
    const [, lotId, winnerUid] = externalReference.split(":");
    if (status === "approved") {
      const dup = await updatePaymentByMpId(paymentId, { status: "approved" });
      if (dup) return; // idempotente
      const lotRef = db.collection("lots").doc(lotId);
      const lotSnap = await lotRef.get();
      const lot = lotSnap.exists ? lotSnap.data() : null;
      if (!lot || lot.payment_status === "paid") return;

      await db.collection("users").doc(winnerUid).update({
        "deposit.status": "applied",
        "deposit.updated_time": FieldValue.serverTimestamp(),
      });
      await lotRef.update({
        payment_status: "paid",
        winner_payment_url: null,
        payment_due_time: null,
      });
      await recordPayment({
        kind: "winner_payment",
        uid: winnerUid,
        lot_id: lotId,
        amount,
        currency: "MXN",
        status: "approved",
        mp_payment_id: paymentId,
      });
      await settlePaidLot(lotId, lot);
    } else if (status === "rejected" || status === "cancelled") {
      await updatePaymentByMpId(paymentId, { status });
    }
  }
}

exports.mpWebhook = functions.region(REGION).https.onRequest(async (req, res) => {
  const topic = String(req.query.topic || req.query.type || (req.body && req.body.type) || "");
  const paymentId =
    req.query["data.id"] || req.query.id || (req.body && req.body.data && req.body.data.id);

  const valid = validateMpSignature({
    xSignature: req.headers["x-signature"],
    xRequestId: req.headers["x-request-id"],
    dataId: paymentId ? String(paymentId) : "",
    secret: process.env.MP_WEBHOOK_SECRET,
  });
  if (!valid) {
    res.status(401).send("invalid signature");
    return;
  }

  if (topic !== "payment") {
    res.status(200).send("ignored");
    return;
  }
  if (!paymentId) {
    res.status(400).send("missing payment id");
    return;
  }

  try {
    await handlePaymentNotification(String(paymentId));
    res.status(200).send("ok");
  } catch (err) {
    functions.logger.error("Error procesando webhook de MP", err);
    // Respondemos 200 igual para que MP no reintente en bucle; el error queda en logs.
    res.status(200).send("processed-with-errors");
  }
});

module.exports = {
  ...module.exports,
  startWinnerPayment,
  settlePaidLot,
  forfeitWin,
  validateMpSignature,
  round2,
  DEPOSIT_AMOUNT,
  COMMISSION_PCT,
  WINNER_PAYMENT_WINDOW_HOURS,
};
