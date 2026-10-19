/**
 * Lógica pura de subastas (sin Firebase) para poder probarla.
 *
 * PUJA PROXY (puja automática máxima)
 * -----------------------------------
 * Cada postor ofrece un MÁXIMO secreto. El precio visible (`current_bid`)
 * solo sube lo necesario: el sistema puja por el líder hasta su máximo,
 * superando al retador por `minimum_increment`.
 *
 * Todo el dinero se maneja en CENTAVOS (enteros) para evitar errores de
 * punto flotante (0.1 + 0.2 !== 0.3).
 */

// Anti-sniping: si quedan 30 s o menos, el cierre pasa a "ahora + 30 s".
// Conexiones de celular lentas en la región: 2 minutos para responder.
const ANTI_SNIPE_WINDOW_MS = 2 * 60 * 1000;
const ANTI_SNIPE_EXTENSION_MS = 2 * 60 * 1000;

// Tope absoluto contra errores de dedo (en pesos). Con puja proxy un máximo
// muy por encima del precio actual es legítimo, por eso ya no se usa un
// múltiplo del precio, solo un límite absoluto.
const MAX_BID_PESOS = 50_000_000;

const toCents = (n) => Math.round(Number(n) * 100);
const fromCents = (c) => c / 100;

function roundMoney(n) {
  return fromCents(toCents(n));
}

function fmt(cents) {
  return `$${fromCents(cents).toLocaleString("es-MX", { maximumFractionDigits: 2 })}`;
}

/**
 * Mínimo que debe ofrecer la siguiente puja de un RETADOR (no del líder).
 * Sin pujas: el precio inicial. Con pujas: puja actual + incremento.
 */
function minimumNextBid(lot) {
  const current = toCents(lot.current_bid || lot.starting_price || 0);
  const inc = toCents(lot.minimum_increment || 0);
  return fromCents((lot.bid_count || 0) === 0 ? current : current + inc);
}

/**
 * Anti-sniping de 30 segundos.
 * Si 0 < (end − now) ≤ 30 s → nuevo cierre = now + 30 s.
 */
function applyAntiSniping(endTimeMs, nowMs) {
  const remaining = endTimeMs - nowMs;
  if (remaining > 0 && remaining <= ANTI_SNIPE_WINDOW_MS) {
    return { newEndTimeMs: nowMs + ANTI_SNIPE_EXTENSION_MS, extended: true };
  }
  return { newEndTimeMs: endTimeMs, extended: false };
}

const VALID_STATUSES = ["active", "ended", "cancelled"];
const isMoney = (n) => typeof n === "number" && Number.isFinite(n);

/**
 * Integridad del lote ANTES de aceptar una oferta. No confiamos en lo que
 * haya en Firestore: un dato corrupto o manipulado (p. ej. un incremento
 * negativo) nunca debe mover el precio hacia abajo.
 * Devuelve null si todo está bien, o un mensaje de error.
 */
function lotIntegrityError(lot) {
  if (!lot || typeof lot !== "object") return "El lote no existe.";
  if (!VALID_STATUSES.includes(lot.status)) return "Estado del lote inválido.";
  if (!isMoney(lot.starting_price) || lot.starting_price <= 0 || lot.starting_price > MAX_BID_PESOS) {
    return "Precio inicial inválido.";
  }
  if (!isMoney(lot.current_bid) || lot.current_bid < lot.starting_price || lot.current_bid > MAX_BID_PESOS) {
    return "Puja actual inválida.";
  }
  if (!isMoney(lot.minimum_increment) || lot.minimum_increment <= 0 || lot.minimum_increment > MAX_BID_PESOS) {
    return "Incremento mínimo inválido.";
  }
  const count = lot.bid_count === undefined ? 0 : lot.bid_count;
  if (!Number.isInteger(count) || count < 0) return "Conteo de pujas inválido.";
  if (count === 0 && toCents(lot.current_bid) !== toCents(lot.starting_price)) {
    return "Puja actual inconsistente con un lote sin pujas.";
  }
  if (count > 0 && !lot.highest_bidder_uid) return "Lote con pujas pero sin líder.";
  if (!Number.isFinite(lot.end_time_ms)) return "Fecha de cierre inválida.";
  if (lot.start_time_ms !== null && lot.start_time_ms !== undefined) {
    if (!Number.isFinite(lot.start_time_ms) || lot.start_time_ms >= lot.end_time_ms) {
      return "Fechas del lote inválidas.";
    }
  }
  return null;
}

