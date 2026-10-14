/**
 * Notificaciones push (Firebase Cloud Messaging).
 *
 * Cada vez que el servidor crea un aviso en users/{uid}/notifications/{id},
 * este trigger lo manda como push a todos los dispositivos del usuario
 * (users/{uid}/fcm_tokens/{token}). Los tokens que ya no sirven se borran.
 *
 * Así cualquier aviso nuevo (te superaron, ganaste, pago, strike...) llega
 * por push sin tocar el resto del código.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();

const REGION = "us-central1";

// Avisos urgentes: se mandan con prioridad alta.
const URGENT_TYPES = new Set(["outbid", "won", "strike", "win_unpaid"]);

// Errores de FCM que significan "este token ya no existe".
const DEAD_TOKEN_ERRORS = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/** Arma el mensaje FCM (pura, para poder probarla). */
function buildPushMessage(notification, notificationId) {
  const title = String(notification.title || "BidStream").slice(0, 120);
  const body = String(notification.body || "").slice(0, 400);
  const lotId = String(notification.lot_id || "");
  const urgent = URGENT_TYPES.has(notification.type);
  const link = lotId ? `/lotDetailView?lotId=${encodeURIComponent(lotId)}` : "/auctionNotifications";
  return {
    notification: { title, body },
    data: {
      type: String(notification.type || ""),
      lot_id: lotId,
      notification_id: String(notificationId || ""),
      link,
    },
    android: {
      priority: urgent ? "high" : "normal",
      notification: { tag: lotId || undefined, sound: "default" },
    },
    apns: {
      headers: { "apns-priority": urgent ? "10" : "5" },
      payload: { aps: { sound: "default" } },
    },
    webpush: {
      fcmOptions: { link },
      notification: { icon: "/icons/Icon-192.png" },
    },
  };
}

async function sendPushForNotification(uid, notification, notificationId) {
  const db = admin.firestore();
  const tokensSnap = await db.collection("users").doc(uid).collection("fcm_tokens").get();
  const tokens = tokensSnap.docs.map((d) => d.id).filter(Boolean);
  if (tokens.length === 0) return { sent: 0, removed: 0 };

  const message = buildPushMessage(notification, notificationId);
  const res = await admin.messaging().sendEachForMulticast({ ...message, tokens });

  const dead = [];
  res.responses.forEach((r, i) => {
    if (!r.success && r.error && DEAD_TOKEN_ERRORS.has(r.error.code)) dead.push(tokens[i]);
  });
  if (dead.length) {
    const batch = db.batch();
    dead.forEach((t) => batch.delete(db.collection("users").doc(uid).collection("fcm_tokens").doc(t)));
    await batch.commit();
  }
  return { sent: res.successCount, removed: dead.length };
}

exports.onNotificationCreated = functions
  .region(REGION)
  .firestore.document("users/{uid}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    try {
      await sendPushForNotification(context.params.uid, snap.data(), context.params.notificationId);
    } catch (err) {
      // Un push fallido nunca debe romper nada: el aviso sigue en la app.
      functions.logger.error("Push fallido", err);
    }
  });

module.exports = {
  ...module.exports,
  buildPushMessage,
  sendPushForNotification,
};
