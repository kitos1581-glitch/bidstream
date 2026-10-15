/**
 * Reputación de vendedores (calificaciones, insignias y perfil público).
 *
 * - feedback/{lotId}: una calificación por venta. Solo la crea el COMPRADOR
 *   que pagó (lot.winner_uid == uid y payment_status == "paid"). Editable
 *   7 días. Una disputa abierta en el lote la bloquea.
 * - public_profiles/{uid}: lo único público de un usuario (nombre público,
 *   verificado, promedio, número de calificaciones y de ventas, insignias).
 *   Nunca teléfono ni correo: el contacto se libera solo tras el pago.
 * Todo lo escribe el servidor; las reglas lo dejan de solo lectura.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { assertAppCheck } = require("./appcheck");
const { publicName } = require("./auction_logic");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;
const REGION = "us-central1";

const EDIT_WINDOW_MS = 7 * 24 * 3600 * 1000;
const MAX_COMMENT = 500;

const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: "UNAUTHENTICATED",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
  LOT_NOT_FOUND: "LOT_NOT_FOUND",
  NOT_BUYER: "NOT_BUYER",
  NOT_PAID: "NOT_PAID",
  DISPUTE_OPEN: "DISPUTE_OPEN",
  ALREADY_RATED: "ALREADY_RATED",
  NOT_FOUND: "NOT_FOUND",
  EDIT_WINDOW_CLOSED: "EDIT_WINDOW_CLOSED",
});

function fail(httpsCode, code, message) {
  return new functions.https.HttpsError(httpsCode, message, { code });
}

/** Insignias a partir de los agregados (función pura). */
function computeBadges({ verified, sales_count: sales = 0, rating_avg: avg = 0, rating_count: count = 0, open_disputes: disputes = 0 }) {
  const badges = [];
  if (verified) badges.push("verificado");
  if (disputes > 0) badges.push("en_disputa");
  else if (sales >= 10 && count > 0 && avg >= 4.5) badges.push("destacado");
  if (sales < 3) badges.push("nuevo");
  return badges;
}

function round1(n) {
  return Math.round(n * 10) / 10;
}

/** Valida y normaliza { lotId, rating, comment }. */
function parseInput(data) {
  const lotId = String((data && data.lotId) || "");
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Lote inválido.");
  }
  const rating = Number(data && data.rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "La calificación debe ser de 1 a 5 estrellas.");
  }
  const comment = String((data && data.comment) || "").trim();
  if (comment.length > MAX_COMMENT) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, `El comentario admite hasta ${MAX_COMMENT} caracteres.`);
  }
  // Sin datos de contacto en comentarios públicos.
  const clean = comment
    .replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, "[correo oculto]")
    .replace(/(\+?\d[\d\s-]{8,}\d)/g, "[teléfono oculto]");
  return { lotId, rating, comment: clean };
}

/** Recalcula agregados del perfil público dentro de una transacción. */
function profilePatch(current, { addSum = 0, addCount = 0 }, seller) {
  const ratingSum = (Number(current.rating_sum) || 0) + addSum;
  const ratingCount = (Number(current.rating_count) || 0) + addCount;
  const ratingAvg = ratingCount > 0 ? round1(ratingSum / ratingCount) : 0;
  const verified = seller ? seller.verified === true : current.verified === true;
  const sales = Number(current.sales_count) || 0;
  return {
    display_name: seller ? publicName(seller.full_name || "") : current.display_name || "",
    verified,
    rating_sum: ratingSum,
    rating_count: ratingCount,
    rating_avg: ratingAvg,
    sales_count: sales,
    badges: computeBadges({
      verified,
      sales_count: sales,
      rating_avg: ratingAvg,
      rating_count: ratingCount,
      open_disputes: Number(current.open_disputes) || 0,
    }),
    updated_time: FieldValue.serverTimestamp(),
  };
}

