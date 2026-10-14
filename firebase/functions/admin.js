/**
 * Verificación de identidad (INE + selfie) y funciones de administrador.
 *
 * Quién es admin: usuarios con el "custom claim" admin == true en su token.
 * Se otorga con: node scripts/set_admin.js correo@ejemplo.com
 * (ver README). Todas las funciones admin lo revisan en el servidor.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { startWinnerPayment } = require("./payments");

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const { FieldValue } = admin.firestore;
const REGION = "us-central1";

const ID_FILES = ["ine_front", "ine_back", "selfie"];

function requireAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
  }
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Solo administradores.");
  }
  return context.auth.uid;
}

function notify(uid, type, title, body, lotId = "") {
  return db.collection("users").doc(uid).collection("notifications").doc().set({
    type,
    title,
    body,
    lot_id: lotId,
    read: false,
    created_time: FieldValue.serverTimestamp(),
  });
}

function auditLog(adminUid, action, target, details = {}) {
  return db.collection("admin_log").add({
    admin_uid: adminUid,
    action,
    target,
    details,
    created_time: FieldValue.serverTimestamp(),
  });
}

// ---------------------------------------------------------------------
// submitIdentityVerification — el usuario ya subió sus 3 fotos a
// Storage (verifications/{uid}/...) y pide revisión.
// ---------------------------------------------------------------------
exports.submitIdentityVerification = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
    }
    const uid = context.auth.uid;
    const files = (data && data.files) || {};

    // Cada archivo debe estar en la carpeta del propio usuario.
    for (const key of ID_FILES) {
      const p = files[key];
      if (typeof p !== "string" || !p.startsWith(`verifications/${uid}/`)) {
        throw new functions.https.HttpsError("invalid-argument", `Falta la foto: ${key}.`);
      }
    }
    // Y debe existir de verdad en Storage.
    const bucket = admin.storage().bucket();
    for (const key of ID_FILES) {
      const [exists] = await bucket.file(files[key]).exists();
      if (!exists) {
        throw new functions.https.HttpsError("invalid-argument", `No encontramos la foto: ${key}.`);
      }
    }

    const ref = db.collection("verifications").doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists && snap.data().status === "approved") {
        throw new functions.https.HttpsError("already-exists", "Tu identidad ya está verificada.");
      }
      const userSnap = await tx.get(db.collection("users").doc(uid));
      const user = userSnap.exists ? userSnap.data() : {};
      tx.set(ref, {
        uid,
        status: "pending",
        files: { ine_front: files.ine_front, ine_back: files.ine_back, selfie: files.selfie },
        full_name: user.full_name || "",
        email: user.email || "",
        submitted_time: FieldValue.serverTimestamp(),
        reviewed_time: null,
        reviewer_uid: null,
        reject_reason: null,
      });
      tx.set(
        db.collection("users").doc(uid),
        { verification_status: "pending" },
        { merge: true }
      );
    });
    return { ok: true, status: "pending" };
  });

// ---------------------------------------------------------------------
// adminReviewVerification — aprobar o rechazar.
// data: { uid, approve: bool, reason?: string }
// ---------------------------------------------------------------------
exports.adminReviewVerification = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const adminUid = requireAdmin(context);
    const uid = String((data && data.uid) || "");
    const approve = data && data.approve === true;
    const reason = String((data && data.reason) || "").slice(0, 300);
    if (!uid) throw new functions.https.HttpsError("invalid-argument", "Falta el usuario.");
    if (!approve && !reason) {
      throw new functions.https.HttpsError("invalid-argument", "Indica el motivo del rechazo.");
    }

    const ref = db.collection("verifications").doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.data().status !== "pending") {
        throw new functions.https.HttpsError("failed-precondition", "No hay solicitud pendiente.");
      }
      tx.update(ref, {
        status: approve ? "approved" : "rejected",
        reviewed_time: FieldValue.serverTimestamp(),
        reviewer_uid: adminUid,
        reject_reason: approve ? null : reason,
      });
      tx.set(
        db.collection("users").doc(uid),
        { verified: approve, verification_status: approve ? "approved" : "rejected" },
        { merge: true }
      );
    });

    await notify(
      uid,
      approve ? "verified" : "verification_rejected",
      approve ? "Identidad verificada" : "No pudimos verificar tu identidad",
      approve
        ? "¡Listo! Ya puedes publicar lotes y hacer pujas altas."
        : `Motivo: ${reason}. Puedes enviar tus fotos de nuevo.`
    );
    await auditLog(adminUid, approve ? "verification_approve" : "verification_reject", uid, { reason });
    return { ok: true };
  });

// ---------------------------------------------------------------------
// adminSetBan — suspender o reactivar una cuenta.
// data: { uid, banned: bool, reason?: string }
// ---------------------------------------------------------------------
exports.adminSetBan = functions.region(REGION).https.onCall(async (data, context) => {
  const adminUid = requireAdmin(context);
  const uid = String((data && data.uid) || "");
  const banned = data && data.banned === true;
  const reason = String((data && data.reason) || "").slice(0, 300);
  if (!uid) throw new functions.https.HttpsError("invalid-argument", "Falta el usuario.");
  if (uid === adminUid) {
    throw new functions.https.HttpsError("failed-precondition", "No puedes suspenderte a ti mismo.");
  }
  await db.collection("users").doc(uid).set(
    { banned, ban_reason: banned ? reason : null, ...(banned ? {} : { strikes: 0 }) },
    { merge: true }
  );
  // Suspender también corta la sesión: revoca sus tokens.
  if (banned) await admin.auth().revokeRefreshTokens(uid);
  await notify(
    uid,
    banned ? "banned" : "unbanned",
    banned ? "Cuenta suspendida" : "Cuenta reactivada",
    banned ? `Motivo: ${reason || "incumplimiento de términos"}.` : "Ya puedes volver a pujar."
  );
  await auditLog(adminUid, banned ? "ban" : "unban", uid, { reason });
  return { ok: true };
});

// ---------------------------------------------------------------------
// adminMarkPayoutSent — registrar que ya se transfirió al vendedor.
// data: { paymentId, reference } (reference = folio / clave de rastreo SPEI)
// ---------------------------------------------------------------------
exports.adminMarkPayoutSent = functions.region(REGION).https.onCall(async (data, context) => {
  const adminUid = requireAdmin(context);
  const paymentId = String((data && data.paymentId) || "");
  const reference = String((data && data.reference) || "").trim().slice(0, 100);
  if (!paymentId || !reference) {
    throw new functions.https.HttpsError("invalid-argument", "Falta el pago o la referencia.");
  }
  const ref = db.collection("payments").doc(paymentId);
  const payout = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.data().kind !== "payout") {
      throw new functions.https.HttpsError("not-found", "Pago no encontrado.");
    }
    if (snap.data().status !== "ready") {
      throw new functions.https.HttpsError("failed-precondition", "Este pago ya fue marcado.");
    }
    tx.update(ref, {
      status: "sent",
      transfer_reference: reference,
      sent_by: adminUid,
      sent_time: FieldValue.serverTimestamp(),
      updated_time: FieldValue.serverTimestamp(),
    });
    return snap.data();
  });
  await notify(
    payout.uid,
    "payout_sent",
    "Te transferimos tu pago",
    `Enviamos $${Number(payout.amount).toLocaleString("es-MX")}. Referencia: ${reference}.`,
    payout.lot_id || ""
  );
  await auditLog(adminUid, "payout_sent", paymentId, { reference, amount: payout.amount });
  return { ok: true };
});

// ---------------------------------------------------------------------
// adminRetryWinnerPayment — Mercado Pago falló al cerrar: reintentar.
// ---------------------------------------------------------------------
exports.adminRetryWinnerPayment = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const adminUid = requireAdmin(context);
    const lotId = String((data && data.lotId) || "");
    const lotRef = db.collection("lots").doc(lotId);
    const snap = await lotRef.get();
    if (!snap.exists) throw new functions.https.HttpsError("not-found", "Lote no encontrado.");
    const lot = snap.data();
    if (!["payment_error", "processing"].includes(lot.payment_status) || !lot.winner_uid) {
      throw new functions.https.HttpsError("failed-precondition", "Este lote no necesita reintento.");
    }
    const pay = await startWinnerPayment(lotRef, lot, lot.winner_uid);
    if (pay.error) {
      throw new functions.https.HttpsError("unavailable", "Mercado Pago sigue sin responder.");
    }
    if (pay.url) {
      await notify(
        lot.winner_uid,
        "won",
        `Tu enlace de pago está listo: ${lot.title}`,
        `Paga $${Number(pay.amount).toLocaleString("es-MX")} desde el detalle del lote.`,
        lotId
      );
    }
    await auditLog(adminUid, "retry_winner_payment", lotId, {});
    return { ok: true, url: pay.url || null };
  });

// ---------------------------------------------------------------------
// adminCancelLot — cancelar una subasta activa (fraude, contenido
// prohibido...). Avisa al vendedor y a quien iba ganando.
// ---------------------------------------------------------------------
exports.adminCancelLot = functions.region(REGION).https.onCall(async (data, context) => {
  const adminUid = requireAdmin(context);
  const lotId = String((data && data.lotId) || "");
  const reason = String((data && data.reason) || "").trim().slice(0, 300);
  if (!lotId || !reason) {
    throw new functions.https.HttpsError("invalid-argument", "Falta el lote o el motivo.");
  }
  const lotRef = db.collection("lots").doc(lotId);
  const lot = await db.runTransaction(async (tx) => {
    const snap = await tx.get(lotRef);
    if (!snap.exists) throw new functions.https.HttpsError("not-found", "Lote no encontrado.");
    if (snap.data().status !== "active") {
      throw new functions.https.HttpsError("failed-precondition", "Solo se cancelan subastas activas.");
    }
    tx.update(lotRef, {
      status: "cancelled",
      cancel_reason: reason,
      cancelled_by: adminUid,
      cancelled_time: FieldValue.serverTimestamp(),
    });
    return snap.data();
  });
  await notify(lot.seller_uid, "lot_cancelled", `Cancelamos tu subasta: ${lot.title}`, `Motivo: ${reason}.`, lotId);
  if (lot.highest_bidder_uid) {
    await notify(
      lot.highest_bidder_uid,
      "lot_cancelled",
      `Subasta cancelada: ${lot.title}`,
      "La plataforma canceló esta subasta. No se te cobrará nada.",
      lotId
    );
  }
  await auditLog(adminUid, "cancel_lot", lotId, { reason });
  return { ok: true };
});

module.exports = { ...module.exports, ID_FILES };
