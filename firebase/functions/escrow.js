/**
 * Liberación del pago al vendedor (escrow).
 *
 * confirmReceipt (comprador): "Recibí el artículo y está bien" → la
 *   liquidación pasa de held a ready (el admin ya puede transferir) y se
 *   cierra la ventana de reclamo.
 * releaseDuePayouts (programada): libera las liquidaciones cuyo plazo venció
 *   (release_after) sin reclamo abierto.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const { assertAppCheck } = require("./appcheck");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;

const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: "UNAUTHENTICATED",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
  LOT_NOT_FOUND: "LOT_NOT_FOUND",
  NOT_BUYER: "NOT_BUYER",
  NOT_PAID: "NOT_PAID",
  DISPUTE_OPEN: "DISPUTE_OPEN",
  NOT_SELLER: "NOT_SELLER",
  WRONG_CODE: "WRONG_CODE",
  TOO_MANY_ATTEMPTS: "TOO_MANY_ATTEMPTS",
  NO_CODE: "NO_CODE",
});

const MAX_CODE_ATTEMPTS = 5;

function hashCode(lotId, code) {
  return crypto.createHash("sha256").update(`${lotId}:${code}`).digest("hex");
}

/**
 * Genera el código de entrega (lo llama writeSettlement con el mismo escritor).
 * - El comprador lo lee en users/{uid}/delivery_codes/{lotId} (solo él).
 * - El servidor guarda solo su huella en lots/{id}/private/delivery_code.
 */
function writeDeliveryCode(writer, lotId, buyerUid, lotTitle) {
  const code = String(crypto.randomInt(0, 1_000_000)).padStart(6, "0");
  writer.set(db.collection("users").doc(buyerUid).collection("delivery_codes").doc(lotId), {
    code,
    lot_title: String(lotTitle).slice(0, 120),
    created_time: FieldValue.serverTimestamp(),
  });
  writer.set(db.collection("lots").doc(lotId).collection("private").doc("delivery_code"), {
    code_hash: hashCode(lotId, code),
    attempts: 0,
    created_time: FieldValue.serverTimestamp(),
  });
  return code;
}

/**
 * El VENDEDOR captura el código que le dio el comprador al entregar en persona:
 * se libera su pago al instante. Máximo 5 intentos (contra adivinanzas).
 */
async function confirmDeliveryCodeImpl(data, uid) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const lotId = String((data && data.lotId) || "");
  const code = String((data && data.code) || "").replace(/\D/g, "");
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Lote inválido.");
  }
  if (code.length !== 6) throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "El código tiene 6 dígitos.");
  const lotRef = db.collection("lots").doc(lotId);
  const codeRef = lotRef.collection("private").doc("delivery_code");
  const payoutRef = db.collection("payments").doc(`payout-${lotId}`);

  const outcome = await db.runTransaction(async (tx) => {
    const [lotSnap, codeSnap, payoutSnap] = await Promise.all([tx.get(lotRef), tx.get(codeRef), tx.get(payoutRef)]);
    if (!lotSnap.exists) throw fail("not-found", ERROR_CODES.LOT_NOT_FOUND, "Este lote ya no existe.");
    const lot = lotSnap.data();
    if (lot.seller_uid !== uid) throw fail("permission-denied", ERROR_CODES.NOT_SELLER, "Solo el vendedor captura el código.");
    if (lot.payment_status !== "paid") throw fail("failed-precondition", ERROR_CODES.NOT_PAID, "El pago aún no está confirmado.");
    if (lot.dispute_status === "open") {
      throw fail("failed-precondition", ERROR_CODES.DISPUTE_OPEN, "Hay un reclamo abierto en esta venta.");
    }
    if (lot.received_time) return { ok: true, alreadyConfirmed: true };
    if (!codeSnap.exists) throw fail("failed-precondition", ERROR_CODES.NO_CODE, "Esta venta no usa código de entrega.");
    const c = codeSnap.data();
    if ((c.attempts || 0) >= MAX_CODE_ATTEMPTS) {
      throw fail("failed-precondition", ERROR_CODES.TOO_MANY_ATTEMPTS, "Demasiados intentos. Pide al comprador que confirme desde su app o contacta a soporte.");
    }
    if (c.code_hash !== hashCode(lotId, code)) {
      tx.update(codeRef, { attempts: (c.attempts || 0) + 1 });
      return { ok: false, left: MAX_CODE_ATTEMPTS - (c.attempts || 0) - 1 };
    }
    tx.update(lotRef, { received_time: FieldValue.serverTimestamp(), delivered_by: "code" });
    tx.update(codeRef, { used_time: FieldValue.serverTimestamp() });
    const payout = payoutSnap.exists ? payoutSnap.data() : null;
    if (payout && payout.status === "held") {
      tx.update(payoutRef, { status: "ready", released_by: "delivery_code", updated_time: FieldValue.serverTimestamp() });
    }
    tx.set(
      db.collection("users").doc(lot.winner_uid).collection("notifications").doc(),
      note("delivered", `Entrega confirmada: ${lot.title || "tu compra"}`, "El vendedor capturó tu código de entrega. ¡Disfrútalo! Ya puedes calificarlo.", lotId)
    );
    return { ok: true, alreadyConfirmed: false };
  });
  if (!outcome.ok) {
    throw fail(
      "invalid-argument",
      ERROR_CODES.WRONG_CODE,
      outcome.left > 0 ? `Código incorrecto. Te quedan ${outcome.left} intentos.` : "Código incorrecto. Ya no quedan intentos."
    );
  }
  return outcome;
}

