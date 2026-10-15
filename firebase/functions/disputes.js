/**
 * Protección al comprador: disputas.
 *
 * openDispute (comprador): desde el pago confirmado y hasta 72 h después.
 *   - Crea disputes/{lotId} (una por venta) con estado "open".
 *   - Congela la liquidación al vendedor (payout → "on_hold").
 *   - Marca el lote (dispute_status) y el perfil público ("en disputa").
 *
 * adminResolveDispute (admin): refund_full | refund_partial | reject.
 *   - refund_full: devuelve el pago completo (pago del ganador + depósito
 *     aplicado). La liquidación se cancela; si ya se había transferido,
 *     se registra un "clawback" (el vendedor debe ese monto).
 *   - refund_partial: devuelve un monto; la liquidación baja en ese monto
 *     (o clawback si ya se transfirió).
 *   - reject: se libera la liquidación tal como estaba.
 *   Reembolsos con llave de idempotencia; SPEI se registra como reembolso
 *   manual. Todo queda en admin_log y en payments.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { assertAppCheck } = require("./appcheck");
const pay = require("./payments");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;
const REGION = "us-central1";

const DISPUTE_WINDOW_MS = 72 * 3600 * 1000;
const REASONS = Object.freeze({
  not_delivered: "No llegó",
  not_as_described: "No coincide con lo publicado",
  missing_documents: "Faltan documentos",
  undisclosed_defect: "Defecto no declarado",
  other: "Otro",
});
const RESOLUTIONS = ["refund_full", "refund_partial", "reject"];
const MAX_PHOTOS = 6;

const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: "UNAUTHENTICATED",
  PERMISSION_DENIED: "PERMISSION_DENIED",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
  LOT_NOT_FOUND: "LOT_NOT_FOUND",
  NOT_BUYER: "NOT_BUYER",
  NOT_PAID: "NOT_PAID",
  WINDOW_CLOSED: "WINDOW_CLOSED",
  ALREADY_EXISTS: "ALREADY_EXISTS",
  NOT_FOUND: "NOT_FOUND",
  NOT_OPEN: "NOT_OPEN",
});

function fail(httpsCode, code, message) {
  return new functions.https.HttpsError(httpsCode, message, { code });
}

function millis(t) {
  if (!t) return 0;
  if (typeof t.toMillis === "function") return t.toMillis();
  if (t instanceof Date) return t.getTime();
  return Number(t) || 0;
}

function notification(type, title, body, lotId) {
  return { type, title, body, lot_id: lotId, read: false, created_time: FieldValue.serverTimestamp() };
}

async function openDisputeImpl(data, uid, nowMs = Date.now()) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const lotId = String((data && data.lotId) || "");
  const reason = String((data && data.reason) || "");
  const details = String((data && data.details) || "").trim();
  const photos = Array.isArray(data && data.photos) ? data.photos.map(String) : [];
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Lote inválido.");
  }
  if (!REASONS[reason]) throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Elige el motivo del reclamo.");
  if (details.length < 20 || details.length > 2000) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Describe el problema (de 20 a 2000 caracteres).");
  }
  if (photos.length > MAX_PHOTOS || photos.some((p) => !p.startsWith(`disputes/${uid}/`) || p.includes(".."))) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, `Adjunta hasta ${MAX_PHOTOS} fotos subidas desde la app.`);
  }

  const lotRef = db.collection("lots").doc(lotId);
  const dispRef = db.collection("disputes").doc(lotId);
  const payoutRef = db.collection("payments").doc(`payout-${lotId}`);

  return db.runTransaction(async (tx) => {
    const [lotSnap, dispSnap, payoutSnap] = await Promise.all([tx.get(lotRef), tx.get(dispRef), tx.get(payoutRef)]);
    if (!lotSnap.exists) throw fail("not-found", ERROR_CODES.LOT_NOT_FOUND, "Este lote ya no existe.");
    const lot = lotSnap.data();
    if (lot.winner_uid !== uid) throw fail("permission-denied", ERROR_CODES.NOT_BUYER, "Solo quien compró puede reclamar.");
    if (lot.payment_status !== "paid") {
      throw fail("failed-precondition", ERROR_CODES.NOT_PAID, "Puedes reclamar cuando tu pago esté confirmado.");
    }
    const paidMs = millis(lot.paid_time);
    if (!paidMs || nowMs > paidMs + DISPUTE_WINDOW_MS) {
      throw fail("failed-precondition", ERROR_CODES.WINDOW_CLOSED, "El plazo de 72 horas para reclamar ya terminó.");
    }
    if (dispSnap.exists) throw fail("already-exists", ERROR_CODES.ALREADY_EXISTS, "Ya hay un reclamo para esta compra.");

    const profRef = db.collection("public_profiles").doc(lot.seller_uid);
    const payout = payoutSnap.exists ? payoutSnap.data() : null;

    tx.set(dispRef, {
      lot_id: lotId,
      lot_title: String(lot.title || "").slice(0, 120),
      buyer_uid: uid,
      seller_uid: lot.seller_uid,
      reason,
      details,
      photos,
      final_price: pay.round2(Number(lot.current_bid) || 0),
      status: "open",
      payout_already_sent: Boolean(payout && payout.status === "sent"),
      created_time: FieldValue.serverTimestamp(),
      updated_time: FieldValue.serverTimestamp(),
    });
    tx.update(lotRef, { dispute_status: "open" });
    if (payout && ["ready", "needs_review"].includes(payout.status)) {
      tx.update(payoutRef, {
        status: "on_hold",
        hold_previous_status: payout.status,
        hold_reason: "dispute",
        updated_time: FieldValue.serverTimestamp(),
      });
    }
    tx.set(profRef, { open_disputes: FieldValue.increment(1), updated_time: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(
      db.collection("users").doc(lot.seller_uid).collection("notifications").doc(),
      notification(
        "dispute_opened",
        `Reclamo del comprador: ${lot.title || "tu venta"}`,
        `Motivo: ${REASONS[reason]}. Tu liquidación queda en pausa mientras lo revisamos. Responde con pruebas a soporte.`,
        lotId
      )
    );
    tx.set(
      db.collection("users").doc(uid).collection("notifications").doc(),
      notification("dispute_opened_buyer", "Recibimos tu reclamo", "Lo revisaremos en máximo 5 días hábiles.", lotId)
    );
    return { ok: true, disputeId: lotId, status: "open" };
  });
}

/** Busca el pago del ganador (Mercado Pago u Openpay) aprobado para el lote. */
async function findWinnerPayment(lotId) {
  const snap = await db.collection("payments").where("lot_id", "==", lotId).get();
  const doc = snap.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .find((p) => p.kind === "winner_payment" && p.status === "approved");
  if (!doc) return null;
  if (doc.provider === "openpay") return { provider: "openpay", id: doc.provider_payment_id, amount: Number(doc.amount) || 0 };
  return { provider: "mercadopago", id: doc.mp_payment_id, amount: Number(doc.amount) || 0 };
}