/** Integridad del estado privado del proxy frente al lote. */
function stateIntegrityError(lot, state) {
  if ((lot.bid_count || 0) === 0) return null; // sin pujas no hay estado que validar
  if (!state || !state.leader_uid) return "Estado de pujas incompleto.";
  if (state.leader_uid !== lot.highest_bidder_uid) return "Estado de pujas inconsistente.";
  if (!isMoney(state.leader_max) || toCents(state.leader_max) < toCents(lot.current_bid)) {
    return "Máximo del líder inconsistente.";
  }
  return null;
}

/**
 * Resuelve una nueva oferta proxy.
 *
 * @param {object} lot   Lote: status, seller_uid, starting_price, current_bid,
 *                       minimum_increment, bid_count, start_time_ms, end_time_ms,
 *                       highest_bidder_uid.
 * @param {object|null} state  Estado PRIVADO del proxy:
 *                       { leader_uid, leader_max, leader_bid_id, leader_name }.
 * @param {string} uid   Quién oferta.
 * @param {number} maxAmount  Máximo secreto ofrecido (pesos).
 * @param {number} nowMs Hora actual (ms).
 *
 * @returns Error:  { ok:false, code, message, minimum? }
 *          Éxito:  {
 *            ok:true,
 *            outcome: 'first' | 'leading' | 'outbid' | 'max_raised',
 *            maxAmount, newCurrentBid, newLeaderUid, newLeaderMax,
 *            bidderEffective,          // current_effective_bid de la nueva oferta
 *            previousLeaderUid,        // líder antes de esta oferta (o null)
 *            previousLeaderEffective,  // nuevo current_effective_bid del líder anterior (o null)
 *            publicEvent,              // ¿cambió algo visible? (precio/líder/conteo)
 *            newEndTimeMs, extended
 *          }
 */
function resolveProxyBid(lot, state, uid, maxAmount, nowMs) {
  const r = resolveProxyBidUnchecked(lot, state, uid, maxAmount, nowMs);
  // Defensa en profundidad: el precio visible JAMÁS baja ni rebasa el máximo
  // del líder, y el cierre jamás se adelanta.
  if (r.ok) {
    const cur = toCents(lot.current_bid);
    const next = toCents(r.newCurrentBid);
    if (next < cur || next > toCents(r.newLeaderMax) || r.newEndTimeMs < lot.end_time_ms) {
      return {
        ok: false,
        code: "internal",
        message: "La oferta produjo un resultado inconsistente y fue rechazada.",
      };
    }
  }
  return r;
}

/**
 * Precio de reserva (secreto). Se aplica DESPUÉS de resolver la puja proxy:
 *  - Si el máximo del líder alcanza la reserva y el precio visible quedó
 *    debajo, el precio sube directo a la reserva (como eBay).
 *  - Nunca rebasa el máximo del líder ni baja el precio.
 * Devuelve el resultado con reserveMet (true/false; true si no hay reserva).
 */
function applyReserve(r, reserve) {
  if (!r || !r.ok) return r;
  const res = Number(reserve);
  if (!(res > 0)) return { ...r, reserveMet: true, reserveJump: false };
  const resC = toCents(res);
  const met = toCents(r.newLeaderMax) >= resC;
  if (!met || toCents(r.newCurrentBid) >= resC) return { ...r, reserveMet: met, reserveJump: false };
  const price = fromCents(resC);
  const out = { ...r, newCurrentBid: price, reserveMet: true, reserveJump: true, publicEvent: true };
  if (r.outcome === "outbid") {
    // El líder sigue siendo el anterior: su puja efectiva sube a la reserva.
    out.previousLeaderEffective = price;
  } else {
    // first / leading / max_raised: el líder es quien acaba de ofertar.
    out.bidderEffective = price;
  }
  return out;
}

