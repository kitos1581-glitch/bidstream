/**
 * Modelo de negocio: comisión normal, Tienda Oficial (0 %), campaña Buen Fin (0 %),
 * envío regional y municipios.
 */
const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const fake = require("./helpers/fake_admin");
const mp = require("./helpers/fake_mp");
function inject(name, exportsObj) {
  const resolved = require.resolve(name);
  require.cache[resolved] = { id: resolved, filename: resolved, loaded: true, exports: exportsObj };
}
inject("firebase-admin", fake);
inject("mercadopago", mp);
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";
process.env.MP_ACCESS_TOKEN = "TEST-token";
process.env.MP_WEBHOOK_SECRET = "secreto";

const policy = require(path.join(__dirname, "..", "commission_policy.js"));
const pay = require(path.join(__dirname, "..", "payments.js"));
const adminFns = require(path.join(__dirname, "..", "admin.js"));
const delivery = require(path.join(__dirname, "..", "delivery.js"));
const spei = require(path.join(__dirname, "..", "spei.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const BUEN_FIN = "2026-11-13T00:00:00-06:00/2026-11-17T23:59:59-06:00";
const std = (p) => pay.computeCommission(p);

// ---------------- Política de comisión ----------------
test("COMMISSION_PROMO: formato estricto (ISO con zona, fin > inicio, ≤ 62 días)", () => {
  assert.deepStrictEqual(policy.readPromo({}), { promo: null });
  assert.ok(policy.readPromo({ COMMISSION_PROMO: BUEN_FIN }).promo);
  assert.ok(policy.readPromo({ COMMISSION_PROMO: "2026-11-13/2026-11-17" }).error, "sin hora ni zona → error");
  assert.ok(policy.readPromo({ COMMISSION_PROMO: "2026-11-17T00:00:00-06:00/2026-11-13T00:00:00-06:00" }).error);
  assert.ok(policy.readPromo({ COMMISSION_PROMO: "basura" }).error);
  assert.ok(policy.readPromo({ COMMISSION_PROMO: "2026-01-01T00:00:00Z/2026-12-31T00:00:00Z" }).error, "más de 62 días");
});

test("comisión: tienda vigente 0 %, campaña 0 % solo dentro de fechas (hora de CIERRE), normal fuera", () => {
  const cfg = policy.readPromo({ COMMISSION_PROMO: BUEN_FIN });
  const inPromo = Date.parse("2026-11-15T12:00:00-06:00");
  const after = Date.parse("2026-11-18T00:00:01-06:00");
  const store = { seller_plan: "store", store_plan_until: Timestamp.fromMillis(after + 86400_000) };
  assert.deepStrictEqual(policy.saleCommission({ finalPrice: 50000, seller: store, closedMs: after, computeStandard: std, promoConfig: cfg }), { commission: 0, policy: "store" });
  assert.deepStrictEqual(policy.saleCommission({ finalPrice: 50000, seller: {}, closedMs: inPromo, computeStandard: std, promoConfig: cfg }), { commission: 0, policy: "promo" });
  const normal = policy.saleCommission({ finalPrice: 50000, seller: {}, closedMs: after, computeStandard: std, promoConfig: cfg });
  assert.strictEqual(normal.policy, "standard");
  assert.ok(normal.commission > 0);
  const expired = { seller_plan: "store", store_plan_until: Timestamp.fromMillis(inPromo - 1) };
  assert.strictEqual(policy.saleCommission({ finalPrice: 50000, seller: expired, closedMs: after, computeStandard: std, promoConfig: cfg }).policy, "standard", "membresía vencida");
  assert.throws(() => policy.saleCommission({ finalPrice: 1, seller: {}, closedMs: 1, computeStandard: std, promoConfig: { error: "x" } }));
});

async function sale({ seller = {}, lotOver = {} } = {}) {
  fake.__reset();
  mp.__reset();
  put("users/vendedor", { full_name: "Vero Vendedora", verified: true, ...seller });
  put("users/ana", { full_name: "Ana Pérez", email: "a@t.mx" });
  put("lots/B1", { title: "Silla", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 10000, closed_time: Timestamp.now(), ...lotOver });
  await pay.startWinnerPayment(fake.firestore().collection("lots").doc("B1"), get("lots/B1"), "ana");
}

test("liquidación: tienda oficial cobra 0 % y el vendedor recibe el total", async () => {
  await sale({ seller: { seller_plan: "store", store_plan_until: Timestamp.fromMillis(Date.now() + 30 * 86400_000) } });
  await pay.applyApprovedPayment({ id: "P1", status: "approved", external_reference: "win:B1:ana", transaction_amount: 10000, currency_id: "MXN" });
  const p = get("payments/payout-B1");
  assert.strictEqual(p.commission, 0);
  assert.strictEqual(p.commission_policy, "store");
  assert.strictEqual(p.amount, 10000);
});

test("liquidación: COMMISSION_PROMO inválido → en revisión (nunca otro % en silencio)", async () => {
  process.env.COMMISSION_PROMO = "2026-11-13/2026-11-17";
  try {
    await sale();
    await pay.applyApprovedPayment({ id: "P2", status: "approved", external_reference: "win:B1:ana", transaction_amount: 10000, currency_id: "MXN" });
    assert.strictEqual(get("payments/payout-B1").status, "needs_review");
  } finally {
    delete process.env.COMMISSION_PROMO;
  }
});

// ---------------- Tienda Oficial (admin) ----------------
test("activar tienda: requiere identidad verificada; renovar suma meses; cancelar regresa a comisión", async () => {
  fake.__reset();
  put("users/t1", { full_name: "Ferretería López", verified: false });
  await assert.rejects(adminFns.setStorePlanImpl({ uid: "t1", months: 12, storeName: "Ferretería López" }, "jefe"), /verificada/);
  S.get("users/t1").data.verified = true;
  await assert.rejects(adminFns.setStorePlanImpl({ uid: "t1", months: 30, storeName: "X Y" }, "jefe"), /Meses/);
  const now = Date.now();
  await adminFns.setStorePlanImpl({ uid: "t1", months: 1, storeName: "Ferretería López" }, "jefe", now);
  const first = get("users/t1").store_plan_until.toMillis();
  await adminFns.setStorePlanImpl({ uid: "t1", months: 1, storeName: "Ferretería López" }, "jefe", now);
  assert.ok(get("users/t1").store_plan_until.toMillis() > first + 27 * 86400_000, "la renovación suma");
  const prof = get("public_profiles/t1");
  assert.strictEqual(prof.is_store, true);
  assert.ok(prof.badges.includes("tienda_oficial"));
  await adminFns.setStorePlanImpl({ uid: "t1", months: 0 }, "jefe");
  assert.strictEqual(get("users/t1").seller_plan, "commission");
  assert.ok(!get("public_profiles/t1").badges.includes("tienda_oficial"));
});

// ---------------- Entrega ----------------
test("deliveryPlan: solo una modalidad se aplica sola; dos → elige el ganador; lotes viejos = acordar", () => {
  assert.deepStrictEqual(delivery.deliveryPlan({}), { choice: "pickup", shipping: 0 });
  assert.deepStrictEqual(delivery.deliveryPlan({ delivery: { regional: true, shipping_cost: 350 } }), { choice: "regional", shipping: 350 });
  assert.deepStrictEqual(delivery.deliveryPlan({ delivery: { regional: true, shipping_cost: 350, shipping_included: true } }), { choice: "regional", shipping: 0 });
  assert.deepStrictEqual(delivery.deliveryPlan({ delivery: { pickup: true, regional: true, shipping_cost: 350 } }), { choice: null, shipping: 0 });
});

test("solo envío: el costo se suma a lo que paga el ganador y va completo al vendedor (sin comisión)", async () => {
  await sale({ lotOver: { delivery: { pickup: false, regional: true, shipping_cost: 400 } } });
  assert.strictEqual(get("lots/B1").amount_due, 10400);
  assert.strictEqual(get("lots/B1").shipping_charge, 400);
  await pay.applyApprovedPayment({ id: "P3", status: "approved", external_reference: "win:B1:ana", transaction_amount: 10400, currency_id: "MXN" });
  const p = get("payments/payout-B1");
  assert.strictEqual(p.shipping, 400);
  assert.strictEqual(p.amount, 10000 - p.commission + 400);
});

test("dos modalidades: el ganador elige; envío suma y regenera el cobro; destino no cubierto se rechaza", async () => {
  await sale({ lotOver: { delivery: { pickup: true, regional: true, shipping_cost: 350, destinations: ["delicias"] } } });
  assert.strictEqual(get("lots/B1").delivery_choice, null);
  assert.strictEqual(get("lots/B1").amount_due, 10000);
  const deps = { createPreference: pay.createPreference };
  await assert.rejects(delivery.chooseDeliveryImpl({ lotId: "B1", mode: "regional", destination: "parral" }, "ana", deps), (e) => e.details.code === "DESTINATION_NOT_COVERED");
  await assert.rejects(delivery.chooseDeliveryImpl({ lotId: "B1", mode: "regional", destination: "delicias" }, "beto", deps), (e) => e.details.code === "NOT_WINNER");
  const r = await delivery.chooseDeliveryImpl({ lotId: "B1", mode: "regional", destination: "delicias" }, "ana", deps);
  assert.strictEqual(r.amountDue, 10350);
  assert.ok(r.paymentUrl);
  assert.strictEqual(get("lots/B1").delivery_destination, "delicias");
  // El cobro viejo (sin envío) ya no alcanza: si se paga, se rechaza.
  const late = await pay.applyApprovedPayment({ id: "OLD", status: "approved", external_reference: "win:B1:ana", transaction_amount: 10000, currency_id: "MXN" });
  assert.strictEqual(late.action, "refund");
  // Cambia a entrega acordada: regresa el monto.
  const r2 = await delivery.chooseDeliveryImpl({ lotId: "B1", mode: "pickup" }, "ana", deps);
  assert.strictEqual(r2.amountDue, 10000);
});

test("con dos modalidades, no se puede pagar por SPEI sin elegir la entrega", async () => {
  await sale({ lotOver: { delivery: { pickup: true, regional: true, shipping_cost: 350 } } });
  S.get("lots/B1").data.payment_options = ["mercadopago", "spei"];
  await assert.rejects(spei.chooseWinnerPaymentMethodImpl({ lotId: "B1", method: "spei" }, "ana"), (e) => e.details.code === "DELIVERY_REQUIRED");
});

// ---------------- Costo del procesador con 0 % ----------------
test("mpProcessingFee: toma el costo real de Mercado Pago (neto recibido o fee_details)", () => {
  assert.strictEqual(policy.mpProcessingFee({ transaction_amount: 10000, transaction_details: { net_received_amount: 9600.5 } }), 399.5);
  assert.strictEqual(policy.mpProcessingFee({ transaction_amount: 100, fee_details: [{ type: "mercadopago_fee", amount: 7.5, fee_payer: "collector" }] }), 7.5);
  assert.strictEqual(policy.mpProcessingFee({ transaction_amount: 100 }), null);
  assert.deepStrictEqual(policy.readFeePayer({}), { payer: "seller" });
  assert.ok(policy.readFeePayer({ ZERO_COMMISSION_FEE_PAYER: "comprador" }).error, "nunca al comprador");
});

test("campaña 0 %: el vendedor paga solo el costo real del cobro; el comprador paga el precio exacto", async () => {
  process.env.COMMISSION_PROMO = "2020-01-01T00:00:00Z/2020-02-01T00:00:00Z";
  try {
    await sale({ lotOver: { closed_time: Timestamp.fromMillis(Date.parse("2020-01-15T00:00:00Z")) } });
    assert.strictEqual(get("lots/B1").amount_due, 10000, "sin recargo al comprador");
    await pay.applyApprovedPayment({
      id: "P9", status: "approved", external_reference: "win:B1:ana", transaction_amount: 10000, currency_id: "MXN",
      transaction_details: { net_received_amount: 9608.6 },
    });
    const p = get("payments/payout-B1");
    assert.strictEqual(p.commission_policy, "promo");
    assert.strictEqual(p.commission, 0);
    assert.strictEqual(p.processing_fee, 391.4);
    assert.strictEqual(p.processing_fee_deducted, 391.4);
    assert.strictEqual(p.amount, 9608.6);
  } finally {
    delete process.env.COMMISSION_PROMO;
  }
});

test("comisión normal: el costo del procesador lo absorbe la comisión (no se descuenta aparte)", async () => {
  await sale();
  await pay.applyApprovedPayment({
    id: "P10", status: "approved", external_reference: "win:B1:ana", transaction_amount: 10000, currency_id: "MXN",
    transaction_details: { net_received_amount: 9608.6 },
  });
  const p = get("payments/payout-B1");
  assert.strictEqual(p.commission_policy, "standard");
  assert.strictEqual(p.processing_fee_deducted, 0);
  assert.strictEqual(p.amount, 10000 - p.commission);
});

test("0 % sin dato del costo real: no se descuenta nada y queda marcado para revisar", async () => {
  await sale({ seller: { seller_plan: "store", store_plan_until: Timestamp.fromMillis(Date.now() + 86400_000 * 30) } });
  await pay.applyApprovedPayment({ id: "P11", status: "approved", external_reference: "win:B1:ana", transaction_amount: 10000, currency_id: "MXN" });
  const p = get("payments/payout-B1");
  assert.strictEqual(p.amount, 10000);
  assert.strictEqual(p.processing_fee_unknown, true);
});

// ---------------- Vendedor fundador (sello) ----------------
test("vendedor fundador: el admin asigna y retira el sello; aparece en el perfil público; no cambia comisiones", async () => {
  fake.__reset();
  put("users/f1", { full_name: "Fernando Ruiz", verified: true });
  put("users/malo", { full_name: "X", banned: true });
  await assert.rejects(adminFns.setFoundingSellerImpl({ uid: "f1", founding: "sí" }, "jefe"), /true\/false/);
  await assert.rejects(adminFns.setFoundingSellerImpl({ uid: "nadie", founding: true }, "jefe"), /no encontrado/);
  await assert.rejects(adminFns.setFoundingSellerImpl({ uid: "malo", founding: true }, "jefe"), /suspendida/);
  await adminFns.setFoundingSellerImpl({ uid: "f1", founding: true }, "jefe");
  assert.strictEqual(get("users/f1").founding_seller, true);
  const prof = get("public_profiles/f1");
  assert.strictEqual(prof.is_founding, true);
  assert.ok(prof.badges.includes("fundador"));
  assert.ok(prof.badges.includes("verificado"));
  // Repetir no rompe nada (idempotente).
  await adminFns.setFoundingSellerImpl({ uid: "f1", founding: true }, "jefe");
  // Solo reconocimiento: la comisión normal no cambia.
  const c = policy.saleCommission({ finalPrice: 10000, seller: get("users/f1"), closedMs: Date.parse("2028-01-01T00:00:00Z"), computeStandard: std, promoConfig: { promo: null }, launchConfig: { launch: null } });
  assert.strictEqual(c.policy, "standard");
  await adminFns.setFoundingSellerImpl({ uid: "f1", founding: false }, "jefe");
  assert.strictEqual(get("users/f1").founding_seller, false);
  assert.ok(!get("public_profiles/f1").badges.includes("fundador"));
});
