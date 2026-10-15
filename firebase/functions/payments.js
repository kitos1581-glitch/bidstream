/**
 * BidStream — Pagos con Mercado Pago (escrow).
 *
 * Flujo:
 *  1. Depósito de garantía: el postor paga DEPOSIT_AMOUNT antes de pujar.
 *     users/{uid}.deposit.status = 'held'.
 *  2. Al cerrar una subasta con ganador (startWinnerPayment):
 *     - Si su depósito está 'held', se RESERVA para ese lote ('reserved',
 *       deposit.lot_id) y se descuenta del precio. Un depósito solo se
 *       descuenta UNA vez aunque gane varios lotes.
 *     - Se cobra (precio final − depósito) con fecha límite.
 *     - Si el depósito es mayor al precio, se reembolsa la diferencia.
 *  3. Webhook aprobado → lote 'paid', depósito 'applied', payout 'ready'
 *     al vendedor (precio final − comisión). Todo en una transacción.
 *  4. No pagó a tiempo (expireUnpaidWins) → depósito reservado 'forfeited'
 *     y se compensa al vendedor; strike al usuario (2 = baneo).
 *  5. Reembolso de depósito a petición, si no va ganando ni debe pagos.
 *  6. Pagos tardíos o inválidos se reembolsan automáticamente.
 *
 * Estados del depósito: none | held | reserved | applied | refunding |
 *                       refunded | forfeited
 * Estados de pago del lote: none | pending | paid | forfeited | payment_error
 *
 * Variables de entorno (functions/.env):
 *   MP_ACCESS_TOKEN, MP_WEBHOOK_SECRET, WEBHOOK_URL, SITE_URL,
 *   DEPOSIT_AMOUNT (200), COMMISSION_PCT (0.10), WINNER_PAYMENT_WINDOW_HOURS (24)
 */
const functions = require("firebase-functions");
const { assertAppCheck } = require("./appcheck");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { MercadoPagoConfig, Preference, Payment, PaymentRefund } = require("mercadopago");
const { openpayConfigured } = require("./openpay");
const { recordSale } = require("./reputation");

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const REGION = "us-central1";

const DEPOSIT_AMOUNT = Number(process.env.DEPOSIT_AMOUNT || 200);

/**
 * Retención del pago al vendedor (escrow). El dinero del comprador se libera
 * al vendedor cuando el comprador confirma que recibió, o automáticamente
 * PAYOUT_RELEASE_DAYS días después del pago si no hay reclamo (por defecto 7).
 * Un valor inválido NO se reemplaza en silencio: las liquidaciones quedan
 * retenidas sin fecha de liberación automática (solo por confirmación o admin)
 * y se registra el error.
 */
function readReleaseDays(env = process.env) {
  if (env.PAYOUT_RELEASE_DAYS === undefined || env.PAYOUT_RELEASE_DAYS === "") return { days: 7 };
  const n = Number(env.PAYOUT_RELEASE_DAYS);
  if (!Number.isInteger(n) || n < 1 || n > 60) {
    return { days: null, error: `PAYOUT_RELEASE_DAYS inválido: "${env.PAYOUT_RELEASE_DAYS}" (entero de 1 a 60)` };
  }
  return { days: n };
}
const RELEASE = readReleaseDays();
if (RELEASE.error) functions.logger.error(RELEASE.error);

/**
 * Comisión por tramos (marginal, como el ISR): cada tramo del precio paga
 * su porcentaje, así no hay "brincos" al pasar de un tramo a otro.
 *
 * COMMISSION_TIERS="10000:0.10,100000:0.08,inf:0.06"
 *   → 10% de los primeros $10,000, 8% de $10,000 a $100,000, 6% del resto.
 * COMMISSION_MIN=50     → comisión mínima por venta.
 * COMMISSION_PCT=0.10   → porcentaje plano, solo si NO hay COMMISSION_TIERS.
 *
 * Una configuración inválida NO se reemplaza en silencio por otro valor:
 * produce un error explícito. Las ventas siguen registrándose, pero su
 * liquidación al vendedor queda "needs_review" hasta corregir la
 * configuración (ver panel de administración).
 */
class CommissionConfigError extends Error {}