function resolveProxyBidUnchecked(lot, state, uid, maxAmount, nowMs) {
  // ---------------- Validaciones generales ----------------
  if (!lot) return { ok: false, code: "not-found", message: "El lote no existe." };
  const lotErr = lotIntegrityError(lot);
  if (lotErr) {
    return {
      ok: false,
      code: "failed-precondition",
      message: `Este lote tiene datos inválidos (${lotErr}) y no acepta pujas por ahora.`,
      integrity: true,
    };
  }
  if (typeof maxAmount !== "number" || !isFinite(maxAmount) || maxAmount <= 0) {
    return { ok: false, code: "invalid-argument", message: "Monto inválido." };
  }
  if (maxAmount > MAX_BID_PESOS) {
    return {
      ok: false,
      code: "invalid-argument",
      message: "El monto parece un error (demasiado alto). Revísalo.",
    };
  }
  if (lot.status !== "active") {
    return { ok: false, code: "failed-precondition", message: "Esta subasta ya terminó." };
  }
  if (lot.seller_uid === uid) {
    return { ok: false, code: "permission-denied", message: "No puedes pujar en tu propio lote." };
  }
  if (lot.start_time_ms && nowMs < lot.start_time_ms) {
    return { ok: false, code: "failed-precondition", message: "La subasta aún no comienza." };
  }
  if (!lot.end_time_ms || nowMs >= lot.end_time_ms) {
    return { ok: false, code: "failed-precondition", message: "Esta subasta ya terminó." };
  }

  const M = toCents(maxAmount);
  const inc = toCents(lot.minimum_increment || 0);
  const cur = toCents(lot.current_bid || lot.starting_price || 0);
  const stateErr = stateIntegrityError(lot, state);
  if (stateErr) {
    return {
      ok: false,
      code: "failed-precondition",
      message: `Este lote tiene datos inválidos (${stateErr}) y no acepta pujas por ahora.`,
      integrity: true,
    };
  }
  const hasBids = (lot.bid_count || 0) > 0;

  // ---------------- Primera oferta del lote ----------------
  if (!hasBids) {
    const min = toCents(lot.starting_price || lot.current_bid || 0);
    if (M < min) {
      return {
        ok: false,
        code: "failed-precondition",
        message: `La puja mínima es ${fmt(min)}.`,
        minimum: fromCents(min),
      };
    }
    // El precio visible arranca en el precio inicial, no en el máximo.
    return {
      ok: true,
      outcome: "first",
      maxAmount: fromCents(M),
      newCurrentBid: fromCents(min),
      newLeaderUid: uid,
      newLeaderMax: fromCents(M),
      bidderEffective: fromCents(min),
      previousLeaderUid: null,
      previousLeaderEffective: null,
      publicEvent: true,
      ...applyAntiSniping(lot.end_time_ms, nowMs),
    };
  }

  const L = toCents(state.leader_max);

  // ---------------- El líder sube su propio máximo ----------------
  // No cambia nada visible: ni precio ni cierre (extender delataría que
  // el líder subió su máximo secreto, y le permitiría alargar la subasta).
  if (state.leader_uid === uid) {
    if (M <= L) {
      return {
        ok: false,
        code: "already-exists",
        message: `Ya vas ganando. Tu máximo actual es ${fmt(L)}; para subirlo ofrece más.`,
        minimum: fromCents(L + Math.max(inc, 1)),
      };
    }
    return {
      ok: true,
      outcome: "max_raised",
      maxAmount: fromCents(M),
      newCurrentBid: fromCents(cur),
      newLeaderUid: uid,
      newLeaderMax: fromCents(M),
      bidderEffective: fromCents(cur),
      previousLeaderUid: uid,
      previousLeaderEffective: null,
      publicEvent: false,
      newEndTimeMs: lot.end_time_ms,
      extended: false,
    };
  }

  // ---------------- Un retador ----------------
  // Debe ofrecer al menos puja actual + incremento.
  const min = cur + inc;
  if (M < min) {
    return {
      ok: false,
      code: "failed-precondition",
      message: `La puja mínima es ${fmt(min)}.`,
      minimum: fromCents(min),
    };
  }

  const timing = applyAntiSniping(lot.end_time_ms, nowMs);

  if (M > L) {
    // El retador supera el máximo del líder: pasa a ganar, pagando solo
    // lo necesario (máximo del líder + incremento, sin rebasar su propio máximo).
    const newCur = Math.min(M, L + inc);
    return {
      ok: true,
      outcome: "leading",
      maxAmount: fromCents(M),
      newCurrentBid: fromCents(newCur),
      newLeaderUid: uid,
      newLeaderMax: fromCents(M),
      bidderEffective: fromCents(newCur),
      previousLeaderUid: state.leader_uid,
      previousLeaderEffective: fromCents(L), // el proxy del líder llegó a su tope
      publicEvent: true,
      ...timing,
    };
  }

  // M <= L: el proxy responde por el líder. Le gana al retador por un
  // incremento, sin rebasar su máximo. En empate gana quien pujó primero.
  const newCur = Math.min(L, M + inc);
  return {
    ok: true,
    outcome: "outbid",
    maxAmount: fromCents(M),
    newCurrentBid: fromCents(newCur),
    newLeaderUid: state.leader_uid,
    newLeaderMax: fromCents(L),
    bidderEffective: fromCents(M),
    previousLeaderUid: state.leader_uid,
    previousLeaderEffective: fromCents(newCur),
    publicEvent: true,
    ...timing,
  };
}

/**
 * Lotes antiguos (antes de la puja proxy) no tienen estado privado.
 * Se reconstruye: el líder es highest_bidder_uid y su máximo = puja actual.
 */
function legacyState(lot) {
  if ((lot.bid_count || 0) > 0 && lot.highest_bidder_uid) {
    return {
      leader_uid: lot.highest_bidder_uid,
      leader_max: Number(lot.current_bid) || 0,
      leader_bid_id: null,
      leader_name: lot.highest_bidder_name || "",
    };
  }
  return null;
}

