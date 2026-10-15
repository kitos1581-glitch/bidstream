/**
 * Segunda oportunidad (Second Chance Offer).
 *
 * Cuando el ganador no paga (forfeitWin), en lugar de solo cerrar:
 *  1. Se busca al subcampeón: el MÁXIMO secreto más alto de otro postor
 *     (empate: quien ofertó primero). Nunca el vendedor ni el moroso.
 *  2. Se le ofrece el lote por SU máximo, con 24 h para aceptar
 *     (lot.second_chance). Rechazar o dejar vencer NO lo castiga.
 *  3. Si acepta, pasa a ser el ganador y corre el mismo cobro de siempre
 *     (startWinnerPayment, 24 h). Si después no paga, se castiga normal.
 *  4. Solo hay UNA segunda oportunidad por lote. Si no se concreta, el lote
 *     cierra como hoy (el vendedor puede republicar).
 * El vendedor conserva el depósito del ganador moroso en cualquier caso.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { assertAppCheck } = require("./appcheck");
const { publicName } = require("./auction_logic");
const pay = require("./payments");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;
const REGION = "us-central1";

const OFFER_WINDOW_MS = 24 * 3600 * 1000;

const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: "UNAUTHENTICATED",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
  LOT_NOT_FOUND: "LOT_NOT_FOUND",
  NO_OFFER: "NO_OFFER",
  NOT_YOUR_OFFER: "NOT_YOUR_OFFER",
  OFFER_EXPIRED: "OFFER_EXPIRED",
  ACCOUNT_SUSPENDED: "ACCOUNT_SUSPENDED",
});

function fail(httpsCode, code, message) {
  return new functions.https.HttpsError(httpsCode, message, { code });
}
function millis(t) {
  if (!t) return 0;
  if (typeof t.toMillis === "function") return t.toMillis();
  if (t instanceof Date) return t.getTime();
  return Number(t) || 0;
}
function note(type, title, body, lotId) {
  return { type, title, body, lot_id: lotId, read: false, created_time: FieldValue.serverTimestamp() };
}
function money(n) {
  return `$${Number(n).toLocaleString("es-MX")}`;
}

/**
 * Subcampeón a partir de las ofertas privadas (función pura).
 * @param {Array<{user_id: string, max_amount: number, timestamp: any}>} bids
 * @param {string[]} exclude uids que no participan (vendedor, moroso)
 */
function pickRunnerUp(bids, exclude) {
  const best = new Map(); // uid -> { amount, ts }
  for (const b of bids) {
    const uid = String(b.user_id || "");
    const amount = Number(b.max_amount);
    if (!uid || exclude.includes(uid) || !Number.isFinite(amount) || amount <= 0) continue;
    const ts = millis(b.timestamp);
    const cur = best.get(uid);
    // Para cada postor vale su máximo más alto (y la fecha en que lo alcanzó).
    if (!cur || amount > cur.amount) best.set(uid, { amount, ts });
  }
  let pick = null;
  for (const [uid, v] of best) {
    if (!pick || v.amount > pick.amount || (v.amount === pick.amount && v.ts < pick.ts)) {
      pick = { uid, amount: v.amount, ts: v.ts };
    }
  }
  return pick ? { uid: pick.uid, amount: pay.round2(pick.amount) } : null;
}

/**
 * Ofrece el lote al subcampeón tras un incumplimiento. Idempotente:
 * si ya hubo una segunda oportunidad, no hace nada. Devuelve la oferta o null.
 */
async function offerSecondChance(lotRef, nowMs = Date.now()) {
  const lotSnap = await lotRef.get();
  if (!lotSnap.exists) return null;
  const lot = lotSnap.data();
  if (lot.payment_status !== "forfeited" || lot.second_chance) return null;

  const bidsSnap = await lotRef.collection("bids").get();
  const runner = pickRunnerUp(
    bidsSnap.docs.map((d) => d.data()),
    [lot.seller_uid, lot.winner_uid, ...(lot.forfeited_uids || [])].filter(Boolean)
  );
  // Nunca por debajo del precio inicial ni de la reserva del vendedor.
  const resSnap = await lotRef.collection("private").doc("reserve").get();
  const reserve = resSnap.exists ? Number(resSnap.data().amount) || 0 : 0;
  const minimum = Math.max(Number(lot.starting_price) || 0, reserve);
  if (!runner || runner.amount < minimum) return null;

  const runnerRef = db.collection("users").doc(runner.uid);
  return db.runTransaction(async (tx) => {
    const [fresh, runnerSnap] = await Promise.all([tx.get(lotRef), tx.get(runnerRef)]);
    const cur = fresh.exists ? fresh.data() : null;
    if (!cur || cur.payment_status !== "forfeited" || cur.second_chance) return null;
    const user = runnerSnap.exists ? runnerSnap.data() : null;
    if (!user || user.banned === true) return null;

    const offer = {
      uid: runner.uid,
      name: publicName(user.full_name || ""),
      amount: runner.amount,
      status: "offered",
      offered_time: FieldValue.serverTimestamp(),
      expires_at: Timestamp.fromMillis(nowMs + OFFER_WINDOW_MS),
    };
    tx.update(lotRef, { second_chance: offer });
    tx.set(
      runnerRef.collection("notifications").doc(),
      note(
        "second_chance",
        `Segunda oportunidad: ${cur.title || "un lote"}`,
        `El ganador no pagó. Llévatelo por tu máximo de ${money(runner.amount)}. Tienes 24 horas para aceptar; si no te interesa, no pasa nada.`,
        lotRef.id
      )
    );
    tx.set(
      db.collection("users").doc(cur.seller_uid).collection("notifications").doc(),
      note(
        "second_chance_offered",
        `Ofrecimos tu lote al segundo lugar`,
        `${offer.name || "El segundo postor"} puede llevárselo por ${money(runner.amount)} en las próximas 24 horas. Te avisamos.`,
        lotRef.id
      )
    );
    return { uid: runner.uid, amount: runner.amount };
  });
}

