/**
 * Política de comisión por venta (modelo híbrido).
 *
 * Orden de decisión, con la FECHA DE CIERRE del lote (no la del pago):
 *  1. Tienda con membresía activa (users.seller_plan == "store" y
 *     store_plan_until posterior al cierre) → 0 % ("store").
 *  2. Campaña de 0 % activa (COMMISSION_PROMO) en la fecha de cierre → 0 % ("promo").
 *  3. Comisión normal por tramos (COMMISSION_TIERS / COMMISSION_PCT) → "standard".
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
  const isoTz = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?(Z|[+-]\d{2}:\d{2})$/;
  if (!isoTz.test(parts[0]) || !isoTz.test(parts[1])) {
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
 * @returns {{commission: number, policy: "store"|"promo"|"standard"}}
 * @throws Error de configuración (la llamada lo convierte en needs_review)
 */
function saleCommission({ finalPrice, seller, closedMs, computeStandard, promoConfig }) {
  const at = closedMs || Date.now();
  if (storeActive(seller, at)) return { commission: 0, policy: "store" };
  const cfg = promoConfig || readPromo();
  if (cfg.error) throw new PromoConfigError(cfg.error);
  if (cfg.promo && at >= cfg.promo.start && at <= cfg.promo.end) return { commission: 0, policy: "promo" };
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

module.exports = { readPromo, saleCommission, storeActive, PromoConfigError, readFeePayer, mpProcessingFee };
