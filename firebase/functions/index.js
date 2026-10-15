const functions = require("firebase-functions");
const { assertAppCheck } = require("./appcheck");
const admin = require("firebase-admin");

// Guarda: permite cargar index.js aunque otro módulo ya haya inicializado.
if (!admin.apps.length) admin.initializeApp();

const {
  resolveProxyBid,
  applyReserve,
  legacyState,
  publicName,
  userBidEligibilityError,
} = require("./auction_logic");
const payments = require("./payments");
const { startWinnerPayment, WINNER_PAYMENT_WINDOW_HOURS } = payments;

// Funciones de pagos: DEBEN exportarse desde index.js para que Firebase
// las despliegue.
exports.createDeposit = payments.createDeposit;
exports.requestDepositRefund = payments.requestDepositRefund;
exports.expireUnpaidWins = payments.expireUnpaidWins;
exports.mpWebhook = payments.mpWebhook;

// Pago final por SPEI (Openpay), opcional junto a Mercado Pago.
const spei = require("./spei");
exports.chooseWinnerPaymentMethod = spei.chooseWinnerPaymentMethod;
exports.openpayWebhook = spei.openpayWebhook;

// Reputación: calificaciones y perfil público del vendedor.
const reputation = require("./reputation");
exports.submitFeedback = reputation.submitFeedback;
exports.updateFeedback = reputation.updateFeedback;
exports.onPublicProfileInputs = reputation.onPublicProfileInputs;
exports.onSaleRecorded = reputation.onSaleRecorded;

// Protección al comprador: disputas.
const disputes = require("./disputes");
exports.openDispute = disputes.openDispute;
exports.adminResolveDispute = disputes.adminResolveDispute;

// Retención del pago al vendedor hasta confirmar la entrega.
const escrow = require("./escrow");
exports.confirmReceipt = escrow.confirmReceipt;
exports.releaseDuePayoutsJob = escrow.releaseDuePayoutsJob;

// Precio de reserva (secreto) para subastas por tiempo.
exports.setReservePrice = require("./reserve").setReservePrice;

// Segunda oportunidad al subcampeón cuando el ganador no paga.
exports.respondSecondChance = require("./second_chance").respondSecondChance;

// Tarjeta para compartir lotes en redes (Open Graph).
exports.lotPreview = require("./share").lotPreview;

// Verificación de identidad y panel de administrador.
const adminFns = require("./admin");
exports.submitIdentityVerification = adminFns.submitIdentityVerification;
exports.adminReviewVerification = adminFns.adminReviewVerification;
exports.adminSetBan = adminFns.adminSetBan;
exports.adminMarkPayoutSent = adminFns.adminMarkPayoutSent;
exports.adminRetryWinnerPayment = adminFns.adminRetryWinnerPayment;
exports.adminCancelLot = adminFns.adminCancelLot;
exports.adminRecalculatePayout = adminFns.adminRecalculatePayout;

// Pujas altas requieren identidad verificada (INE). Monto en MXN.
const VERIFIED_BID_THRESHOLD = Number(process.env.VERIFIED_BID_THRESHOLD || 20000);

// Asistente de IA para describir lotes.
exports.generateLotDescription = require("./ai").generateLotDescription;

