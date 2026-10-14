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
const ANTI_SNIPE_WINDOW_MS = 30 * 1000;
const ANTI_SNIPE_EXTENSION_MS = 30 * 1000;

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
  // ---------------- Validaciones generales ----------------
  if (!lot) return { ok: false, code: "not-found", message: "El lote no existe." };
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
  const hasBids = (lot.bid_count || 0) > 0 && state && state.leader_uid;

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

// Nombre público para el historial (protege privacidad):
// "Juan Pérez López" -> "Juan P."
function publicName(fullName) {
  const parts = String(fullName || "").trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "Postor";
  if (parts.length === 1) return parts[0];
  return `${parts[0]} ${parts[1].charAt(0).toUpperCase()}.`;
}

module.exports = {
  resolveProxyBid,
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