/** Reembolsa por el proveedor; SPEI se registra como reembolso manual. */
async function refundVia(payment, amount, { uid, lotId, reason }) {
  if (!payment || amount <= 0) return { ok: true, manual: false, amount: 0 };
  if (payment.provider === "mercadopago" && payment.id) {
    const ok = await pay.refundAndRecord({ mpPaymentId: payment.id, amount, uid, lotId, reason });
    return { ok, manual: false, amount };
  }
  await db.collection("payments").doc(`refund-${reason}-${lotId}-${payment.provider}`).set({
    kind: "refund",
    provider: payment.provider,
    reason,
    uid,
    lot_id: lotId,
    amount: pay.round2(amount),
    currency: "MXN",
    status: "manual_required",
    created_time: FieldValue.serverTimestamp(),
  });
  return { ok: true, manual: true, amount };
}

async function adminResolveDisputeImpl(data, adminUid) {
  const disputeId = String((data && data.disputeId) || "");
  const resolution = String((data && data.resolution) || "");
  const note = String((data && data.note) || "").trim().slice(0, 1000);
  if (!disputeId || disputeId.includes("/")) throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Disputa inválida.");
  if (!RESOLUTIONS.includes(resolution)) throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Resolución inválida.");

  const dispRef = db.collection("disputes").doc(disputeId);
  const lotRef = db.collection("lots").doc(disputeId);
  const payoutRef = db.collection("payments").doc(`payout-${disputeId}`);

  // 1) Tomar la disputa (open o refund_failed → resolving): una sola resolución a la vez.
  const ctx = await db.runTransaction(async (tx) => {
    const [dSnap, lSnap, pSnap] = await Promise.all([tx.get(dispRef), tx.get(lotRef), tx.get(payoutRef)]);
    if (!dSnap.exists) throw fail("not-found", ERROR_CODES.NOT_FOUND, "Disputa no encontrada.");
    const d = dSnap.data();
    const retry = d.status === "refund_failed" && d.resolution === resolution;
    if (d.status !== "open" && !retry) throw fail("failed-precondition", ERROR_CODES.NOT_OPEN, "Esta disputa ya se resolvió.");
    const lot = lSnap.exists ? lSnap.data() : {};
    const finalPrice = pay.round2(Number(d.final_price) || Number(lot.current_bid) || 0);
    let amount = 0;
    if (resolution === "refund_full") amount = finalPrice;
    if (resolution === "refund_partial") {
      amount = pay.round2(Number(data && data.amount));
      if (!(amount > 0 && amount < finalPrice)) {
        throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "El reembolso parcial debe ser mayor a 0 y menor al precio final.");
      }
    }
    tx.update(dispRef, {
      status: "resolving",
      resolution,
      refund_amount: amount,
      resolver_uid: adminUid,
      note,
      updated_time: FieldValue.serverTimestamp(),
    });
    return { d, lot, payout: pSnap.exists ? pSnap.data() : null, amount, finalPrice };
  });

  const { d, lot, payout, amount } = ctx;
  const buyer = d.buyer_uid;

  // 2) Dinero de regreso al comprador (fuera de transacción, idempotente).
  let refundOk = true;
  let manual = false;
  if (amount > 0) {
    const winnerPayment = await findWinnerPayment(disputeId);
    const depositApplied = pay.round2(Number(lot.deposit_applied) || 0);
    const fromPayment = Math.min(amount, winnerPayment ? winnerPayment.amount : 0);
    const r1 = await refundVia(winnerPayment, fromPayment, { uid: buyer, lotId: disputeId, reason: `dispute_${resolution}` });
    refundOk = refundOk && r1.ok;
    manual = manual || r1.manual;
    // Lo que no alcanza a cubrir el pago (el depósito aplicado) se devuelve aparte.
    const rest = pay.round2(amount - fromPayment);
    if (rest > 0) {
      const userSnap = await db.collection("users").doc(buyer).get();
      const dep = userSnap.exists ? userSnap.data().deposit || {} : {};
      const depId = dep.lot_id === disputeId && dep.mp_payment_id ? dep.mp_payment_id : null;
      const r2 = depId
        ? await refundVia({ provider: "mercadopago", id: depId }, Math.min(rest, depositApplied), {
            uid: buyer,
            lotId: disputeId,
            reason: "dispute_deposit",
          })
        : await refundVia({ provider: "manual" }, rest, { uid: buyer, lotId: disputeId, reason: "dispute_deposit" });
      refundOk = refundOk && r2.ok;
      manual = manual || r2.manual;
    }
  }

  if (!refundOk) {
    await dispRef.update({ status: "refund_failed", updated_time: FieldValue.serverTimestamp() });
    await db.collection("admin_log").add({
      admin_uid: adminUid,
      action: "dispute_refund_failed",
      target: disputeId,
      details: { resolution, amount },
      created_time: FieldValue.serverTimestamp(),
    });
    throw fail("unavailable", "REFUND_FAILED", "Mercado Pago rechazó el reembolso. La disputa quedó marcada; vuelve a intentar.");
  }

  // 3) Liquidación al vendedor y cierre.
  const batch = db.batch();
  if (payout) {
    const prev = payout.hold_previous_status || payout.status;
    if (payout.status === "sent") {
      if (amount > 0) {
        batch.set(db.collection("payments").doc(`clawback-${disputeId}`), {
          kind: "clawback",
          uid: d.seller_uid,
          lot_id: disputeId,
          amount: resolution === "refund_full" ? Number(payout.amount) || 0 : amount,
          currency: "MXN",
          status: "pending",
          reason: `dispute_${resolution}`,
          created_time: FieldValue.serverTimestamp(),
        });
      }
    } else if (resolution === "refund_full") {
      batch.update(payoutRef, { status: "cancelled", cancel_reason: "dispute_refund_full", updated_time: FieldValue.serverTimestamp() });
    } else if (resolution === "refund_partial") {
      const newAmount = payout.amount == null ? null : pay.round2(Math.max(0, Number(payout.amount) - amount));
      batch.update(payoutRef, {
        status: prev === "on_hold" ? "ready" : prev,
        amount: newAmount,
        adjusted_by_dispute: amount,
        hold_previous_status: FieldValue.delete(),
        updated_time: FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(payoutRef, {
        status: prev === "on_hold" ? "ready" : prev,
        hold_previous_status: FieldValue.delete(),
        updated_time: FieldValue.serverTimestamp(),
      });
    }
  }
  batch.update(dispRef, {
    status: "resolved",
    refund_manual: manual,
    resolved_time: FieldValue.serverTimestamp(),
    updated_time: FieldValue.serverTimestamp(),
  });
  batch.update(lotRef, { dispute_status: "resolved", dispute_resolution: resolution });
  batch.set(
    db.collection("public_profiles").doc(d.seller_uid),
    { open_disputes: FieldValue.increment(-1), updated_time: FieldValue.serverTimestamp() },
    { merge: true }
  );
  const money = (n) => `$${Number(n).toLocaleString("es-MX")}`;
  const buyerMsg =
    resolution === "reject"
      ? "Revisamos tu reclamo y no procede. Si tienes nuevas pruebas, contacta a soporte."
      : `Resolvimos a tu favor: te devolvemos ${money(amount)}${manual ? " por transferencia (un asesor te contactará)" : ""}.`;
  const sellerMsg =
    resolution === "reject"
      ? "El reclamo no procedió. Tu liquidación sigue su curso."
      : `Se reembolsó ${money(amount)} al comprador; tu liquidación se ajustó.`;
  batch.set(db.collection("users").doc(buyer).collection("notifications").doc(), notification("dispute_resolved", "Tu reclamo se resolvió", buyerMsg, disputeId));
  batch.set(db.collection("users").doc(d.seller_uid).collection("notifications").doc(), notification("dispute_resolved", "Reclamo resuelto", sellerMsg, disputeId));
  batch.set(db.collection("admin_log").doc(), {
    admin_uid: adminUid,
    action: "dispute_resolved",
    target: disputeId,
    details: { resolution, amount, manual, note },
    created_time: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return { ok: true, disputeId, resolution, refundAmount: amount, manualRefund: manual };
}

function requireAdminUid(context) {
  if (!context.auth) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  if (context.auth.token.admin !== true) throw fail("permission-denied", ERROR_CODES.PERMISSION_DENIED, "Solo administradores.");
  return context.auth.uid;
}

exports.openDispute = functions.region(REGION).https.onCall((data, context) => {
  assertAppCheck(context);
  return openDisputeImpl(data, context.auth ? context.auth.uid : null);
});

exports.adminResolveDispute = functions.region(REGION).https.onCall((data, context) => {
  assertAppCheck(context);
  return adminResolveDisputeImpl(data, requireAdminUid(context));
});

module.exports = {
  ...module.exports,
  ERROR_CODES,
  REASONS,
  DISPUTE_WINDOW_MS,
  openDisputeImpl,
  adminResolveDisputeImpl,
  requireAdminUid,
};
