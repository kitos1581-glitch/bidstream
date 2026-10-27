/**
 * Entrega y municipios (logística regional, arranque en Camargo, Chih.).
 *
 * En el lote (lo valida firestore.rules):
 *   municipality: uno de MUNICIPALITIES (origen del artículo)
 *   delivery: {
 *     pickup: bool,               // "Entrega a acordar con el vendedor" (sin costo)
 *     regional: bool,             // "Envío regional / intermunicipal"
 *     shipping_cost: number,      // costo fijo del envío (0 si va incluido)
 *     shipping_included: bool,    // true = ya incluido en el precio
 *     destinations: [municipio],  // a dónde envía ([] = toda la región)
 *   }
 * Al cerrar: si solo hay una modalidad, se aplica sola. Si hay dos, el ganador
 * elige con chooseDelivery ANTES de pagar; el envío se suma a lo que paga y
 * va completo al vendedor (sin comisión).
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { assertAppCheck } = require("./appcheck");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;

/** Municipios de la región (Chihuahua). Deben coincidir con lib/backend/regions.dart. */
const MUNICIPALITIES = Object.freeze({
  camargo: "Camargo",
  jimenez: "Jiménez",
  saucillo: "Saucillo",
  delicias: "Delicias",
  parral: "Hidalgo del Parral",
  meoqui: "Meoqui",
  la_cruz: "La Cruz",
  san_francisco_de_conchos: "San Francisco de Conchos",
  chihuahua: "Chihuahua",
  cuauhtemoc: "Cuauhtémoc",
  otro: "Otro",
});

const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: "UNAUTHENTICATED",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
  LOT_NOT_FOUND: "LOT_NOT_FOUND",
  NOT_WINNER: "NOT_WINNER",
  NOT_PENDING: "NOT_PENDING",
  MODE_NOT_OFFERED: "MODE_NOT_OFFERED",
  DESTINATION_NOT_COVERED: "DESTINATION_NOT_COVERED",
  ALREADY_LOCKED: "ALREADY_LOCKED",
});

function fail(httpsCode, code, message) {
  return new functions.https.HttpsError(httpsCode, message, { code });
}

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

/** Costo de envío que paga el comprador por la modalidad regional. */
function regionalCharge(delivery) {
  if (!delivery || !delivery.regional || delivery.shipping_included) return 0;
  const c = Number(delivery.shipping_cost);
  return Number.isFinite(c) && c > 0 ? round2(c) : 0;
}

/**
 * Qué modalidad aplica al cerrar (función pura).
 * Lotes viejos sin `delivery` = entrega a acordar (como siempre).
 * @returns {{choice: "pickup"|"regional"|null, shipping: number}}
 */
function deliveryPlan(lot) {
  const d = lot && lot.delivery;
  if (!d || (!d.pickup && !d.regional)) return { choice: "pickup", shipping: 0 };
  if (d.pickup && d.regional) return { choice: null, shipping: 0 }; // elige el ganador
  if (d.regional) return { choice: "regional", shipping: regionalCharge(d) };
  return { choice: "pickup", shipping: 0 };
}

async function chooseDeliveryImpl(data, uid, deps) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const lotId = String((data && data.lotId) || "");
  const mode = String((data && data.mode) || "");
  const destination = String((data && data.destination) || "");
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Lote inválido.");
  }
  if (!["pickup", "regional"].includes(mode)) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Modalidad de entrega inválida.");
  }
  if (mode === "regional" && !MUNICIPALITIES[destination]) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Elige el municipio de destino.");
  }
  const lotRef = db.collection("lots").doc(lotId);
  const plan = await db.runTransaction(async (tx) => {
    const snap = await tx.get(lotRef);
    if (!snap.exists) throw fail("not-found", ERROR_CODES.LOT_NOT_FOUND, "Este lote ya no existe.");
    const lot = snap.data();
    if (lot.winner_uid !== uid) throw fail("permission-denied", ERROR_CODES.NOT_WINNER, "Solo el ganador elige la entrega.");
    if (lot.payment_status !== "pending") {
      throw fail("failed-precondition", ERROR_CODES.NOT_PENDING, "Este lote no tiene un pago pendiente.");
    }
    if (lot.offline_payment_pending === true) {
      throw fail(
        "failed-precondition",
        ERROR_CODES.ALREADY_LOCKED,
        "Ya generaste tu ficha de pago con este monto; ya no se puede cambiar la entrega."
      );
    }
    if (lot.spei_charge_id) {
      throw fail(
        "failed-precondition",
        ERROR_CODES.ALREADY_LOCKED,
        "Ya generaste tu referencia SPEI con este monto; ya no se puede cambiar la entrega."
      );
    }
    const d = lot.delivery || {};
    if ((mode === "pickup" && !d.pickup) || (mode === "regional" && !d.regional)) {
      throw fail("failed-precondition", ERROR_CODES.MODE_NOT_OFFERED, "El vendedor no ofrece esa modalidad.");
    }
    const dests = Array.isArray(d.destinations) ? d.destinations : [];
    if (mode === "regional" && dests.length && !dests.includes(destination)) {
      throw fail("failed-precondition", ERROR_CODES.DESTINATION_NOT_COVERED, "El vendedor no envía a ese municipio.");
    }
    const shipping = mode === "regional" ? regionalCharge(d) : 0;
    const base = round2(Number(lot.current_bid) - Number(lot.deposit_applied || 0));
    const amountDue = round2(Math.max(0, base) + shipping);
    tx.update(lotRef, {
      delivery_choice: mode,
      delivery_destination: mode === "regional" ? destination : null,
      shipping_charge: shipping,
      amount_due: amountDue,
      winner_payment_url: FieldValue.delete(),
    });
    return { lot, amountDue, shipping };
  });

  // Nuevo cobro de Mercado Pago con el monto correcto (el anterior, si se
  // pagara, se rechaza y se reembolsa por monto menor).
  const winnerSnap = await db.collection("users").doc(uid).get();
  let url = null;
  try {
    const dueMs = plan.lot.payment_due_time && plan.lot.payment_due_time.toMillis ? plan.lot.payment_due_time.toMillis() : undefined;
    const offline = deps.offlineOptionsFor ? deps.offlineOptionsFor(plan.lot, dueMs) : { allowOffline: false, cashExpiresAt: null };
    const pref = await deps.createPreference({
      email: winnerSnap.exists ? winnerSnap.data().email : undefined,
      title: `Pago de subasta ganada: ${plan.lot.title || ""}`,
      amount: plan.amountDue,
      externalReference: `win:${lotId}:${uid}`,
      expiresAt: dueMs,
      allowOffline: offline.allowOffline,
      cashExpiresAt: offline.cashExpiresAt,
    });
    url = pref.init_point;
    await lotRef.update({ winner_payment_url: url });
  } catch (err) {
    functions.logger.error(`No se pudo regenerar el cobro de ${lotId}`, err);
  }
  return { ok: true, mode, shipping: plan.shipping, amountDue: plan.amountDue, paymentUrl: url };
}

exports.chooseDelivery = functions.region("us-central1").https.onCall((data, context) => {
  assertAppCheck(context);
  const pay = require("./payments");
  return chooseDeliveryImpl(data, context.auth ? context.auth.uid : null, { createPreference: pay.createPreference, offlineOptionsFor: pay.offlineOptionsFor });
});

module.exports = { ...module.exports, MUNICIPALITIES, ERROR_CODES, deliveryPlan, regionalCharge, chooseDeliveryImpl };