/**
 * ¿Puede este usuario pujar este monto? Se usa DOS veces: antes de la
 * transacción (respuesta rápida) y DENTRO de ella con el documento fresco
 * (la decisión que cuenta), por si el perfil cambió en medio.
 * Devuelve null si puede, o { code, message, details }.
 */
function userBidEligibilityError(user, maxAmount, verifiedThreshold, verbo = "pujar") {
  if (!user) {
    return { code: "failed-precondition", message: `Completa tu perfil antes de ${verbo}.` };
  }
  if (user.banned === true) {
    return { code: "permission-denied", message: "Tu cuenta está suspendida." };
  }
  if (!String(user.full_name || "").trim() || !String(user.phone || "").trim()) {
    return {
      code: "failed-precondition",
      message: `Completa tu perfil (nombre y teléfono) antes de ${verbo}.`,
    };
  }
  if (user.accepted_terms !== true) {
    return { code: "failed-precondition", message: `Acepta los términos antes de ${verbo}.` };
  }
  if (Number(maxAmount) > verifiedThreshold && user.verified !== true) {
    return {
      code: "failed-precondition",
      message: `Para ${verbo === "pujar" ? "pujas" : "compras"} mayores a $${verifiedThreshold.toLocaleString("es-MX")} necesitas verificar tu identidad (INE).`,
      details: { code: "IDENTITY_REQUIRED" },
    };
  }
  if (!user.deposit || user.deposit.status !== "held") {
    return {
      code: "failed-precondition",
      message: `Debes dejar un depósito de garantía antes de ${verbo}. Es reembolsable.`,
      details: { code: "DEPOSIT_REQUIRED" },
    };
  }
  return null;
}

// Nombre público para el historial (protege privacidad):
// "Juan Pérez López" -> "Juan P."
function publicName(fullName) {
  const parts = String(fullName || "").trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "Postor";
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[1].charAt(0).toUpperCase()}.`;
}


// ---------------------------------------------------------------------
// Comprar ahora / precio fijo (R-10).
//
//  sale_type "fixed"  → venta a precio fijo (sin pujas): buy_now_price es
//                       el precio; el primero que lo compra se lo lleva.
//  sale_type "auction" (o ausente) con buy_now_price → subasta POR TIEMPO
//                       que se puede comprar al instante MIENTRAS NO HAYA
//                       PUJAS (al primer puja la opción desaparece, como eBay).
//
// Devuelve { price } si se puede comprar, o { code, message } si no.
// ---------------------------------------------------------------------
function saleType(lot) {
  return lot && lot.sale_type === "fixed" ? "fixed" : "auction";
}

function buyNowError(lot, uid, nowMs) {
  if (!lot) return { code: "not-found", message: "El artículo ya no existe.", reason: "NOT_FOUND" };
  if (lot.seller_uid === uid) {
    return { code: "failed-precondition", message: "Es tu publicación: no puedes comprarla.", reason: "OWN_LOT" };
  }
  if (lot.status !== "active") {
    return { code: "failed-precondition", message: "Este artículo ya se vendió o terminó.", reason: "NOT_ACTIVE" };
  }
  const start = lot.start_time_ms;
  const end = lot.end_time_ms;
  if (start && nowMs < start) {
    return { code: "failed-precondition", message: "Esta publicación todavía no empieza.", reason: "NOT_STARTED" };
  }
  if (end && nowMs >= end) {
    return { code: "failed-precondition", message: "Esta publicación ya terminó.", reason: "ENDED" };
  }
  const price = roundMoney(Number(lot.buy_now_price));
  if (!(price > 0) || price > MAX_BID_PESOS) {
    return { code: "failed-precondition", message: "Este artículo no tiene opción de Comprar ahora.", reason: "NO_BUY_NOW" };
  }
  if (saleType(lot) === "auction") {
    if (lot.format === "live") {
      return { code: "failed-precondition", message: "Las subastas en vivo no tienen Comprar ahora.", reason: "LIVE" };
    }
    if ((lot.bid_count || 0) > 0) {
      return {
        code: "failed-precondition",
        message: "Ya hay pujas: Comprar ahora ya no está disponible. Puedes pujar.",
        reason: "HAS_BIDS",
      };
    }
  }
  return { price };
}

module.exports = {
  saleType,
  buyNowError,
  applyReserve,
  userBidEligibilityError,
  resolveProxyBid,
  lotIntegrityError,
  stateIntegrityError,
  applyAntiSniping,
  legacyState,
  minimumNextBid,
  publicName,
  roundMoney,
  toCents,
  fromCents,
  ANTI_SNIPE_WINDOW_MS,
  ANTI_SNIPE_EXTENSION_MS,
  MAX_BID_PESOS,
};
