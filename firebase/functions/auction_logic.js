/**
 * Lógica pura de subastas (sin Firebase) para poder probarla.
 */

// Si alguien puja en los últimos 2 minutos, la subasta se extiende
// 2 minutos más (evita el "francotirador" de último segundo).
const ANTI_SNIPE_WINDOW_MS = 2 * 60 * 1000;
const ANTI_SNIPE_EXTENSION_MS = 2 * 60 * 1000;

// Tope de seguridad para evitar errores de dedo (ej. un cero de más).
const MAX_BID_MULTIPLIER = 20;

function roundMoney(n) {
  return Math.round(n * 100) / 100;
}

/**
 * Mínimo que debe ofrecer la siguiente puja.
 * Si nadie ha pujado, basta con el precio inicial.
 */
function minimumNextBid(lot) {
  const bidCount = lot.bid_count || 0;
  const current = Number(lot.current_bid || lot.starting_price || 0);
  const increment = Number(lot.minimum_increment || 0);
  return bidCount === 0 ? roundMoney(current) : roundMoney(current + increment);
}

/**
 * Valida una puja. Devuelve { ok: true, newEndTimeMs } o { ok: false, code, message }.
 * @param {object} lot  Datos del lote (fechas en milisegundos).
 * @param {number} amount Monto ofrecido.
 * @param {string} uid  Usuario que puja.
 * @param {number} nowMs Hora actual en milisegundos.
 */
function validateBid(lot, amount, uid, nowMs) {
  if (!lot) {
    return { ok: false, code: "not-found", message: "El lote no existe." };
  }
  if (typeof amount !== "number" || !isFinite(amount) || amount <= 0) {
    return { ok: false, code: "invalid-argument", message: "Monto inválido." };
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
  if (lot.highest_bidder_uid === uid) {
    return { ok: false, code: "already-exists", message: "Ya vas ganando esta subasta." };
  }

  const min = minimumNextBid(lot);
  const rounded = roundMoney(amount);
  if (rounded < min) {
    return {
      ok: false,
      code: "failed-precondition",
      message: `La puja mínima es $${min.toLocaleString("es-MX")}.`,
      minimum: min,
    };
  }
  const ceiling = Math.max(min * MAX_BID_MULTIPLIER, min + 1000);
  if (rounded > ceiling) {
    return {
      ok: false,
      code: "invalid-argument",
      message: "El monto parece un error (demasiado alto). Revísalo.",
    };
  }

  let newEndTimeMs = lot.end_time_ms;
  if (lot.end_time_ms - nowMs <= ANTI_SNIPE_WINDOW_MS) {
    newEndTimeMs = nowMs + ANTI_SNIPE_EXTENSION_MS;
  }

  return { ok: true, amount: rounded, newEndTimeMs, extended: newEndTimeMs !== lot.end_time_ms };
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
  publicName,
  minimumNextBid,
  validateBid,
  roundMoney,
  ANTI_SNIPE_WINDOW_MS,
  ANTI_SNIPE_EXTENSION_MS,
};
