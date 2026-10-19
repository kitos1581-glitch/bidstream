/**
 * Política de comisión por venta (modelo híbrido).
 *
 * Orden de decisión, con la FECHA DE CIERRE del lote (no la del pago):
 *  1. Tienda con membresía activa (users.seller_plan == "store" y
 *     store_plan_until posterior al cierre) → 0 % ("store").
 *  2. Campaña de 0 % activa (COMMISSION_PROMO) en la fecha de cierre → 0 % ("promo").
 *  3. Periodo de lanzamiento (LAUNCH_FREE_UNTIL): 0 % para TODOS los vendedores
 *     mientras el lote cierre antes de esa fecha, hasta
 *     LAUNCH_FREE_MAX_MONTHLY_SALES ventas en el mes (por defecto 30). De la
 *     venta siguiente en adelante, en ese mes, comisión normal → "launch".
 *     El mes se cuenta con la fecha de cierre en hora del centro de México.
 *  4. Comisión normal por tramos (COMMISSION_TIERS / COMMISSION_PCT) → "standard".
 *
 * COMMISSION_PROMO="2026-11-13T00:00:00-06:00/2026-11-17T23:59:59-06:00"
 * (inicio/fin ISO con zona horaria). Configuración inválida = error explícito
 * (CommissionConfigError): la liquidación queda "needs_review", nunca se usa
 * otro porcentaje en silencio.
 *
 * Ojo: con 0 % la plataforma absorbe la tarifa del procesador de pagos.
 */
class PromoConfigError extends Error {}

function readPromo(env = process.env) {
  const raw = String(env.COMMISSION_PROMO || "").trim();
  if (!raw) return { promo: null };
  const parts = raw.split("/");
  if (parts.length !== 2) return { error: `COMMISSION_PROMO inválido: "${raw}" (formato inicio/fin ISO)` };
  if (!ISO_TZ.test(parts[0]) || !ISO_TZ.test(parts[1])) {
    return { error: `COMMISSION_PROMO debe usar fechas ISO con zona horaria: "${raw}"` };
  }
  const start = Date.parse(parts[0]);
  const end = Date.parse(parts[1]);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
    return { error: `COMMISSION_PROMO con fechas inválidas: "${raw}"` };
  }
  if (end - start > 62 * 86400_000) return { error: "COMMISSION_PROMO no puede durar más de 62 días." };
  return { promo: { start, end } };
}

const ISO_TZ = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(Z|[+-]\d{2}:\d{2})$/;

/**
 * LAUNCH_FREE_UNTIL="2027-03-31T23:59:59-06:00" (fin, ISO con zona horaria).
 * LAUNCH_FREE_MAX_MONTHLY_SALES=30 (entero 1–10000; por defecto 30).
 * Vacío = sin periodo de lanzamiento.
 */
function readLaunch(env = process.env) {
  const raw = String(env.LAUNCH_FREE_UNTIL || "").trim();
  if (!raw) return { launch: null };
  if (!ISO_TZ.test(raw)) return { error: `LAUNCH_FREE_UNTIL debe ser una fecha ISO con zona horaria: "${raw}"` };
  const end = Date.parse(raw);
  if (!Number.isFinite(end)) return { error: `LAUNCH_FREE_UNTIL inválida: "${raw}"` };
  const rawMax = env.LAUNCH_FREE_MAX_MONTHLY_SALES;
  let max = 30;
  if (rawMax !== undefined && String(rawMax).trim() !== "") {
    const n = Number(String(rawMax).trim());
    if (!Number.isInteger(n) || n < 1 || n > 10000) {
      return { error: `LAUNCH_FREE_MAX_MONTHLY_SALES inválido: "${rawMax}" (entero 1–10000)` };
    }
    max = n;
  }
  return { launch: { end, max } };
}

/**
 * Mes "AAAA-MM" de una fecha en hora del centro de México (UTC−6 todo el
 * año desde 2022; la región no usa horario de verano).
 */
