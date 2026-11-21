/**
 * Venta privada con enlace ("ya tengo comprador, solo necesito cobrar con tarjeta").
 *
 *  lots/{id}.private_sale = true      → no sale en el catálogo (lo marca la app al publicar;
 *                                       solo precio fijo y hasta PRIVATE_SALE_MAX, lo validan las reglas)
 *  lot_private/{id} { token, ... }    → secreto del enlace. Solo el servidor lo lee/escribe.
 *  private_pairs/{vendedor}_{comprador} { times: [ms] } → límite por pareja.
 *
 * El enlace es subastaloaqui.com/lotDetailView?lotId=ID&k=TOKEN. Aunque alguien encuentre
 * el lote (las lecturas de lotes son públicas), sin el token no lo puede comprar.
 *
 * Controles anti "sacar efectivo de la tarjeta" (vender algo inexistente a un cómplice):
 *  - vendedor con INE (como cualquier vendedor) y comprador con INE verificada;
 *  - tope por operación (PRIVATE_SALE_MAX, $30,000 por defecto);
 *  - máximo PRIVATE_PAIR_LIMIT compras privadas entre la misma pareja cada 30 días;
 *    al pasarlo se rechaza y se pide contactar a soporte (revisión manual);
 *  - el pago sigue el flujo normal: retenido hasta la entrega con código.
 */
const crypto = require("crypto");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { assertAppCheck } = require("./appcheck");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;
const REGION = "us-central1";

const PRIVATE_SALE_MAX = Number(process.env.PRIVATE_SALE_MAX || 30000);
const PRIVATE_PAIR_LIMIT = Number(process.env.PRIVATE_PAIR_LIMIT || 2);
const PAIR_WINDOW_MS = 30 * 86400000;
const SITE = String(process.env.SITE_URL || "https://subastaloaqui.com").replace(/\/+$/, "");

function err(code, message, reason) {
  return new functions.https.HttpsError(code, message, { code: reason });
}

function sameToken(a, b) {
  const x = Buffer.from(String(a || ""));
  const y = Buffer.from(String(b || ""));
  return x.length > 0 && x.length === y.length && crypto.timingSafeEqual(x, y);
}

function linkFor(lotId, token) {
  return `${SITE}/lotDetailView?lotId=${encodeURIComponent(lotId)}&k=${encodeURIComponent(token)}`;
}

/** El vendedor pide (o vuelve a pedir) el enlace de su venta privada. */
async function getPrivateSaleLinkImpl(data, uid) {
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
  const lotId = String((data && data.lotId) || "");
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw new functions.https.HttpsError("invalid-argument", "Falta el artículo.");
  }
  const lotRef = db.collection("lots").doc(lotId);
  const privRef = db.collection("lot_private").doc(lotId);
  return db.runTransaction(async (tx) => {
    const [lotSnap, privSnap] = await Promise.all([tx.get(lotRef), tx.get(privRef)]);
    if (!lotSnap.exists) throw new functions.https.HttpsError("not-found", "No existe el artículo.");
    const lot = lotSnap.data();
    if (lot.seller_uid !== uid) throw new functions.https.HttpsError("permission-denied", "Solo el vendedor.");
    if (lot.private_sale !== true) {
      throw new functions.https.HttpsError("failed-precondition", "Esta publicación no es venta privada.");
    }
    if (privSnap.exists && privSnap.data().token) {
      return { ok: true, link: linkFor(lotId, privSnap.data().token) };
    }
    const token = crypto.randomBytes(12).toString("base64url");
    tx.set(privRef, { token, seller_uid: uid, created_time: FieldValue.serverTimestamp() });
    return { ok: true, link: linkFor(lotId, token) };
  });
}

/**
 * Dentro de la transacción de buyNow (antes de cualquier escritura): valida el
 * enlace y los controles. Lanza HttpsError si no procede; si procede, registra
 * la compra en el contador de la pareja.
 */
async function assertPrivateSaleTx(tx, { lotId, lot, buyer, buyerUid, token, price, nowMs }) {
  const privSnap = await tx.get(db.collection("lot_private").doc(lotId));
  const pairRef = db.collection("private_pairs").doc(`${lot.seller_uid}_${buyerUid}`);
  const pairSnap = await tx.get(pairRef);
  if (!privSnap.exists || !sameToken(token, privSnap.data().token)) {
    throw err("permission-denied",
      "Esta es una venta privada: solo se puede comprar con el enlace que te mandó el vendedor.", "PRIVATE_LINK");
  }
  if (!buyer || buyer.verified !== true) {
    throw err("failed-precondition",
      "Para comprar con enlace privado necesitas verificar tu identidad (INE) en Mi cuenta.", "PRIVATE_NEEDS_ID");
  }
  if (Number(price) > PRIVATE_SALE_MAX) {
    throw err("failed-precondition",
      `Las ventas privadas tienen un tope de $${PRIVATE_SALE_MAX.toLocaleString("es-MX")} por operación.`, "PRIVATE_MAX");
  }
  const recent = ((pairSnap.exists && pairSnap.data().times) || [])
    .filter((t) => typeof t === "number" && nowMs - t < PAIR_WINDOW_MS);
  if (recent.length >= PRIVATE_PAIR_LIMIT) {
    throw err("resource-exhausted",
      "Ya hicieron varias compras privadas entre ustedes este mes. Escríbenos a contacto@subastaloaqui.com para revisarla.",
      "PRIVATE_PAIR_LIMIT");
  }
  return () => tx.set(pairRef, {
    seller_uid: lot.seller_uid,
    buyer_uid: buyerUid,
    times: [...recent, nowMs],
    last_lot_id: lotId,
    updated_time: FieldValue.serverTimestamp(),
  });
}

exports.getPrivateSaleLink = functions.region(REGION).https.onCall((data, context) => {
  assertAppCheck(context);
  return getPrivateSaleLinkImpl(data, context.auth ? context.auth.uid : null);
});

module.exports = {
  ...module.exports,
  PRIVATE_SALE_MAX,
  PRIVATE_PAIR_LIMIT,
  getPrivateSaleLinkImpl,
  assertPrivateSaleTx,
  sameToken,
};
