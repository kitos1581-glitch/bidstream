const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Guarda: permite cargar index.js aunque otro módulo ya haya inicializado.
if (!admin.apps.length) admin.initializeApp();

const { validateBid, publicName } = require("./auction_logic");
const { startWinnerPayment } = require("./payments");

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const REGION = "us-central1";

function notificationRef(uid) {
  return db.collection("users").doc(uid).collection("notifications").doc();
}

function formatMoney(n) {
  return `$${Number(n).toLocaleString("es-MX", { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
}

function contactString(u) {
  const parts = [u.full_name, u.phone && `Tel/WhatsApp: ${u.phone}`, u.city].filter(Boolean);
  return parts.length ? parts.join(" · ") : "sin datos de contacto";
}

// ---------------------------------------------------------------------
// placeBid: única forma de pujar. Valida todo en el servidor dentro
// de una transacción para que dos pujas simultáneas no se pisen.
// REQUIERE depósito de garantía activo (users/{uid}.deposit.status == 'held').
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
  // ---- Escrow: sin depósito en garantía no se puja. ----
  if (!user.deposit || user.deposit.status !== "held") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Debes dejar un depósito de garantía antes de pujar. Es reembolsable.",
      { code: "DEPOSIT_REQUIRED" }
    );
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
// asigna ganador, genera su pago y avisa a las partes.
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
      // Sin pujas no hay nada que cobrar; con ganador queda 'pending' hasta
      // que pague (lo pone startWinnerPayment) o venza (expireUnpaidWins).
      payment_status: hasWinner ? "pending" : "none",
    });
    return { lot, hasWinner };
  });
  if (!outcome) return false;

  const { lot, hasWinner } = outcome;

  if (hasWinner) {
    // Datos de contacto para el intercambio y depósito del ganador.
    const [sellerSnap, winnerSnap] = await Promise.all([
      db.collection("users").doc(lot.seller_uid).get(),
      db.collection("users").doc(lot.highest_bidder_uid).get(),
    ]);
    const seller = sellerSnap.exists ? sellerSnap.data() : {};
    const winner = winnerSnap.exists ? winnerSnap.data() : {};
    const sellerContact = contactString(seller);
    const winnerContact = contactString(winner);

    // Generar el cobro del ganador (precio final − depósito).
    let pay;
    try {
      pay = await startWinnerPayment(lotRef, lot, lot.highest_bidder_uid, winner);
    } catch (err) {
      functions.logger.error(`No se pudo generar el cobro de ${lotRef.id}`, err);
      pay = { url: null, amount: 0, alreadySettled: false };
    }

    const depositApplied =
      winner.deposit && winner.deposit.status === "held" ? Number(winner.deposit.amount) : 0;
    const winnerBody = pay.alreadySettled
      ? `Tu depósito cubre los ${formatMoney(lot.current_bid)}. Contacta al vendedor: ${sellerContact}.`
      : `Ganaste con ${formatMoney(lot.current_bid)}. Tienes 24 horas para pagar ${formatMoney(
          pay.amount
        )}${depositApplied ? ` (tu depósito de ${formatMoney(depositApplied)} ya está aplicado)` : ""}.`;

    const batch = db.batch();
    batch.set(notificationRef(lot.highest_bidder_uid), {
      type: "won",
      title: `¡Ganaste! ${lot.title}`,
      body: winnerBody,
      lot_id: lotRef.id,
      action_url: pay.url || "",
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
    batch.set(notificationRef(lot.seller_uid), {
      type: "sold",
      title: `Vendiste: ${lot.title}`,
      body: `Se vendió en ${formatMoney(lot.current_bid)}. Comprador: ${winnerContact}. Te avisaremos cuando el pago quede registrado.`,
      lot_id: lotRef.id,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
    await batch.commit();
  } else {
    await notificationRef(lot.seller_uid).set({
      type: "unsold",
      title: `Sin pujas: ${lot.title}`,
      body: "Tu subasta terminó sin pujas. Puedes publicarla de nuevo.",
      lot_id: lotRef.id,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
  }
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