function parseTiers(spec) {
  const parts = String(spec)
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean);
  if (parts.length === 0) throw new CommissionConfigError("COMMISSION_TIERS está vacío.");
  const tiers = parts.map((p) => {
    const m = p.split(":");
    if (m.length !== 2) throw new CommissionConfigError(`Tramo mal escrito: "${p}" (usa límite:porcentaje).`);
    const upTo = m[0].trim().toLowerCase() === "inf" ? Infinity : Number(m[0]);
    const pct = Number(m[1]);
    if (!(upTo > 0)) throw new CommissionConfigError(`Límite inválido en "${p}".`);
    if (!Number.isFinite(pct) || pct < 0 || pct >= 1) {
      throw new CommissionConfigError(`Porcentaje inválido en "${p}" (debe ser de 0 a 0.99).`);
    }
    return { upTo, pct };
  });
  for (let i = 1; i < tiers.length; i++) {
    if (!(tiers[i].upTo > tiers[i - 1].upTo)) {
      throw new CommissionConfigError("Los límites de COMMISSION_TIERS deben ir en orden creciente.");
    }
  }
  if (tiers[tiers.length - 1].upTo !== Infinity) {
    throw new CommissionConfigError('El último tramo de COMMISSION_TIERS debe ser "inf".');
  }
  return tiers;
}

/** Lee y valida la configuración. Devuelve { tiers, flat, min } o lanza. */
function readCommissionConfig(env = process.env) {
  const has = (k) => env[k] !== undefined && String(env[k]).trim() !== "";
  let tiers = null;
  let flat = null;
  if (has("COMMISSION_TIERS")) {
    tiers = parseTiers(env.COMMISSION_TIERS);
  } else {
    flat = has("COMMISSION_PCT") ? Number(env.COMMISSION_PCT) : 0.1;
    if (!Number.isFinite(flat) || flat < 0 || flat >= 1) {
      throw new CommissionConfigError(`COMMISSION_PCT inválido: "${env.COMMISSION_PCT}" (de 0 a 0.99).`);
    }
  }
  const min = has("COMMISSION_MIN") ? Number(env.COMMISSION_MIN) : 0;
  if (!Number.isFinite(min) || min < 0) {
    throw new CommissionConfigError(`COMMISSION_MIN inválido: "${env.COMMISSION_MIN}".`);
  }
  return { tiers, flat, min };
}

// Se valida al cargar para que el error aparezca en los logs desde el
// arranque, sin tumbar las demás funciones (pujas, depósitos, etc.).
let COMMISSION_CONFIG = null;
let COMMISSION_CONFIG_ERROR = null;
try {
  COMMISSION_CONFIG = readCommissionConfig();
} catch (err) {
  COMMISSION_CONFIG_ERROR = err.message;
  functions.logger.error(`CONFIGURACIÓN DE COMISIONES INVÁLIDA: ${err.message}`);
}

/**
 * Comisión de una venta. Lanza CommissionConfigError si la configuración
 * es inválida (nunca usa un valor por defecto en silencio).
 */
function computeCommission(price, config = COMMISSION_CONFIG) {
  if (!config) {
    throw new CommissionConfigError(COMMISSION_CONFIG_ERROR || "Configuración de comisiones ausente.");
  }
  const p = Number(price);
  if (!Number.isFinite(p) || p < 0) throw new CommissionConfigError(`Precio inválido: ${price}`);
  let c = 0;
  if (config.tiers) {
    let prev = 0;
    for (const t of config.tiers) {
      if (p <= prev) break;
      c += (Math.min(p, t.upTo) - prev) * t.pct;
      prev = t.upTo;
    }
  } else {
    c = p * config.flat;
  }
  // La comisión nunca supera el precio.
  return round2(Math.min(p, Math.max(c, config.min)));
}
const WINNER_PAYMENT_WINDOW_HOURS = Number(process.env.WINNER_PAYMENT_WINDOW_HOURS || 24);
const SITE_URL = process.env.SITE_URL || "https://bidstream.web.app";
const WEBHOOK_URL = process.env.WEBHOOK_URL || "";

// Tolerancia para comparar montos (centavos de redondeo).
const EPS = 0.01;

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