async function submitFeedbackImpl(data, uid, nowMs = Date.now()) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const { lotId, rating, comment } = parseInput(data);
  const lotRef = db.collection("lots").doc(lotId);
  const fbRef = db.collection("feedback").doc(lotId);

  return db.runTransaction(async (tx) => {
    const [lotSnap, fbSnap] = await Promise.all([tx.get(lotRef), tx.get(fbRef)]);
    if (!lotSnap.exists) throw fail("not-found", ERROR_CODES.LOT_NOT_FOUND, "Este lote ya no existe.");
    const lot = lotSnap.data();
    if (lot.winner_uid !== uid) {
      throw fail("permission-denied", ERROR_CODES.NOT_BUYER, "Solo quien compró puede calificar esta venta.");
    }
    if (lot.payment_status !== "paid") {
      throw fail("failed-precondition", ERROR_CODES.NOT_PAID, "Podrás calificar cuando el pago esté confirmado.");
    }
    if (lot.dispute_status === "open") {
      throw fail("failed-precondition", ERROR_CODES.DISPUTE_OPEN, "Hay una disputa abierta en esta compra; califica cuando se resuelva.");
    }
    if (fbSnap.exists) {
      throw fail("already-exists", ERROR_CODES.ALREADY_RATED, "Ya calificaste esta compra. Puedes editarla durante 7 días.");
    }
    const sellerUid = lot.seller_uid;
    const profRef = db.collection("public_profiles").doc(sellerUid);
    const [profSnap, sellerSnap, buyerSnap] = await Promise.all([
      tx.get(profRef),
      tx.get(db.collection("users").doc(sellerUid)),
      tx.get(db.collection("users").doc(uid)),
    ]);

    tx.set(fbRef, {
      lot_id: lotId,
      lot_title: String(lot.title || "").slice(0, 120),
      rating,
      comment,
      author_uid: uid,
      author_name: publicName(buyerSnap.exists ? buyerSnap.data().full_name || "" : ""),
      seller_uid: sellerUid,
      created_time: FieldValue.serverTimestamp(),
      updated_time: FieldValue.serverTimestamp(),
      editable_until: Timestamp.fromMillis(nowMs + EDIT_WINDOW_MS),
    });
    tx.set(
      profRef,
      profilePatch(profSnap.exists ? profSnap.data() : {}, { addSum: rating, addCount: 1 }, sellerSnap.exists ? sellerSnap.data() : null),
      { merge: true }
    );
    tx.set(db.collection("users").doc(sellerUid).collection("notifications").doc(), {
      type: "feedback_received",
      title: `Te calificaron con ${rating} ${rating === 1 ? "estrella" : "estrellas"}`,
      body: comment ? `"${comment.slice(0, 120)}"` : `Venta: ${lot.title || ""}`,
      lot_id: lotId,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
    return { ok: true, lotId, rating };
  });
}

async function updateFeedbackImpl(data, uid, nowMs = Date.now()) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const { lotId, rating, comment } = parseInput(data);
  const fbRef = db.collection("feedback").doc(lotId);
  const lotRef = db.collection("lots").doc(lotId);

  return db.runTransaction(async (tx) => {
    const [fbSnap, lotSnap] = await Promise.all([tx.get(fbRef), tx.get(lotRef)]);
    if (!fbSnap.exists) throw fail("not-found", ERROR_CODES.NOT_FOUND, "No encontramos tu calificación.");
    const fb = fbSnap.data();
    if (fb.author_uid !== uid) {
      throw fail("permission-denied", ERROR_CODES.NOT_BUYER, "Solo quien calificó puede editar.");
    }
    const until = fb.editable_until && fb.editable_until.toMillis ? fb.editable_until.toMillis() : 0;
    if (until <= nowMs) {
      throw fail("failed-precondition", ERROR_CODES.EDIT_WINDOW_CLOSED, "Ya pasaron los 7 días para editar esta calificación.");
    }
    if (lotSnap.exists && lotSnap.data().dispute_status === "open") {
      throw fail("failed-precondition", ERROR_CODES.DISPUTE_OPEN, "Hay una disputa abierta en esta compra.");
    }
    const profRef = db.collection("public_profiles").doc(fb.seller_uid);
    const profSnap = await tx.get(profRef);
    tx.update(fbRef, { rating, comment, updated_time: FieldValue.serverTimestamp() });
    tx.set(
      profRef,
      profilePatch(profSnap.exists ? profSnap.data() : {}, { addSum: rating - Number(fb.rating || 0), addCount: 0 }, null),
      { merge: true }
    );
    return { ok: true, lotId, rating };
  });
}

/**
 * Llamado desde writeSettlement (venta pagada) con el mismo escritor
 * (transacción o batch): suma una venta al perfil público del vendedor.
 */
function recordSale(writer, sellerUid) {
  writer.set(
    db.collection("public_profiles").doc(sellerUid),
    { sales_count: FieldValue.increment(1), updated_time: FieldValue.serverTimestamp() },
    { merge: true }
  );
}

/** Recalcula insignias tras cambios (venta, verificación). */
async function refreshProfile(uid) {
  const profRef = db.collection("public_profiles").doc(uid);
  await db.runTransaction(async (tx) => {
    const [profSnap, userSnap] = await Promise.all([tx.get(profRef), tx.get(db.collection("users").doc(uid))]);
    tx.set(profRef, profilePatch(profSnap.exists ? profSnap.data() : {}, {}, userSnap.exists ? userSnap.data() : null), {
      merge: true,
    });
  });
}

exports.submitFeedback = functions.region(REGION).https.onCall((data, context) => {
  assertAppCheck(context);
  return submitFeedbackImpl(data, context.auth ? context.auth.uid : null);
});

exports.updateFeedback = functions.region(REGION).https.onCall((data, context) => {
  assertAppCheck(context);
  return updateFeedbackImpl(data, context.auth ? context.auth.uid : null);
});

// Insignias al día cuando cambian ventas o verificación.
exports.onPublicProfileInputs = functions
  .region(REGION)
  .firestore.document("users/{uid}")
  .onUpdate(async (change, context) => {
    const a = change.before.data() || {};
    const b = change.after.data() || {};
    if (a.verified === b.verified && a.full_name === b.full_name) return;
    await refreshProfile(context.params.uid);
  });

exports.onSaleRecorded = functions
  .region(REGION)
  .firestore.document("public_profiles/{uid}")
  .onWrite(async (change, context) => {
    const a = change.before.exists ? change.before.data() : {};
    const b = change.after.exists ? change.after.data() : null;
    if (!b) return;
    if ((a.sales_count || 0) === (b.sales_count || 0) && (a.open_disputes || 0) === (b.open_disputes || 0)) return;
    await refreshProfile(context.params.uid);
  });

module.exports = {
  ...module.exports,
  ERROR_CODES,
  computeBadges,
  parseInput,
  submitFeedbackImpl,
  updateFeedbackImpl,
  recordSale,
  refreshProfile,
  EDIT_WINDOW_MS,
};
