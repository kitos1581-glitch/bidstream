/**
 * Pago en efectivo (OXXO / tiendas) y transferencia para el GANADOR de una
 * subasta. Nunca en "aparta y paga" ni en el depósito. Un pago pendiente NO
 * cuenta como pagado; uno aprobado después del plazo se reembolsa.
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

const pay = require(path.join(__dirname, "..", "payments.js"));
const delivery = require(path.join(__dirname, "..", "delivery.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const H = 3600 * 1000;

function reset() {
  fake.__reset();
  mp.__reset();
  put("users/vendedor", { full_name: "Vero", verified: true });
  put("users/ana", { full_name: "Ana", email: "a@t.mx" });
}

test("readOfflinePayments: on por defecto, margen 4 h; inválido → apagado con error", () => {
  assert.deepStrictEqual(pay.readOfflinePayments({}), { enabled: true, marginMs: 4 * H });
  assert.strictEqual(pay.readOfflinePayments({ OFFLINE_PAYMENTS: "off" }).enabled, false);
  assert.strictEqual(pay.readOfflinePayments({ OFFLINE_PAYMENT_MARGIN_HOURS: "6" }).marginMs, 6 * H);
  const bad = pay.readOfflinePayments({ OFFLINE_PAYMENTS: "si" });
  assert.strictEqual(bad.enabled, false);
  assert.ok(bad.error);
  assert.ok(pay.readOfflinePayments({ OFFLINE_PAYMENT_MARGIN_HOURS: "0" }).error);
  assert.ok(pay.readOfflinePayments({ OFFLINE_PAYMENT_MARGIN_HOURS: "2.5" }).error);
});

test("offlineOptionsFor: subasta sí; aparta y paga no; plazo corto no", () => {
  const now = Date.parse("2026-11-10T12:00:00-06:00");
  const sub = pay.offlineOptionsFor({}, now + 24 * H, now, {});
  assert.strictEqual(sub.allowOffline, true);
  assert.strictEqual(sub.cashExpiresAt, now + 20 * H, "la ficha vence 4 h antes del plazo");
  assert.strictEqual(pay.offlineOptionsFor({ pay_first: true }, now + 24 * H, now, {}).allowOffline, false);
  assert.strictEqual(pay.offlineOptionsFor({}, now + 5 * H, now, {}).allowOffline, false, "quedaría < 2 h de ficha");
  assert.strictEqual(pay.offlineOptionsFor({}, now + 24 * H, now, { OFFLINE_PAYMENTS: "off" }).allowOffline, false);
});

test("ganador de subasta: preferencia SIN binary_mode y con vencimiento de ficha; el lote guarda cash_payment_until", async () => {
  reset();
  put("lots/L1", { title: "Silla", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 500 });
  await pay.startWinnerPayment(fake.firestore().collection("lots").doc("L1"), get("lots/L1"), "ana");
  const pref = mp.__calls.preferences.at(-1);
  assert.strictEqual(pref.binary_mode, false);
  assert.deepStrictEqual(pref.payment_methods.excluded_payment_types, []);
  assert.ok(pref.date_of_expiration, "la ficha tiene vencimiento");
  assert.ok(Date.parse(pref.date_of_expiration) < Date.parse(pref.expiration_date_to), "vence antes del plazo");
  assert.ok(get("lots/L1").cash_payment_until, "el lote muestra hasta cuándo se paga en efectivo");
});

test("aparta y paga y depósito: solo pago inmediato (binary_mode y efectivo excluido)", async () => {
  reset();
  put("lots/L2", { title: "Mesa", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 300, pay_first: true });
  await pay.startWinnerPayment(fake.firestore().collection("lots").doc("L2"), get("lots/L2"), "ana");
  const pref = mp.__calls.preferences.at(-1);
  assert.strictEqual(pref.binary_mode, true);
  assert.deepStrictEqual(pref.payment_methods.excluded_payment_types.map((t) => t.id).sort(), ["atm", "bank_transfer", "ticket"]);
  assert.strictEqual(pref.date_of_expiration, undefined);
  assert.strictEqual(get("lots/L2").cash_payment_until, null);
});

test("ficha OXXO pendiente: NO marca pagado, avisa al comprador una sola vez; luego aprobado → pagado", async () => {
  reset();
  put("lots/L3", { title: "Bici", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 1000 });
  const lotRef = fake.firestore().collection("lots").doc("L3");
  await pay.startWinnerPayment(lotRef, get("lots/L3"), "ana");
  const pending = { id: 777, status: "pending", payment_type_id: "ticket", payment_method_id: "oxxo", external_reference: "win:L3:ana", transaction_amount: 1000, currency_id: "MXN" };
  mp.__payments.set("777", pending);
  await pay.handlePaymentNotification("777");
  await pay.handlePaymentNotification("777"); // MP repite el aviso
  let lot = get("lots/L3");
  assert.strictEqual(lot.payment_status, "pending", "pendiente no es pagado");
  assert.strictEqual(lot.offline_payment_pending, true);
  assert.strictEqual(lot.offline_payment_method, "oxxo");
  const notes = [...S.keys()].filter((k) => k.startsWith("users/ana/notifications/")).map((k) => S.get(k).data);
  assert.strictEqual(notes.filter((n) => n.type === "payment_pending").length, 1);
  assert.ok(!get("payments/payout-L3"), "al vendedor no se le liquida nada todavía");

  mp.__payments.set("777", { ...pending, status: "approved" });
  await pay.handlePaymentNotification("777");
  lot = get("lots/L3");
  assert.strictEqual(lot.payment_status, "paid");
  assert.strictEqual(lot.offline_payment_pending, false);
  assert.ok(get("payments/payout-L3"), "ahora sí hay liquidación");
});

test("OXXO pagado después de perder el lote → se reembolsa completo", async () => {
  reset();
  put("lots/L4", { title: "Tele", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 800 });
  const lotRef = fake.firestore().collection("lots").doc("L4");
  await pay.startWinnerPayment(lotRef, get("lots/L4"), "ana");
  put("lots/L4", { ...get("lots/L4"), payment_due_time: Timestamp.fromMillis(Date.now() - 1000) });
  assert.strictEqual(await pay.forfeitWin(lotRef), true);
  assert.strictEqual(get("lots/L4").payment_status, "forfeited");
  mp.__payments.set("888", { id: 888, status: "approved", payment_type_id: "ticket", payment_method_id: "oxxo", external_reference: "win:L4:ana", transaction_amount: 800, currency_id: "MXN" });
  await pay.handlePaymentNotification("888");
  assert.ok(mp.__calls.refunds.some((r) => r.payment_id === "888"), "se devolvió");
  assert.notStrictEqual(get("lots/L4").payment_status, "paid");
});

test("con ficha generada ya no se puede cambiar la entrega (cambiaría el monto)", async () => {
  reset();
  put("lots/L5", {
    title: "Sofá", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 2000,
    payment_status: "pending", amount_due: 2000, offline_payment_pending: true,
    payment_due_time: Timestamp.fromMillis(Date.now() + 20 * H),
    delivery: { pickup: true, regional: true, regional_fee: 100 },
  });
  await assert.rejects(
    delivery.chooseDeliveryImpl({ lotId: "L5", mode: "pickup" }, "ana", { createPreference: pay.createPreference, offlineOptionsFor: pay.offlineOptionsFor }),
    (e) => /ficha/.test(e.message)
  );
});