function mpConfig() {
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

function notificationRef(uid) {
  return db.collection("users").doc(uid).collection("notifications").doc();
}

function notificationData(type, title, body, lotId, extra = {}) {
  return {
    type,
    title,
    body,
    lot_id: lotId || "",
    read: false,
    created_time: FieldValue.serverTimestamp(),
    ...extra,
  };
}

// ---------------------------------------------------------------------
// Firma del webhook (pura, para probarla).
// x-signature: "ts=...,v1=...", x-request-id. HMAC sobre
// "id:{data.id};request-id:{x-request-id};ts:{ts};"
// ---------------------------------------------------------------------
function validateMpSignature({ xSignature, xRequestId, dataId, secret }) {
  if (!xSignature || !xRequestId || !secret || !dataId) return false;
  const parts = {};
  for (const pair of String(xSignature).split(",")) {
    const idx = pair.indexOf("=");
    if (idx > 0) parts[pair.slice(0, idx).trim()] = pair.slice(idx + 1).trim();
  }
  if (!parts.ts || !parts.v1) return false;
  // MP indica que el id alfanumérico va en minúsculas en el manifiesto.
  const id = String(dataId).toLowerCase();
  const manifest = `id:${id};request-id:${xRequestId};ts:${parts.ts};`;
  const expected = crypto.createHmac("sha256", secret).update(manifest).digest("hex");
  const a = Buffer.from(expected);
  const b = Buffer.from(String(parts.v1));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// ---------------------------------------------------------------------
// Llamadas a Mercado Pago
// ---------------------------------------------------------------------
async function createPreference({ email, title, amount, externalReference, expiresAt }) {
  const body = {
    items: [
      {
        id: externalReference,
        title,
        quantity: 1,
        currency_id: "MXN",
        unit_price: round2(amount),
      },
    ],
    payer: email ? { email } : undefined,
    external_reference: externalReference,
    binary_mode: true,
    statement_descriptor: "BIDSTREAM",
    notification_url: WEBHOOK_URL || undefined,
    back_urls: {
      success: `${SITE_URL}/`,
      pending: `${SITE_URL}/`,
      failure: `${SITE_URL}/`,
    },
    auto_return: "approved",
  };
  if (expiresAt) {
    body.expires = true;
    body.expiration_date_from = new Date().toISOString();
    body.expiration_date_to = new Date(expiresAt).toISOString();
  }
  return new Preference(mpConfig()).create({
    body,
    requestOptions: { idempotencyKey: `pref-${externalReference}-${Date.now()}` },
  });
}

/**
 * Reembolsa un pago (total si amount es null, parcial si no).
 * La llave de idempotencia evita reembolsar dos veces lo mismo.
 */
async function refundMpPayment(mpPaymentId, amount, idempotencyKey) {
  const body = amount ? { amount: round2(amount) } : {};
  return new PaymentRefund(mpConfig()).create({
    payment_id: mpPaymentId,
    body,
    requestOptions: { idempotencyKey },
  });
}

/** Reembolsa y deja registro; si falla, lo deja marcado para revisión manual. */
async function refundAndRecord({ mpPaymentId, amount, uid, lotId, reason }) {
  const key = `refund-${reason}-${mpPaymentId}-${amount || "full"}`;
  const rec = {
    kind: "refund",
    reason,
    uid: uid || null,
    lot_id: lotId || null,
    amount: amount ? round2(amount) : null,
    currency: "MXN",
    mp_payment_id: String(mpPaymentId),
    created_time: FieldValue.serverTimestamp(),
    updated_time: FieldValue.serverTimestamp(),
  };
  try {
    await refundMpPayment(mpPaymentId, amount, key);
    await db.collection("payments").doc(key).set({ ...rec, status: "approved" });
    return true;
  } catch (err) {
    functions.logger.error(`Reembolso fallido (${reason}) ${mpPaymentId}`, err);
    await db
      .collection("payments")
      .doc(key)
      .set({ ...rec, status: "failed", error: String((err && err.message) || err) });
    return false;
  }
}

// ---------------------------------------------------------------------
// Escrituras de liquidación (dentro de una transacción o batch).
// ---------------------------------------------------------------------
function contactString(u) {
  const parts = [u && u.full_name, u && u.phone && `Tel/WhatsApp: ${u.phone}`, u && u.city].filter(Boolean);
  return parts.length ? parts.join(" · ") : "sin datos de contacto";
}

/**
 * El contacto entre comprador y vendedor se comparte SOLO aquí, cuando el
 * pago ya está confirmado (así no se saltan la plataforma y su comisión).
 */
function writeSettlement(writer, lotId, lot, winnerUid, seller, winner) {
  const finalPrice = round2(Number(lot.current_bid) || 0);
  // Una venta más en el perfil público del vendedor (reputación).
  recordSale(writer, lot.seller_uid);
  let commission;
  try {
    commission = computeCommission(finalPrice);
  } catch (err) {
    // Configuración inválida: el pago SÍ se registra (el dinero ya entró),
    // pero la liquidación al vendedor queda en revisión, sin inventar montos.
    functions.logger.error(`Liquidación del lote ${lotId} en revisión: ${err.message}`);
    writer.set(db.collection("payments").doc(`payout-${lotId}`), {
      kind: "payout",
      reason: "sale",
      uid: lot.seller_uid,
      lot_id: lotId,
      final_price: finalPrice,
      amount: null,
      commission: null,
      currency: "MXN",
      status: "needs_review",
      error: `Configuración de comisiones inválida: ${err.message}`,
      created_time: FieldValue.serverTimestamp(),
      updated_time: FieldValue.serverTimestamp(),
    });
    writer.set(
      notificationRef(lot.seller_uid),
      notificationData(
        "paid",
        `¡Cobrada! ${lot.title}`,
        `Recibimos ${money(finalPrice)}. Estamos calculando tu liquidación y te avisaremos. Coordina la entrega con el comprador: ${contactString(winner)}.`,
        lotId
      )
    );
    if (winnerUid) {
      writer.set(
        notificationRef(winnerUid),
        notificationData(
          "payment_confirmed",
          `Pago confirmado: ${lot.title}`,
          `Tu pago quedó registrado. Coordina la entrega con el vendedor: ${contactString(seller)}.`,
          lotId
        )
      );
    }
    return { finalPrice, commission: null, sellerAmount: null, needsReview: true };
  }
  const sellerAmount = round2(finalPrice - commission);

  // Retenida hasta confirmar la entrega (o liberación automática sin reclamo).
  const releaseAt = RELEASE.days ? Timestamp.fromMillis(Date.now() + RELEASE.days * 86400_000) : null;
  writer.set(db.collection("payments").doc(`payout-${lotId}`), {
    kind: "payout",
    reason: "sale",
    uid: lot.seller_uid,
    lot_id: lotId,
    amount: sellerAmount,
    commission,
    currency: "MXN",
    status: "held", // held → ready (entrega confirmada / plazo) → sent (admin)
    release_after: releaseAt,
    created_time: FieldValue.serverTimestamp(),
    updated_time: FieldValue.serverTimestamp(),
  });
  writer.set(db.collection("lots").doc(lotId), { escrow_release_at: releaseAt }, { merge: true });
  writer.set(
    notificationRef(lot.seller_uid),
    notificationData(
      "paid",
      `¡Cobrada! ${lot.title}`,
      `Recibimos ${money(finalPrice)}. Te transferiremos ${money(sellerAmount)} (comisión ${money(
        commission
      )}) cuando el comprador confirme que recibió${
        RELEASE.days ? ` o, si no hay reclamo, en ${RELEASE.days} días` : ""
      }. Coordina la entrega con el comprador: ${contactString(winner)}.`,
      lotId
    )
  );
  if (winnerUid) {
    writer.set(
      notificationRef(winnerUid),
      notificationData(
        "payment_confirmed",
        `Pago confirmado: ${lot.title}`,
        `Tu pago quedó registrado. Coordina la entrega con el vendedor: ${contactString(seller)}.`,
        lotId
      )
    );
  }
  return { finalPrice, commission, sellerAmount };
}

// ---------------------------------------------------------------------
// createDeposit — genera el checkout del depósito de garantía.
// ---------------------------------------------------------------------
exports.createDeposit = functions.region(REGION).https.onCall(async (data, context) => {
  assertAppCheck(context);
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
  const st = user.deposit && user.deposit.status;
  if (st === "held" || st === "reserved" || st === "refunding") {
    throw new functions.https.HttpsError("already-exists", "Ya tienes un depósito activo.");
  }

  const pref = await createPreference({
    email: user.email,
    title: "Depósito de garantía para pujar — BidStream",
    amount: DEPOSIT_AMOUNT,
    externalReference: `deposit:${uid}`,
  });

  await db.collection("payments").add({
    kind: "deposit_intent",
    uid,
    amount: DEPOSIT_AMOUNT,
    currency: "MXN",
    status: "pending",
    mp_preference_id: pref.id,
    created_time: FieldValue.serverTimestamp(),
  });

  return { initPoint: pref.init_point, amount: DEPOSIT_AMOUNT };
});

// ---------------------------------------------------------------------
// startWinnerPayment — la llama closeLot. Reserva el depósito, calcula lo
// que falta y genera el cobro. Devuelve
// { url, amount, alreadySettled, depositApplied, error }.
// ---------------------------------------------------------------------
async function startWinnerPayment(lotRef, lot, winnerUid) {
  const finalPrice = round2(Number(lot.current_bid) || 0);
  const winnerRef = db.collection("users").doc(winnerUid);
  const dueMs = Date.now() + WINNER_PAYMENT_WINDOW_HOURS * 3600 * 1000;

  const sellerRef = db.collection("users").doc(lot.seller_uid);
  const plan = await db.runTransaction(async (tx) => {
    const [winnerSnap, lotSnap, sellerSnap] = await Promise.all([
      tx.get(winnerRef),
      tx.get(lotRef),
      tx.get(sellerRef),
    ]);
    const winner = winnerSnap.exists ? winnerSnap.data() : {};
    const seller = sellerSnap.exists ? sellerSnap.data() : {};
    const current = lotSnap.exists ? lotSnap.data() : {};
    // Ya procesado (p. ej. reintento): no repetir.
    if (current.amount_due !== undefined && current.payment_status !== "payment_error") {
      return { skip: true, amountDue: current.amount_due, depositApplied: current.deposit_applied || 0 };
    }

    let depositApplied = 0;
    let depositMpId = null;
    const dep = winner.deposit || {};
    if (dep.status === "held") {
      depositApplied = round2(Number(dep.amount) || 0);
      depositMpId = dep.mp_payment_id || null;
    } else if (dep.status === "reserved" && dep.lot_id === lotRef.id) {
      depositApplied = round2(Number(dep.amount) || 0); // reintento
      depositMpId = dep.mp_payment_id || null;
    }

    const covered = Math.min(depositApplied, finalPrice);
    const amountDue = round2(finalPrice - covered);
    const excess = round2(depositApplied - covered);

    if (amountDue <= 0) {
      // El depósito cubre todo: liquidar ya.
      if (depositApplied > 0) {
        tx.update(winnerRef, {
          "deposit.status": "applied",
          "deposit.lot_id": lotRef.id,
          "deposit.updated_time": FieldValue.serverTimestamp(),
        });
      }
      tx.update(lotRef, {
        payment_status: "paid",
        amount_due: 0,
        deposit_applied: depositApplied,
        payment_due_time: null,
        winner_payment_url: null,
      });
      writeSettlement(tx, lotRef.id, lot, winnerUid, seller, winner);
      return { settled: true, amountDue: 0, depositApplied, excess, depositMpId };
    }

    if (depositApplied > 0) {
      tx.update(winnerRef, {
        "deposit.status": "reserved",
        "deposit.lot_id": lotRef.id,
        "deposit.updated_time": FieldValue.serverTimestamp(),
      });
    }
    tx.update(lotRef, {
      payment_status: "pending",
      amount_due: amountDue,
      deposit_applied: depositApplied,
      payment_due_time: Timestamp.fromMillis(dueMs),
      // Métodos que el ganador puede elegir (SPEI solo si Openpay está configurado).
      payment_options: openpayConfigured() ? ["mercadopago", "spei"] : ["mercadopago"],
    });
    return { settled: false, amountDue, depositApplied, excess: 0, depositMpId };
  });

  if (plan.skip) {
    return {
      url: lot.winner_payment_url || null,
      amount: plan.amountDue,
      alreadySettled: plan.amountDue <= 0,
      depositApplied: plan.depositApplied,
    };
  }

  if (plan.settled) {
    if (plan.excess > 0 && plan.depositMpId) {
      await refundAndRecord({
        mpPaymentId: plan.depositMpId,
        amount: plan.excess,
        uid: winnerUid,
        lotId: lotRef.id,
        reason: "deposit_excess",
      });
    }
    return { url: null, amount: 0, alreadySettled: true, depositApplied: plan.depositApplied };
  }

  const winnerSnap = await winnerRef.get();
  const winner = winnerSnap.exists ? winnerSnap.data() : {};
  try {
    const pref = await createPreference({
      email: winner.email,
      title: `Pago de subasta ganada: ${lot.title}`,
      amount: plan.amountDue,
      externalReference: `win:${lotRef.id}:${winnerUid}`,
      expiresAt: dueMs,
    });
    await lotRef.update({ winner_payment_url: pref.init_point });
    return {
      url: pref.init_point,
      amount: plan.amountDue,
      alreadySettled: false,
      depositApplied: plan.depositApplied,
    };
  } catch (err) {
    // Mercado Pago no respondió: queda marcado para que el admin reintente.
    functions.logger.error(`No se pudo crear el cobro del lote ${lotRef.id}`, err);
    await lotRef.update({ payment_status: "payment_error", payment_due_time: null });
    return {
      url: null,
      amount: plan.amountDue,
      alreadySettled: false,
      depositApplied: plan.depositApplied,
      error: true,
    };
  }
}

// ---------------------------------------------------------------------
// forfeitWin — el ganador no pagó a tiempo.
// ---------------------------------------------------------------------
async function forfeitWin(lotRef) {
  const outcome = await db.runTransaction(async (tx) => {
    // 1) TODAS las lecturas primero.
    const snap = await tx.get(lotRef);
    if (!snap.exists) return null;
    const lot = snap.data();
    if (lot.status !== "ended" || lot.payment_status !== "pending") return null;
    if (!lot.payment_due_time || lot.payment_due_time.toMillis() > Date.now()) return null;
    if (!lot.winner_uid) return null;

    const winnerRef = db.collection("users").doc(lot.winner_uid);
    const winnerSnap = await tx.get(winnerRef);
    const winner = winnerSnap.exists ? winnerSnap.data() : {};

    // Solo se pierde el depósito si estaba reservado PARA ESTE lote.
    const dep = winner.deposit || {};
    const forfeitable = dep.status === "reserved" && dep.lot_id === lotRef.id;
    const depositAmount = forfeitable ? round2(Number(dep.amount) || 0) : 0;
    const strikes = (winner.strikes || 0) + 1;

    // 2) Escrituras.
    tx.update(lotRef, {
      payment_status: "forfeited",
      winner_payment_url: null,
    });
    const userPatch = { strikes };
    if (strikes >= 2) userPatch.banned = true;
    if (forfeitable) {
      userPatch["deposit.status"] = "forfeited";
      userPatch["deposit.updated_time"] = FieldValue.serverTimestamp();
    }
    tx.update(winnerRef, userPatch);

    if (depositAmount > 0) {
      tx.set(db.collection("payments").doc(`payout-forfeit-${lotRef.id}`), {
        kind: "payout",
        reason: "deposit_forfeit",
        uid: lot.seller_uid,
        lot_id: lotRef.id,
        amount: depositAmount,
        currency: "MXN",
        status: "ready",
        created_time: FieldValue.serverTimestamp(),
        updated_time: FieldValue.serverTimestamp(),
      });
    }

    tx.set(
      notificationRef(lot.seller_uid),
      notificationData(
        "win_unpaid",
        `El ganador no pagó: ${lot.title}`,
        depositAmount > 0
          ? `Su depósito de ${money(depositAmount)} se te transferirá como compensación. Puedes republicar el lote.`
          : "Puedes republicar el lote.",
        lotRef.id
      )
    );
    tx.set(
      notificationRef(lot.winner_uid),
      notificationData(
        "strike",
        "No completaste tu pago",
        `Perdiste la subasta "${lot.title}"${
          depositAmount > 0 ? ` y tu depósito de ${money(depositAmount)} se transfirió al vendedor` : ""
        }. ${strikes >= 2 ? "Tu cuenta fue suspendida." : "Otro incumplimiento suspenderá tu cuenta."}`,
        lotRef.id
      )
    );
    return true;
  });
  return !!outcome;
}

exports.expireUnpaidWins = functions
  .region(REGION)
  .pubsub.schedule("every 15 minutes")
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

    // Segunda oportunidad: ofrecer al subcampeón y vencer ofertas viejas.
    // (require aquí para evitar la dependencia circular con second_chance.js)
    const sc = require("./second_chance");
    for (const doc of snap.docs) {
      try {
        await sc.offerSecondChance(doc.ref);
      } catch (err) {
        functions.logger.error(`Segunda oportunidad falló en ${doc.id}`, err);
      }
    }
    try {
      await sc.expireSecondChances();
    } catch (err) {
      functions.logger.error("No se pudieron vencer segundas oportunidades", err);
    }
    return null;
  });