function fail(httpsCode, code, message) {
  return new functions.https.HttpsError(httpsCode, message, { code });
}
function millis(t) {
  if (!t) return 0;
  if (typeof t.toMillis === "function") return t.toMillis();
  return Number(t) || 0;
}
function note(type, title, body, lotId) {
  return { type, title, body, lot_id: lotId, read: false, created_time: FieldValue.serverTimestamp() };
}

async function confirmReceiptImpl(data, uid) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const lotId = String((data && data.lotId) || "");
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Lote inválido.");
  }
  const lotRef = db.collection("lots").doc(lotId);
  const payoutRef = db.collection("payments").doc(`payout-${lotId}`);
  return db.runTransaction(async (tx) => {
    const [lotSnap, payoutSnap] = await Promise.all([tx.get(lotRef), tx.get(payoutRef)]);
    if (!lotSnap.exists) throw fail("not-found", ERROR_CODES.LOT_NOT_FOUND, "Este lote ya no existe.");
    const lot = lotSnap.data();
    if (lot.winner_uid !== uid) throw fail("permission-denied", ERROR_CODES.NOT_BUYER, "Solo quien compró puede confirmar.");
    if (lot.payment_status !== "paid") throw fail("failed-precondition", ERROR_CODES.NOT_PAID, "El pago aún no está confirmado.");
    if (lot.dispute_status === "open") {
      throw fail("failed-precondition", ERROR_CODES.DISPUTE_OPEN, "Tienes un reclamo abierto; espera su resolución.");
    }
    if (lot.received_time) return { ok: true, alreadyConfirmed: true };
    tx.update(lotRef, { received_time: FieldValue.serverTimestamp() });
    const payout = payoutSnap.exists ? payoutSnap.data() : null;
    if (payout && payout.status === "held") {
      tx.update(payoutRef, { status: "ready", released_by: "buyer", updated_time: FieldValue.serverTimestamp() });
    }
    tx.set(
      db.collection("users").doc(lot.seller_uid).collection("notifications").doc(),
      note("receipt_confirmed", `El comprador recibió: ${lot.title || "tu venta"}`, "Tu pago quedó liberado; te avisaremos cuando lo transfiramos.", lotId)
    );
    return { ok: true, alreadyConfirmed: false };
  });
}

/** Libera las liquidaciones retenidas cuyo plazo venció sin reclamo. */
async function releaseDuePayouts(nowMs = Date.now()) {
  const snap = await db.collection("payments").where("status", "==", "held").limit(200).get();
  let released = 0;
  for (const doc of snap.docs) {
    const p = doc.data();
    if (p.kind !== "payout" || !p.release_after || millis(p.release_after) > nowMs) continue;
    const lotRef = db.collection("lots").doc(p.lot_id);
    const ok = await db.runTransaction(async (tx) => {
      const [fresh, lotSnap] = await Promise.all([tx.get(doc.ref), tx.get(lotRef)]);
      const cur = fresh.exists ? fresh.data() : null;
      if (!cur || cur.status !== "held") return false;
      if (lotSnap.exists && lotSnap.data().dispute_status === "open") return false;
      tx.update(doc.ref, { status: "ready", released_by: "timeout", updated_time: FieldValue.serverTimestamp() });
      tx.set(
        db.collection("users").doc(cur.uid).collection("notifications").doc(),
        note("payout_released", "Tu pago quedó liberado", "Pasó el plazo sin reclamos del comprador. Te avisaremos cuando lo transfiramos.", p.lot_id)
      );
      return true;
    });
    if (ok) released++;
  }
  return released;
}

exports.confirmReceipt = functions.region("us-central1").https.onCall((data, context) => {
  assertAppCheck(context);
  return confirmReceiptImpl(data, context.auth ? context.auth.uid : null);
});

exports.confirmDeliveryCode = functions.region("us-central1").https.onCall((data, context) => {
  assertAppCheck(context);
  return confirmDeliveryCodeImpl(data, context.auth ? context.auth.uid : null);
});

exports.releaseDuePayoutsJob = functions
  .region("us-central1")
  .pubsub.schedule("every 60 minutes")
  .onRun(async () => {
    const n = await releaseDuePayouts();
    functions.logger.info(`Liquidaciones liberadas por plazo: ${n}`);
    return null;
  });

module.exports = {
  ...module.exports,
  ERROR_CODES,
  confirmReceiptImpl,
  releaseDuePayouts,
  writeDeliveryCode,
  confirmDeliveryCodeImpl,
  MAX_CODE_ATTEMPTS,
};