// Notificaciones push: cada aviso nuevo se manda al celular.
exports.onNotificationCreated = require("./push").onNotificationCreated;

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
// placeBid: única forma de pujar. PUJA PROXY + ANTI-SNIPING DE 30 s.
//
// El postor manda su MÁXIMO secreto. Dentro de una transacción:
//   1. Se lee el lote y el estado privado del proxy (líder + su máximo).
//   2. resolveProxyBid() decide nuevo precio visible, líder y cierre.
//   3. Se escriben: la oferta (bids, privada), el historial público
//      (history), el estado privado y el lote.
// Si dos personas pujan al mismo tiempo, Firestore reintenta la transacción
// de la que llegó después con los datos ya actualizados (sin carreras).
//
// Requiere: sesión, correo verificado, perfil completo, no baneado y
// depósito de garantía activo (users/{uid}.deposit.status == 'held').
//
// data: { lotId: string, max_amount: number }   (acepta `amount` por compatibilidad)
// ---------------------------------------------------------------------
exports.placeBid = functions.region(REGION).https.onCall(async (data, context) => {
  assertAppCheck(context);
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
  const rawMax = data && (data.max_amount !== undefined ? data.max_amount : data.amount);
  const maxAmount = Number(rawMax);
  if (!lotId) {
    throw new functions.https.HttpsError("invalid-argument", "Falta el lote.");
  }

  if (!Number.isFinite(maxAmount) || maxAmount <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Monto inválido.");
  }

  // Revisión rápida (antes de la transacción) para responder pronto.
  // La decisión definitiva se toma DENTRO de la transacción con datos frescos.
  const userSnap = await db.collection("users").doc(uid).get();
  const preErr = userBidEligibilityError(
    userSnap.exists ? userSnap.data() : null,
    maxAmount,
    VERIFIED_BID_THRESHOLD
  );
  if (preErr) throw new functions.https.HttpsError(preErr.code, preErr.message, preErr.details);

  const lotRef = db.collection("lots").doc(lotId);
  // Estado privado del proxy: nadie lo puede leer desde la app (firestore.rules).
  const stateRef = lotRef.collection("private").doc("proxy_state");
  // Precio de reserva: también privado (nadie lo lee desde la app).
  const reserveRef = lotRef.collection("private").doc("reserve");

  const result = await db.runTransaction(async (tx) => {
    // En una transacción, TODAS las lecturas van antes de las escrituras.
    const userRef = db.collection("users").doc(uid);
    const [lotSnap, stateSnap, freshUser, reserveSnap] = await Promise.all([
      tx.get(lotRef),
      tx.get(stateRef),
      tx.get(userRef),
      tx.get(reserveRef),
    ]);
    if (!lotSnap.exists) {
      throw new functions.https.HttpsError("not-found", "El lote no existe.");
    }
    // Perfil, términos, identidad, suspensión y depósito se revalidan
    // DENTRO de la transacción: si cambiaron en medio (p. ej. pidió el
    // reembolso o un admin lo suspendió), esta puja se rechaza.
    const freshErr = userBidEligibilityError(
      freshUser.exists ? freshUser.data() : null,
      maxAmount,
      VERIFIED_BID_THRESHOLD
    );
    if (freshErr) {
      throw new functions.https.HttpsError(freshErr.code, freshErr.message, freshErr.details);
    }
    const bidderName = publicName(freshUser.data().full_name);
    const lot = lotSnap.data();
    const state = stateSnap.exists ? stateSnap.data() : legacyState(lot);

    // La hora se toma DENTRO de la transacción: si Firestore la reintenta,
    // se vuelve a calcular con el momento real del reintento.
    const nowMs = Date.now();
    const reserve = reserveSnap.exists ? Number(reserveSnap.data().amount) || 0 : 0;
    const r0 = resolveProxyBid(
      {
        ...lot,
        start_time_ms: lot.start_time ? lot.start_time.toMillis() : null,
        end_time_ms: lot.end_time ? lot.end_time.toMillis() : null,
      },
      state,
      uid,
      maxAmount,
      nowMs
    );
    const r = applyReserve(r0, reserve);
    if (!r.ok) {
      if (r.integrity || r.code === "internal") {
        functions.logger.error(`Lote ${lotId} rechazó una puja por integridad: ${r.message}`);
      }
      throw new functions.https.HttpsError(r.code, r.message, { minimum: r.minimum || null });
    }

    const now = Timestamp.fromMillis(nowMs);

    // 1) La oferta (privada: incluye el máximo secreto).
    const bidRef = lotRef.collection("bids").doc();
    tx.set(bidRef, {
      user_id: uid,
      max_amount: r.maxAmount,
      current_effective_bid: r.bidderEffective,
      timestamp: now,
    });

    // 2) Actualizar la puja efectiva de la oferta del líder anterior.
    if (
      r.previousLeaderEffective !== null &&
      state &&
      state.leader_bid_id &&
      r.outcome !== "max_raised"
    ) {
      tx.set(
        lotRef.collection("bids").doc(state.leader_bid_id),
        { current_effective_bid: r.previousLeaderEffective },
        { merge: true }
      );
    }

    // 3) Estado privado del proxy.
    const leaderIsBidder = r.newLeaderUid === uid;
    const leaderName = leaderIsBidder ? bidderName : (state && state.leader_name) || "";
    tx.set(stateRef, {
      leader_uid: r.newLeaderUid,
      leader_max: r.newLeaderMax,
      leader_bid_id: leaderIsBidder ? bidRef.id : (state && state.leader_bid_id) || null,
      leader_name: leaderName,
      updated_time: now,
    });

    // 4) Historial público (sin máximos) y lote. Si el líder solo subió su
    //    máximo, no se publica nada: sería revelar información secreta.
    if (r.publicEvent) {
      const history = lotRef.collection("history");
      if (r.outcome === "outbid") {
        // El retador ofreció M y el proxy del líder respondió automáticamente.
        tx.set(history.doc(), {
          bidder_uid: uid,
          bidder_name: bidderName,
          amount: r.bidderEffective,
          auto: false,
          created_time: now,
        });
        tx.set(history.doc(), {
          bidder_uid: r.newLeaderUid,
          bidder_name: leaderName,
          amount: r.newCurrentBid,
          auto: true,
          created_time: Timestamp.fromMillis(nowMs + 1), // orden estable
        });
      } else {
        tx.set(history.doc(), {
          bidder_uid: uid,
          bidder_name: bidderName,
          amount: r.newCurrentBid,
          auto: false,
          created_time: now,
        });
      }

      tx.update(lotRef, {
        current_bid: r.newCurrentBid,
        bid_count: FieldValue.increment(r.outcome === "outbid" ? 2 : 1),
        highest_bidder_uid: r.newLeaderUid,
        highest_bidder_name: leaderName,
        last_bid_time: now,
        end_time: Timestamp.fromMillis(r.newEndTimeMs),
        ...(reserve > 0 ? { reserve_met: r.reserveMet } : {}),
      });
    }

    // 5) "Mis pujas" del postor (privado, solo él lo lee).
    tx.set(
      db.collection("users").doc(uid).collection("bidding").doc(lotId),
      {
        lot_id: lotId,
        lot_title: lot.title || "",
        lot_image: (lot.image_urls && lot.image_urls[0]) || "",
        my_max_bid: r.maxAmount,
        last_bid_time: now,
      },
      { merge: true }
    );

    // 6) Aviso al líder anterior si perdió el primer lugar. Va DENTRO de la
    //    transacción: se escribe solo si la puja se confirma, una sola vez
    //    aunque la transacción se reintente, y nunca puede "fallar después"
    //    haciendo parecer rechazada una puja ya confirmada.
    if (r.outcome === "leading" && r.previousLeaderUid && r.previousLeaderUid !== uid) {
      tx.set(notificationRef(r.previousLeaderUid), {
        type: "outbid",
        title: `Te superaron: ${lot.title || ""}`,
        body: `La puja va en ${formatMoney(r.newCurrentBid)} y superó tu máximo. ¡Todavía puedes recuperarla!`,
        lot_id: lotId,
        read: false,
        created_time: FieldValue.serverTimestamp(),
      });
    }

    return { ...r, lotTitle: lot.title || "", hasReserve: reserve > 0 };
  });

  const messages = {
    first: `¡Vas ganando! Puja actual ${formatMoney(result.newCurrentBid)}; tu máximo es ${formatMoney(result.maxAmount)}.`,
    leading: `¡Vas ganando! Puja actual ${formatMoney(result.newCurrentBid)}; tu máximo es ${formatMoney(result.maxAmount)}.`,
    outbid: `Otro postor tiene un máximo mayor o igual. La puja subió a ${formatMoney(result.newCurrentBid)}. Ofrece más para ganar.`,
    max_raised: `Tu máximo ahora es ${formatMoney(result.maxAmount)}. Sigues ganando en ${formatMoney(result.newCurrentBid)}.`,
  };

  return {
    ok: true,
    outcome: result.outcome, // first | leading | outbid | max_raised
    leading: result.newLeaderUid === uid,
    current_bid: result.newCurrentBid,
    your_max: result.maxAmount,
    extended: result.extended,
    endTime: result.newEndTimeMs,
    message:
      messages[result.outcome] +
      (result.hasReserve && !result.reserveMet && result.newLeaderUid === uid
        ? " Aún no se alcanza el precio de reserva del vendedor."
        : ""),
    reserve_met: result.hasReserve ? result.reserveMet : null,
    // Compatibilidad con la app actual:
    amount: result.newCurrentBid,
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

    const reserveSnap = await tx.get(lotRef.collection("private").doc("reserve"));
    const reserve = reserveSnap.exists ? Number(reserveSnap.data().amount) || 0 : 0;
    const hadBids = (lot.bid_count || 0) > 0 && lot.highest_bidder_uid;
    if (hadBids && reserve > 0 && Number(lot.current_bid) < reserve) {
      // Reserva no alcanzada: no hay venta, nadie paga, sin comisión.
      tx.update(lotRef, {
        status: "ended_unsold_reserve",
        closed_time: FieldValue.serverTimestamp(),
        winner_uid: null,
        winner_name: null,
        final_price: null,
        payment_status: "none",
        reserve_met: false,
      });
      return { lot, hasWinner: false, reserveNotMet: true };
    }
    const hasWinner = hadBids;
    tx.update(lotRef, {
      status: "ended",
      closed_time: FieldValue.serverTimestamp(),
      winner_uid: hasWinner ? lot.highest_bidder_uid : null,
      winner_name: hasWinner ? lot.highest_bidder_name || "" : null,
      final_price: hasWinner ? lot.current_bid : null,
      // Sin pujas no hay nada que cobrar. Con ganador queda 'processing'
      // hasta que startWinnerPayment lo pase a pending / paid / payment_error.
      payment_status: hasWinner ? "processing" : "none",
    });
    return { lot, hasWinner };
  });
  if (!outcome) return false;

  const { lot, hasWinner, reserveNotMet } = outcome;

  if (reserveNotMet) {
    const batch = db.batch();
    batch.set(notificationRef(lot.seller_uid), {
      type: "unsold_reserve",
      title: `No se alcanzó tu reserva: ${lot.title}`,
      body: `La puja más alta fue ${formatMoney(lot.current_bid)}, debajo de tu precio de reserva. No hay venta ni comisión. Puedes republicar con otra reserva.`,
      lot_id: lotRef.id,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
    batch.set(notificationRef(lot.highest_bidder_uid), {
      type: "reserve_not_met",
      title: `Reserva no alcanzada: ${lot.title}`,
      body: "Ibas ganando, pero no se llegó al precio mínimo del vendedor. No tienes que pagar nada y tu depósito sigue disponible.",
      lot_id: lotRef.id,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return true;
  }

  if (hasWinner) {
    // Generar el cobro del ganador (precio final − depósito).
    let pay;
    try {
      pay = await startWinnerPayment(lotRef, lot, lot.highest_bidder_uid);
    } catch (err) {
      functions.logger.error(`No se pudo generar el cobro de ${lotRef.id}`, err);
      await lotRef.update({ payment_status: "payment_error" });
      pay = { url: null, amount: 0, alreadySettled: false, depositApplied: 0, error: true };
    }

    const depositApplied = pay.depositApplied || 0;
    let winnerBody;
    if (pay.alreadySettled) {
      winnerBody = `Ganaste con ${formatMoney(lot.current_bid)} y tu depósito lo cubre. En tus avisos está el contacto del vendedor.`;
    } else if (pay.error) {
      winnerBody = `Ganaste con ${formatMoney(lot.current_bid)}. Estamos generando tu enlace de pago; te avisaremos en cuanto esté listo.`;
    } else {
      winnerBody = `Ganaste con ${formatMoney(lot.current_bid)}. Tienes ${WINNER_PAYMENT_WINDOW_HOURS} horas para pagar ${formatMoney(
        pay.amount
      )}${depositApplied ? ` (tu depósito de ${formatMoney(depositApplied)} ya está aplicado)` : ""}. Al pagar te compartimos el contacto del vendedor.`;
    }

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
      body: `Se vendió en ${formatMoney(lot.current_bid)}. Cuando el comprador pague te enviaremos su contacto para la entrega.`,
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
    const [userSnap, profSnap] = await Promise.all([
      db.collection("users").doc(lot.seller_uid).get(),
      db.collection("public_profiles").doc(lot.seller_uid).get(),
    ]);
    const fullName = userSnap.exists ? userSnap.data().full_name : "";
    const prof = profSnap.exists ? profSnap.data() : {};
    // Copia de la reputación al publicar, para mostrarla en las tarjetas
    // sin una lectura extra por lote (puede quedar unos días atrás).
    await snap.ref.update({
      seller_name: publicName(fullName),
      seller_rating_avg: Number(prof.rating_avg) || 0,
      seller_rating_count: Number(prof.rating_count) || 0,
      seller_sales_count: Number(prof.sales_count) || 0,
      seller_badges: Array.isArray(prof.badges) ? prof.badges : [],
    });
  });