// ---------------------------------------------------------------------
// requestDepositRefund — reembolso del depósito a petición.
// Se marca 'refunding' en una transacción ANTES de llamar a MP, así una
// puja simultánea (que lee el depósito dentro de su transacción) se
// rechaza, y dos solicitudes simultáneas no reembolsan dos veces.
// ---------------------------------------------------------------------
exports.requestDepositRefund = functions.region(REGION).https.onCall(async (data, context) => {
  assertAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
  }
  const uid = context.auth.uid;
  const userRef = db.collection("users").doc(uid);

  const dep = await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const leading = await tx.get(
      db.collection("lots").where("highest_bidder_uid", "==", uid).limit(50)
    );
    const user = userSnap.exists ? userSnap.data() : null;
    if (!user || !user.deposit || user.deposit.status !== "held" || !user.deposit.mp_payment_id) {
      throw new functions.https.HttpsError("failed-precondition", "No tienes un depósito reembolsable.");
    }
    if (leading.docs.some((d) => d.data().status === "active")) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vas ganando una subasta activa. Espera a que termine antes de pedir el reembolso."
      );
    }
    tx.update(userRef, {
      "deposit.status": "refunding",
      "deposit.updated_time": FieldValue.serverTimestamp(),
    });
    return user.deposit;
  });

  try {
    await refundMpPayment(dep.mp_payment_id, null, `refund-deposit-${dep.mp_payment_id}`);
  } catch (err) {
    functions.logger.error("Reembolso rechazado por MP", err);
    await userRef.update({
      "deposit.status": "held",
      "deposit.updated_time": FieldValue.serverTimestamp(),
    });
    throw new functions.https.HttpsError(
      "internal",
      "Mercado Pago rechazó el reembolso. Intenta más tarde o contacta a soporte."
    );
  }

  const batch = db.batch();
  batch.update(userRef, {
    "deposit.status": "refunded",
    "deposit.updated_time": FieldValue.serverTimestamp(),
  });
  batch.set(db.collection("payments").doc(`refund-deposit-${dep.mp_payment_id}`), {
    kind: "refund",
    reason: "deposit_request",
    uid,
    amount: dep.amount,
    currency: "MXN",
    status: "approved",
    mp_payment_id: String(dep.mp_payment_id),
    created_time: FieldValue.serverTimestamp(),
    updated_time: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { ok: true, amount: dep.amount };
});

