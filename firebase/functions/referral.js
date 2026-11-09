/**
 * Códigos de referido para promotores (tiktokers, practicantes, comercios).
 *
 *  referral_codes/{CODE}  { name, active, signups, buyers_purchases,
 *                           buyers_amount, sellers_sales, sellers_amount }
 *  users/{uid}.referred_by = CODE   (solo lo escribe el servidor)
 *
 * El enlace es subastaloaqui.com/?ref=CODE. La app lo guarda y, cuando la
 * persona crea su cuenta (o entra por primera vez), llama a claimReferral.
 * Solo cuenta para cuentas nuevas (menos de 14 días), una vez por usuario,
 * y nunca para el propio dueño del código. Las ventas se atribuyen en la
 * liquidación (writeSettlement → recordReferralSale).
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { assertAppCheck } = require("./appcheck");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;
const REGION = "us-central1";
const NEW_ACCOUNT_DAYS = 14;

function normalizeCode(raw) {
  const code = String(raw || "").trim().toUpperCase();
  return /^[A-Z0-9]{3,20}$/.test(code) ? code : null;
}

async function claimReferralImpl(data, uid, nowMs = Date.now()) {
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
  const code = normalizeCode(data && data.code);
  if (!code) return { ok: false, reason: "INVALID" };
  const userRef = db.collection("users").doc(uid);
  const codeRef = db.collection("referral_codes").doc(code);
  return db.runTransaction(async (tx) => {
    const [userSnap, codeSnap] = await Promise.all([tx.get(userRef), tx.get(codeRef)]);
    if (!userSnap.exists) return { ok: false, reason: "NO_PROFILE" };
    const user = userSnap.data();
    if (user.referred_by) return { ok: false, reason: "ALREADY" };
    if (!codeSnap.exists || codeSnap.data().active === false) return { ok: false, reason: "UNKNOWN_CODE" };
    if (codeSnap.data().owner_uid && codeSnap.data().owner_uid === uid) return { ok: false, reason: "OWN_CODE" };
    const created = user.created_time && user.created_time.toMillis ? user.created_time.toMillis() : null;
    if (created && nowMs - created > NEW_ACCOUNT_DAYS * 86400000) return { ok: false, reason: "NOT_NEW" };
    tx.update(userRef, { referred_by: code, referred_time: FieldValue.serverTimestamp() });
    tx.set(codeRef, { signups: FieldValue.increment(1), updated_time: FieldValue.serverTimestamp() }, { merge: true });
    return { ok: true, code };
  });
}

/** Dentro de la liquidación: suma la compra/venta al código de quien la trajo. */
function recordReferralSale(writer, { buyer, seller, amount }) {
  const amt = Math.round((Number(amount) || 0) * 100) / 100;
  const b = normalizeCode(buyer && buyer.referred_by);
  const s = normalizeCode(seller && seller.referred_by);
  if (b) {
    writer.set(db.collection("referral_codes").doc(b), {
      buyers_purchases: FieldValue.increment(1),
      buyers_amount: FieldValue.increment(amt),
    }, { merge: true });
  }
  if (s) {
    writer.set(db.collection("referral_codes").doc(s), {
      sellers_sales: FieldValue.increment(1),
      sellers_amount: FieldValue.increment(amt),
    }, { merge: true });
  }
}

async function createReferralCodeImpl(data, adminUid) {
  const code = normalizeCode(data && data.code);
  if (!code) throw new functions.https.HttpsError("invalid-argument", "Código inválido: 3 a 20 letras o números, sin espacios.");
  const name = String((data && data.name) || "").trim().slice(0, 80);
  if (name.length < 2) throw new functions.https.HttpsError("invalid-argument", "Escribe el nombre del promotor.");
  const ref = db.collection("referral_codes").doc(code);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) throw new functions.https.HttpsError("already-exists", "Ese código ya existe.");
    tx.set(ref, {
      name,
      active: true,
      signups: 0,
      buyers_purchases: 0,
      buyers_amount: 0,
      sellers_sales: 0,
      sellers_amount: 0,
      created_by: adminUid,
      created_time: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true, code, link: `https://subastaloaqui.com/?ref=${code}` };
}

exports.claimReferral = functions.region(REGION).https.onCall((data, context) => {
  assertAppCheck(context);
  return claimReferralImpl(data, context.auth ? context.auth.uid : null);
});

exports.adminCreateReferralCode = functions.region(REGION).https.onCall((data, context) => {
  assertAppCheck(context);
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Solo administradores.");
  }
  return createReferralCodeImpl(data, context.auth.uid);
});

module.exports = { ...module.exports, normalizeCode, claimReferralImpl, recordReferralSale, createReferralCodeImpl };
