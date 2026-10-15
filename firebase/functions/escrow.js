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
});

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

exports.releaseDuePayoutsJob = functions
  .region("us-central1")
  .pubsub.schedule("every 60 minutes")
  .onRun(async () => {
    const n = await releaseDuePayouts();
    functions.logger.info(`Liquidaciones liberadas por plazo: ${n}`);
    return null;
  });

module.exports = { ...module.exports, ERROR_CODES, confirmReceiptImpl, releaseDuePayouts };