// ---------------------------------------------------------------------
// Webhook
// ---------------------------------------------------------------------

/**
 * Lógica común del pago del ganador, para cualquier proveedor (Mercado Pago,
 * Openpay/SPEI). Corre DENTRO de una transacción que ya leyó lockRef.
 * Devuelve { action: "none" } o { action: "refund", ... } si el pago no
 * corresponde (tardío, duplicado o monto menor).
 */
async function applyWinnerPaymentTx(tx, { lockRef, base, lotId, winnerUid, amount, currency }) {
  const lotRef = db.collection("lots").doc(lotId);
  const winnerRef = db.collection("users").doc(winnerUid);
  const [lotSnap, winnerSnap] = await Promise.all([tx.get(lotRef), tx.get(winnerRef)]);
  const lot = lotSnap.exists ? lotSnap.data() : null;
  const sellerSnap = lot ? await tx.get(db.collection("users").doc(lot.seller_uid)) : null;

  const valid =
    lot &&
    lot.winner_uid === winnerUid &&
    lot.payment_status === "pending" &&
    currency === "MXN" &&
    amount + EPS >= Number(lot.amount_due || 0);

  if (!valid) {
    // Pago tardío (ya castigado), duplicado o monto incorrecto: devolver.
    tx.set(lockRef, {
      ...base,
      kind: "winner_payment",
      uid: winnerUid,
      lot_id: lotId,
      status: "rejected_late_or_invalid",
    });
    return { action: "refund", uid: winnerUid, lotId, reason: "winner_late_or_invalid", lot };
  }

  tx.update(lotRef, {
    payment_status: "paid",
    winner_payment_url: null,
    payment_due_time: null,
    paid_time: FieldValue.serverTimestamp(),
    paid_with: base.provider || "mercadopago",
  });
  const dep = winnerSnap.exists ? winnerSnap.data().deposit || {} : {};
  if (dep.status === "reserved" && dep.lot_id === lotId) {
    tx.update(winnerRef, {
      "deposit.status": "applied",
      "deposit.updated_time": FieldValue.serverTimestamp(),
    });
  }
  tx.set(lockRef, {
    ...base,
    kind: "winner_payment",
    uid: winnerUid,
    lot_id: lotId,
    status: "approved",
  });
  writeSettlement(
    tx,
    lotId,
    lot,
    winnerUid,
    sellerSnap && sellerSnap.exists ? sellerSnap.data() : {},
    winnerSnap.exists ? winnerSnap.data() : {}
  );
  return { action: "none" };
}