async function respondImpl(data, uid, accept, nowMs = Date.now()) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const lotId = String((data && data.lotId) || "");
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Lote inválido.");
  }
  const lotRef = db.collection("lots").doc(lotId);
  const userRef = db.collection("users").doc(uid);

  const lot = await db.runTransaction(async (tx) => {
    const [snap, userSnap] = await Promise.all([tx.get(lotRef), tx.get(userRef)]);
    if (!snap.exists) throw fail("not-found", ERROR_CODES.LOT_NOT_FOUND, "Este lote ya no existe.");
    const l = snap.data();
    const offer = l.second_chance;
    if (!offer || offer.status !== "offered") {
      throw fail("failed-precondition", ERROR_CODES.NO_OFFER, "Esta oferta ya no está disponible.");
    }
    if (offer.uid !== uid) throw fail("permission-denied", ERROR_CODES.NOT_YOUR_OFFER, "Esta oferta no es para ti.");
    if (millis(offer.expires_at) <= nowMs) {
      throw fail("failed-precondition", ERROR_CODES.OFFER_EXPIRED, "La oferta ya venció.");
    }
    if (!accept) {
      tx.update(lotRef, { "second_chance.status": "declined" });
      tx.set(
        db.collection("users").doc(l.seller_uid).collection("notifications").doc(),
        note("second_chance_declined", "El segundo lugar no aceptó", `Puedes republicar "${l.title || "tu lote"}".`, lotId)
      );
      return null;
    }
    if (userSnap.exists && userSnap.data().banned === true) {
      throw fail("permission-denied", ERROR_CODES.ACCOUNT_SUSPENDED, "Tu cuenta está suspendida.");
    }
    const patch = {
      winner_uid: uid,
      winner_name: offer.name || "",
      highest_bidder_uid: uid,
      highest_bidder_name: offer.name || "",
      current_bid: offer.amount,
      final_price: offer.amount,
      forfeited_uids: [...new Set([...(l.forfeited_uids || []), l.winner_uid].filter(Boolean))],
      "second_chance.status": "accepted",
      // Se reinicia el cobro para el nuevo ganador.
      payment_status: FieldValue.delete(),
      amount_due: FieldValue.delete(),
      deposit_applied: FieldValue.delete(),
      payment_due_time: FieldValue.delete(),
      payment_options: FieldValue.delete(),
      winner_payment_url: FieldValue.delete(),
      spei_charge_id: FieldValue.delete(),
      payment_method_chosen: FieldValue.delete(),
    };
    tx.update(lotRef, patch);
    tx.set(
      db.collection("users").doc(l.seller_uid).collection("notifications").doc(),
      note(
        "second_chance_accepted",
        "¡El segundo lugar aceptó!",
        `${offer.name || "El comprador"} se lleva "${l.title || "tu lote"}" por ${money(offer.amount)}. Te avisamos cuando pague.`,
        lotId
      )
    );
    return { ...l, current_bid: offer.amount, winner_uid: uid };
  });

  if (!accept) return { ok: true, accepted: false };
  const res = await pay.startWinnerPayment(lotRef, lot, uid);
  return {
    ok: true,
    accepted: true,
    amountDue: res.amount,
    paymentUrl: res.url || null,
    paymentError: Boolean(res.error),
  };
}

/** Ofertas vencidas (lo llama expireUnpaidWins). */
async function expireSecondChances(nowMs = Date.now()) {
  const snap = await db.collection("lots").where("second_chance.status", "==", "offered").limit(100).get();
  let n = 0;
  for (const doc of snap.docs) {
    const sc = doc.data().second_chance || {};
    if (millis(sc.expires_at) > nowMs) continue;
    const done = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(doc.ref);
      const cur = fresh.data() || {};
      if (!cur.second_chance || cur.second_chance.status !== "offered") return false;
      tx.update(doc.ref, { "second_chance.status": "expired" });
      tx.set(
        db.collection("users").doc(cur.seller_uid).collection("notifications").doc(),
        note("second_chance_expired", "La segunda oportunidad venció", `Puedes republicar "${cur.title || "tu lote"}".`, doc.id)
      );
      return true;
    });
    if (done) n++;
  }
  return n;
}

exports.respondSecondChance = functions.region(REGION).https.onCall((data, context) => {
  assertAppCheck(context);
  return respondImpl(data, context.auth ? context.auth.uid : null, (data && data.accept) === true);
});

module.exports = {
  ...module.exports,
  ERROR_CODES,
  OFFER_WINDOW_MS,
  pickRunnerUp,
  offerSecondChance,
  respondImpl,
  expireSecondChances,
};
