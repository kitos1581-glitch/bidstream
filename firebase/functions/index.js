const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { validateBid, publicName } = require("./auction_logic");

admin.initializeApp();
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const REGION = "us-central1";

function notificationRef(uid) {
  return db.collection("users").doc(uid).collection("notifications").doc();
}

function formatMoney(n) {
  return `$${Number(n).toLocaleString("es-MX", { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
}

// ---------------------------------------------------------------------
// placeBid: única forma de pujar. Valida todo en el servidor dentro
// de una transacción para que dos pujas simultáneas no se pisen.
// data: { lotId: string, amount: number }
// ---------------------------------------------------------------------
exports.placeBid = functions.region(REGION).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Inicia sesión para pujar.");
  }
  if (context.auth.token.email_verified !== true) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Verifica tu correo electrónico antes de pujar."
    );
  }

  const uid = context.auth.uid;
  const lotId = String((data && data.lotId) || "");
  const amount = Number(data && data.amount);
  if (!lotId) {
    throw new functions.https.HttpsError("invalid-argument", "Falta el lote.");
  }

  const userSnap = await db.collection("users").doc(uid).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || !user.full_name || !user.phone || user.accepted_terms !== true) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Completa tu perfil (nombre, teléfono y términos) antes de pujar."
    );
  }
  if (user.banned === true) {
    throw new functions.https.HttpsError("permission-denied", "Tu cuenta está suspendida.");
  }

  const bidderName = publicName(user.full_name);
  const lotRef = db.collection("lots").doc(lotId);

  const result = await db.runTransaction(async (tx) => {
    const lotSnap = await tx.get(lotRef);
    if (!lotSnap.exists) {
      throw new functions.https.HttpsError("not-found", "El lote no existe.");
    }
    const lot = lotSnap.data();
    const nowMs = Date.now();
    const check = validateBid(
      {
        ...lot,
        start_time_ms: lot.start_time ? lot.start_time.toMillis() : null,
        end_time_ms: lot.end_time ? lot.end_time.toMillis() : null,
      },
      amount,
      uid,
      nowMs
    );
    if (!check.ok) {
      throw new functions.https.HttpsError(check.code, check.message, {
        minimum: check.minimum || null,
      });
    }

    const now = Timestamp.fromMillis(nowMs);
    const bidRef = lotRef.collection("bids").doc();
    tx.set(bidRef, {
      bidder_uid: uid,
      bidder_name: bidderName,
      amount: check.amount,
      created_time: now,
    });

    tx.update(lotRef, {
      current_bid: check.amount,
      bid_count: FieldValue.increment(1),
      highest_bidder_uid: uid,
      highest_bidder_name: bidderName,
      last_bid_time: now,
      end_time: Timestamp.fromMillis(check.newEndTimeMs),
    });

    tx.set(
      db.collection("users").doc(uid).collection("bidding").doc(lotId),
      {
        lot_id: lotId,
        lot_title: lot.title || "",
        lot_image: (lot.image_urls && lot.image_urls[0]) || "",
        my_max_bid: check.amount,
        last_bid_time: now,
      },
      { merge: true }
    );

    return {
      previousBidderUid: lot.highest_bidder_uid || null,
      lotTitle: lot.title || "",
      amount: check.amount,
      extended: check.extended,
      newEndTimeMs: check.newEndTimeMs,
    };
  });

  // Avisar al que fue superado (fuera de la transacción).
  if (result.previousBidderUid && result.previousBidderUid !== uid) {
    await notificationRef(result.previousBidderUid).set({
      type: "outbid",
      title: `Te superaron: ${result.lotTitle}`,
      body: `Nueva puja de ${formatMoney(result.amount)}. ¡Todavía puedes recuperarla!`,
      lot_id: lotId,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
  }

  return {
    ok: true,
    amount: result.amount,
    extended: result.extended,
    endTime: result.newEndTimeMs,
  };
});

// ---------------------------------------------------------------------
// closeEndedAuctions: cada minuto cierra las subastas vencidas,
// asigna ganador y avisa a ganador y vendedor.
// ---------------------------------------------------------------------
async function closeLot(lotRef) {
  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(lotRef);
    if (!snap.exists) return null;
    const lot = snap.data();
    if (lot.status !== "active") return null;
    if (!lot.end_time || lot.end_time.toMillis() > Date.now()) return null;

    const hasWinner = (lot.bid_count || 0) > 0 && lot.highest_bidder_uid;
    tx.update(lotRef, {
      status: "ended",
      closed_time: FieldValue.serverTimestamp(),
      winner_uid: hasWinner ? lot.highest_bidder_uid : null,
      winner_name: hasWinner ? lot.highest_bidder_name || "" : null,
      final_price: hasWinner ? lot.current_bid : null,
    });
    return { lot, hasWinner };
  });
  if (!outcome) return false;

  const { lot, hasWinner } = outcome;

  // Intercambio de contacto: solo se comparte entre ganador y vendedor,
  // dentro de sus notificaciones privadas.
  async function contactOf(uid) {
    const snap = await db.collection("users").doc(uid).get();
    const u = snap.exists ? snap.data() : {};
    const parts = [u.full_name, u.phone && `Tel/WhatsApp: ${u.phone}`, u.city]
      .filter(Boolean);
    return parts.length ? parts.join(" · ") : "sin datos de contacto";
  }

  const batch = db.batch();
  if (hasWinner) {
    const [sellerContact, winnerContact] = await Promise.all([
      contactOf(lot.seller_uid),
      contactOf(lot.highest_bidder_uid),
    ]);
    batch.set(notificationRef(lot.highest_bidder_uid), {
      type: "won",
      title: `¡Ganaste! ${lot.title}`,
      body: `Ganaste con ${formatMoney(lot.current_bid)}. Contacta al vendedor: ${sellerContact}.`,
      lot_id: lotRef.id,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
    batch.set(notificationRef(lot.seller_uid), {
      type: "sold",
      title: `Vendiste: ${lot.title}`,
      body: `Se vendió en ${formatMoney(lot.current_bid)}. Comprador: ${winnerContact}.`,
      lot_id: lotRef.id,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
  } else {
    batch.set(notificationRef(lot.seller_uid), {
      type: "unsold",
      title: `Sin pujas: ${lot.title}`,
      body: "Tu subasta terminó sin pujas. Puedes publicarla de nuevo.",
      lot_id: lotRef.id,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  return true;
}

exports.closeEndedAuctions = functions
  .region(REGION)
  .pubsub.schedule("every 1 minutes")
  .onRun(async () => {
    const snap = await db
      .collection("lots")
      .where("status", "==", "active")
      .where("end_time", "<=", Timestamp.now())
      .orderBy("end_time", "asc")
      .limit(200)
      .get();

    let closed = 0;
    for (const doc of snap.docs) {
      try {
        if (await closeLot(doc.ref)) closed++;
      } catch (err) {
        functions.logger.error(`No se pudo cerrar ${doc.id}`, err);
      }
    }
    functions.logger.info(`Subastas cerradas: ${closed}`);
    return null;
  });

// ---------------------------------------------------------------------
// Datos del vendedor: al crear un lote, el servidor pone el nombre
// público del vendedor (el cliente no puede falsificarlo).
// ---------------------------------------------------------------------
exports.onLotCreated = functions
  .region(REGION)
  .firestore.document("lots/{lotId}")
  .onCreate(async (snap) => {
    const lot = snap.data();
    const userSnap = await db.collection("users").doc(lot.seller_uid).get();
    const fullName = userSnap.exists ? userSnap.data().full_name : "";
    await snap.ref.update({ seller_name: publicName(fullName) });
  });