/**
 * Pago del ganador confirmado por un proveedor distinto de Mercado Pago.
 * Candado de idempotencia: payments/{provider}_{providerPaymentId}.
 */
async function applyProviderWinnerPayment({ provider, providerPaymentId, lotId, winnerUid, amount, currency }) {
  const lockRef = db.collection("payments").doc(`${provider}_${providerPaymentId}`);
  return db.runTransaction(async (tx) => {
    const lock = await tx.get(lockRef);
    if (lock.exists) return { action: "none", duplicate: true };
    const base = {
      provider,
      provider_payment_id: String(providerPaymentId),
      amount: round2(amount),
      currency,
      created_time: FieldValue.serverTimestamp(),
      updated_time: FieldValue.serverTimestamp(),
    };
    return applyWinnerPaymentTx(tx, {
      lockRef,
      base,
      lotId,
      winnerUid,
      amount: round2(amount),
      currency,
    });
  });
}

/**
 * Aplica un pago aprobado. Toda la decisión ocurre en UNA transacción con
 * un documento payments/mp_{id} como candado de idempotencia: aunque MP
 * mande la misma notificación varias veces, se aplica una sola vez.
 * Devuelve acciones externas a ejecutar después (reembolsos).
 */
async function applyApprovedPayment(payment) {
  const mpId = String(payment.id);
  const ref = String(payment.external_reference || "");
  const amount = round2(Number(payment.transaction_amount) || 0);
  const currency = payment.currency_id || "MXN";
  const lockRef = db.collection("payments").doc(`mp_${mpId}`);

  return db.runTransaction(async (tx) => {
    const lock = await tx.get(lockRef);
    if (lock.exists) return { action: "none" }; // ya procesado

    const base = {
      mp_payment_id: mpId,
      amount,
      currency,
      external_reference: ref,
      created_time: FieldValue.serverTimestamp(),
      updated_time: FieldValue.serverTimestamp(),
    };

    // ---------------- Depósito ----------------
    if (ref.startsWith("deposit:")) {
      const uid = ref.split(":")[1];
      const userRef = db.collection("users").doc(uid);
      const userSnap = await tx.get(userRef);
      const st = userSnap.exists && userSnap.data().deposit ? userSnap.data().deposit.status : "none";

      if (currency !== "MXN" || amount + EPS < DEPOSIT_AMOUNT) {
        tx.set(lockRef, { ...base, kind: "deposit", uid, status: "amount_mismatch" });
        return { action: "refund", uid, reason: "deposit_mismatch" };
      }
      if (["held", "reserved", "refunding"].includes(st)) {
        // Ya tenía depósito activo: este pago sobra.
        tx.set(lockRef, { ...base, kind: "deposit", uid, status: "duplicate" });
        return { action: "refund", uid, reason: "deposit_duplicate" };
      }
      tx.set(
        userRef,
        {
          deposit: {
            status: "held",
            amount,
            mp_payment_id: mpId,
            held_at: FieldValue.serverTimestamp(),
            updated_time: FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );
      tx.set(lockRef, { ...base, kind: "deposit", uid, status: "approved" });
      tx.set(
        notificationRef(uid),
        notificationData(
          "deposit_ok",
          "Depósito recibido",
          `Tu depósito de ${money(amount)} quedó en garantía. Ya puedes pujar.`,
          ""
        )
      );
      return { action: "none" };
    }

    // ---------------- Pago del ganador ----------------
    if (ref.startsWith("win:")) {
      const [, lotId, winnerUid] = ref.split(":");
      return applyWinnerPaymentTx(tx, { lockRef, base, lotId, winnerUid, amount, currency });
    }

    tx.set(lockRef, { ...base, kind: "unknown", status: "ignored" });
    return { action: "none" };
  });
}

async function handlePaymentNotification(paymentId) {
  const payment = await new Payment(mpConfig()).get({ id: paymentId });
  if (payment.status !== "approved") {
    // rejected / cancelled / etc. Solo dejamos registro.
    await db
      .collection("payments")
      .doc(`mp_status_${paymentId}_${payment.status}`)
      .set({
        mp_payment_id: String(paymentId),
        status: payment.status,
        external_reference: payment.external_reference || "",
        created_time: FieldValue.serverTimestamp(),
      });
    return;
  }

  const result = await applyApprovedPayment(payment);
  if (result.action === "refund") {
    const ok = await refundAndRecord({
      mpPaymentId: paymentId,
      amount: null,
      uid: result.uid,
      lotId: result.lotId,
      reason: result.reason,
    });
    if (result.uid) {
      await notificationRef(result.uid).set(
        notificationData(
          "payment_refunded",
          "Te devolvimos un pago",
          ok
            ? "Recibimos un pago que no correspondía (tardío o duplicado) y lo reembolsamos completo."
            : "Recibimos un pago que no correspondía. Lo revisaremos y te lo devolveremos.",
          result.lotId || ""
        )
      );
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
    // 500 → Mercado Pago reintenta. Es seguro: el procesamiento es idempotente.
    res.status(500).send("retry");
  }
});

module.exports = {
  ...module.exports,
  startWinnerPayment,
  forfeitWin,
  applyApprovedPayment,
  applyProviderWinnerPayment,
  validateMpSignature,
  refundAndRecord,
  round2,
  DEPOSIT_AMOUNT,
  computeCommission,
  parseTiers,
  readCommissionConfig,
  CommissionConfigError,
  getCommissionConfigError: () => COMMISSION_CONFIG_ERROR,
  WINNER_PAYMENT_WINDOW_HOURS,
  readReleaseDays,
  RELEASE,
};
