/**
 * setReservePrice — el vendedor fija, baja o quita su precio de reserva.
 *
 * - Solo subastas POR TIEMPO (en vivo no hay reserva: la venta es firme).
 * - Secreto: se guarda en lots/{id}/private/reserve (las reglas lo cierran).
 *   En el lote solo quedan has_reserve y reserve_met.
 * - Debe ser mayor que el precio inicial y ≤ $50,000,000.
 * - Con pujas: solo se puede BAJAR o quitar (nunca subir ni agregar).
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { assertAppCheck } = require("./appcheck");
const { MAX_BID_PESOS } = require("./auction_logic");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;

const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: "UNAUTHENTICATED",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
  LOT_NOT_FOUND: "LOT_NOT_FOUND",
  NOT_SELLER: "NOT_SELLER",
  NOT_ACTIVE: "NOT_ACTIVE",
  LIVE_NOT_ALLOWED: "LIVE_NOT_ALLOWED",
  FIXED_NOT_ALLOWED: "FIXED_NOT_ALLOWED",
  ABOVE_BUY_NOW: "ABOVE_BUY_NOW",
  ONLY_LOWER: "ONLY_LOWER",
});

function fail(httpsCode, code, message) {
  return new functions.https.HttpsError(httpsCode, message, { code });
}

async function setReservePriceImpl(data, uid) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const lotId = String((data && data.lotId) || "");
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Lote inválido.");
  }
  const raw = data ? data.amount : undefined;
  const remove = raw === null || raw === 0;
  const amount = remove ? 0 : Math.round(Number(raw) * 100) / 100;
  if (!remove && !(Number.isFinite(amount) && amount > 0 && amount <= MAX_BID_PESOS)) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Precio de reserva inválido.");
  }

  const lotRef = db.collection("lots").doc(lotId);
  const resRef = lotRef.collection("private").doc("reserve");
  const stateRef = lotRef.collection("private").doc("proxy_state");
  return db.runTransaction(async (tx) => {
    const [lotSnap, resSnap, stateSnap] = await Promise.all([tx.get(lotRef), tx.get(resRef), tx.get(stateRef)]);
    if (!lotSnap.exists) throw fail("not-found", ERROR_CODES.LOT_NOT_FOUND, "Este lote ya no existe.");
    const lot = lotSnap.data();
    if (lot.seller_uid !== uid) throw fail("permission-denied", ERROR_CODES.NOT_SELLER, "Solo el vendedor puede cambiar la reserva.");
    if (lot.status !== "active") throw fail("failed-precondition", ERROR_CODES.NOT_ACTIVE, "La subasta ya terminó.");
    if (lot.format === "live") {
      throw fail("failed-precondition", ERROR_CODES.LIVE_NOT_ALLOWED, "Las subastas en vivo no llevan precio de reserva.");
    }
    if (lot.sale_type === "fixed") {
      throw fail("failed-precondition", ERROR_CODES.FIXED_NOT_ALLOWED, "Las ventas a precio fijo no llevan precio de reserva.");
    }
    const buyNow = Number(lot.buy_now_price) || 0;
    if (!remove && buyNow > 0 && amount >= buyNow) {
      throw fail(
        "invalid-argument",
        ERROR_CODES.ABOVE_BUY_NOW,
        "La reserva debe ser menor que tu precio de Comprar ahora."
      );
    }
    const current = resSnap.exists ? Number(resSnap.data().amount) || 0 : 0;
    const hasBids = (lot.bid_count || 0) > 0;
    if (!remove && amount <= Number(lot.starting_price || 0)) {
      throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "La reserva debe ser mayor que el precio inicial.");
    }
    if (hasBids && !remove && (current === 0 || amount > current)) {
      throw fail(
        "failed-precondition",
        ERROR_CODES.ONLY_LOWER,
        "Con pujas ya no se puede agregar ni subir la reserva; solo bajarla o quitarla."
      );
    }

    if (remove) {
      tx.delete(resRef);
      tx.update(lotRef, { has_reserve: false, reserve_met: FieldValue.delete() });
      return { ok: true, hasReserve: false, reserveMet: null };
    }
    // ¿El máximo secreto del líder ya alcanza la nueva reserva?
    const state = stateSnap.exists ? stateSnap.data() : null;
    const leaderMax = state ? Number(state.leader_max) || 0 : 0;
    const met = hasBids && leaderMax >= amount;
    const patch = { has_reserve: true, reserve_met: met };
    if (met && Number(lot.current_bid || 0) < amount) {
      // Al bajar la reserva por debajo del máximo del líder, el precio sube
      // a la reserva (puja automática del líder, como cuando se alcanza pujando).
      patch.current_bid = amount;
      patch.bid_count = FieldValue.increment(1);
      tx.set(lotRef.collection("history").doc(), {
        bidder_uid: state.leader_uid,
        bidder_name: state.leader_name || lot.highest_bidder_name || "",
        amount,
        auto: true,
        created_time: FieldValue.serverTimestamp(),
      });
      if (state.leader_bid_id) {
        tx.set(lotRef.collection("bids").doc(state.leader_bid_id), { current_effective_bid: amount }, { merge: true });
      }
    }
    tx.set(resRef, { amount, updated_time: FieldValue.serverTimestamp() });
    tx.update(lotRef, patch);
    return { ok: true, hasReserve: true, reserveMet: met };
  });
}

exports.setReservePrice = functions.region("us-central1").https.onCall((data, context) => {
  assertAppCheck(context);
  return setReservePriceImpl(data, context.auth ? context.auth.uid : null);
});

module.exports = { ...module.exports, ERROR_CODES, setReservePriceImpl };