function monthKey(ms) {
  return new Date(ms - 6 * 3600_000).toISOString().slice(0, 7);
}

function millis(t) {
  if (!t) return 0;
  if (typeof t.toMillis === "function") return t.toMillis();
  if (t instanceof Date) return t.getTime();
  return Number(t) || 0;
}

/** ¿El vendedor tiene membresía de tienda vigente en ese momento? */
function storeActive(seller, atMs) {
  return Boolean(seller && seller.seller_plan === "store" && millis(seller.store_plan_until) > atMs);
}

/**
 * @param {{finalPrice: number, seller: object, closedMs: number,
 *          computeStandard: (price:number)=>number, promoConfig?: object}} p
 * `monthSaleNumber`: qué número de venta del mes es esta para el vendedor (1 = la primera).
 * @returns {{commission: number, policy: "store"|"promo"|"launch"|"standard"}}
 * @throws Error de configuración (la llamada lo convierte en needs_review)
 */
function saleCommission({ finalPrice, seller, closedMs, computeStandard, promoConfig, launchConfig, monthSaleNumber = 1 }) {
  const at = closedMs || Date.now();
  if (storeActive(seller, at)) return { commission: 0, policy: "store" };
  const cfg = promoConfig || readPromo();
  if (cfg.error) throw new PromoConfigError(cfg.error);
  if (cfg.promo && at >= cfg.promo.start && at <= cfg.promo.end) return { commission: 0, policy: "promo" };
  const lc = launchConfig || readLaunch();
  if (lc.error) throw new PromoConfigError(lc.error);
  if (lc.launch && at <= lc.launch.end) {
    const n = Number(monthSaleNumber) || 1;
    if (n <= lc.launch.max) return { commission: 0, policy: "launch", launchMax: lc.launch.max };
    return { commission: computeStandard(finalPrice), policy: "standard", launchLimitReached: true, launchMax: lc.launch.max };
  }
  return { commission: computeStandard(finalPrice), policy: "standard" };
}

/**
 * ¿Quién absorbe el costo del procesador de pagos cuando la comisión es 0 %
 * (Tienda Oficial o campaña)? ZERO_COMMISSION_FEE_PAYER:
 *   "seller"   (por defecto) → se descuenta de la liquidación del vendedor
 *   "platform" → lo absorbe Subástalo Aquí
 * Nunca se le cobra al comprador como recargo (Profeco: precio total final,
 * sin comisión extra por pagar con tarjeta).
 */
function readFeePayer(env = process.env) {
  const raw = env.ZERO_COMMISSION_FEE_PAYER;
  if (raw === undefined || raw === "") return { payer: "seller" };
  const v = String(raw).trim().toLowerCase();
  if (v !== "seller" && v !== "platform") {
    return { error: `ZERO_COMMISSION_FEE_PAYER inválido: "${raw}" (seller | platform)` };
  }
  return { payer: v };
}

/** Costo real que cobró Mercado Pago por un pago (null si no viene). */
function mpProcessingFee(payment) {
  if (!payment) return null;
  const amount = Number(payment.transaction_amount);
  const net = payment.transaction_details && Number(payment.transaction_details.net_received_amount);
  if (Number.isFinite(amount) && Number.isFinite(net) && net > 0 && net <= amount) {
    return Math.round((amount - net) * 100) / 100;
  }
  if (Array.isArray(payment.fee_details) && payment.fee_details.length) {
    const sum = payment.fee_details
      .filter((f) => !f.fee_payer || f.fee_payer === "collector")
      .reduce((acc, f) => acc + (Number(f.amount) || 0), 0);
    return Math.round(sum * 100) / 100;
  }
  return null;
}

module.exports = { readPromo, readLaunch, monthKey, saleCommission, storeActive, PromoConfigError, readFeePayer, mpProcessingFee };
