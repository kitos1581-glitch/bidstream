/**
 * Retención del pago al vendedor: confirmación de entrega y liberación por plazo.
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
const esc = require(path.join(__dirname, "..", "escrow.js"));
const dis = require(path.join(__dirname, "..", "disputes.js"));
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const DAY = 86400_000;

async function paidSale() {
  fake.__reset();
  mp.__reset();
  put("users/vendedor", { full_name: "Vero Vendedora" });
  put("users/ana", { full_name: "Ana Pérez" });
  put("lots/E1", { title: "Reloj", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 5000, payment_status: "pending", amount_due: 5000 });
  await pay.applyApprovedPayment({ id: "MPE", status: "approved", external_reference: "win:E1:ana", transaction_amount: 5000, currency_id: "MXN" });
}
async function rejectsWith(p, code) {
  await assert.rejects(p, (e) => e.details && e.details.code === code);
}

test("al pagar, la liquidación queda RETENIDA con fecha de liberación (7 días por defecto)", async () => {
  await paidSale();
  const p = get("payments/payout-E1");
  assert.strictEqual(p.status, "held");
  const days = (p.release_after.toMillis() - Date.now()) / DAY;
  assert.ok(days > 6.9 && days <= 7.01);
  assert.ok(get("lots/E1").escrow_release_at);
});

test("el comprador confirma de recibido → se libera (ready) una sola vez", async () => {
  await paidSale();
  const r = await esc.confirmReceiptImpl({ lotId: "E1" }, "ana");
  assert.deepStrictEqual(r, { ok: true, alreadyConfirmed: false });
  assert.strictEqual(get("payments/payout-E1").status, "ready");
  assert.strictEqual(get("payments/payout-E1").released_by, "buyer");
  const again = await esc.confirmReceiptImpl({ lotId: "E1" }, "ana");
  assert.strictEqual(again.alreadyConfirmed, true);
});

test("confirmar: solo el comprador, con pago confirmado y sin reclamo abierto", async () => {
  await paidSale();
  await rejectsWith(esc.confirmReceiptImpl({ lotId: "E1" }, "vendedor"), "NOT_BUYER");
  await rejectsWith(esc.confirmReceiptImpl({ lotId: "E1" }, null), "UNAUTHENTICATED");
  await dis.openDisputeImpl({ lotId: "E1", reason: "not_delivered", details: "No ha llegado nada después de una semana." }, "ana");
  await rejectsWith(esc.confirmReceiptImpl({ lotId: "E1" }, "ana"), "DISPUTE_OPEN");
});

test("liberación por plazo: solo vencidas y sin reclamo abierto", async () => {
  await paidSale();
  assert.strictEqual(await esc.releaseDuePayouts(Date.now() + 6 * DAY), 0);
  assert.strictEqual(await esc.releaseDuePayouts(Date.now() + 8 * DAY), 1);
  assert.strictEqual(get("payments/payout-E1").status, "ready");
  assert.strictEqual(get("payments/payout-E1").released_by, "timeout");

  await paidSale();
  await dis.openDisputeImpl({ lotId: "E1", reason: "not_delivered", details: "No ha llegado nada después de una semana." }, "ana");
  assert.strictEqual(await esc.releaseDuePayouts(Date.now() + 8 * DAY), 0, "con reclamo abierto no se libera");
});

test("PAYOUT_RELEASE_DAYS inválido = error explícito, sin liberación automática", () => {
  assert.deepStrictEqual(pay.readReleaseDays({}), { days: 7 });
  assert.deepStrictEqual(pay.readReleaseDays({ PAYOUT_RELEASE_DAYS: "10" }), { days: 10 });
  assert.strictEqual(pay.readReleaseDays({ PAYOUT_RELEASE_DAYS: "abc" }).days, null);
  assert.ok(pay.readReleaseDays({ PAYOUT_RELEASE_DAYS: "0" }).error);
});

// ---------------- Código de entrega en persona ----------------
const code = () => get("users/ana/delivery_codes/E1").code;
const enter = (c, uid = "vendedor") => esc.confirmDeliveryCodeImpl({ lotId: "E1", code: c }, uid);

test("entrega en persona: el comprador recibe su código; el servidor solo guarda la huella", async () => {
  await paidSale();
  assert.match(code(), /^\d{6}$/);
  const priv = get("lots/E1/private/delivery_code");
  assert.ok(priv.code_hash && !JSON.stringify(priv).includes(code()), "el código no se guarda en claro en el lote");
  assert.ok(!JSON.stringify(get("lots/E1")).includes(code()));
});

test("el vendedor captura el código correcto → pago liberado al instante", async () => {
  await paidSale();
  const r = await enter(code());
  assert.deepStrictEqual(r, { ok: true, alreadyConfirmed: false });
  assert.strictEqual(get("payments/payout-E1").status, "ready");
  assert.strictEqual(get("payments/payout-E1").released_by, "delivery_code");
  assert.strictEqual(get("lots/E1").delivered_by, "code");
  await rejectsWith(dis.openDisputeImpl({ lotId: "E1", reason: "not_delivered", details: "Nunca me entregaron nada de nada." }, "ana"), "WINDOW_CLOSED");
});

test("código: solo el vendedor, 6 dígitos, máximo 5 intentos fallidos", async () => {
  await paidSale();
  await rejectsWith(enter(code(), "ana"), "NOT_SELLER");
  await rejectsWith(enter("12"), "INVALID_ARGUMENT");
  const wrong = code() === "000000" ? "111111" : "000000";
  for (let i = 0; i < 5; i++) await rejectsWith(enter(wrong), "WRONG_CODE");
  await rejectsWith(enter(code()), "TOO_MANY_ATTEMPTS");
  assert.strictEqual(get("payments/payout-E1").status, "held", "sigue retenido");
});

test("con reclamo abierto el código no libera el pago", async () => {
  await paidSale();
  await dis.openDisputeImpl({ lotId: "E1", reason: "not_as_described", details: "El reloj no funciona como decía la publicación." }, "ana");
  await rejectsWith(enter(code()), "DISPUTE_OPEN");
});

test("envío regional: no hay código (se libera al confirmar el comprador o por plazo)", async () => {
  fake.__reset();
  mp.__reset();
  put("users/vendedor", { full_name: "Vero Vendedora" });
  put("users/ana", { full_name: "Ana Pérez" });
  put("lots/E1", { title: "Reloj", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 5000, payment_status: "pending", amount_due: 5000, delivery_choice: "regional" });
  await pay.applyApprovedPayment({ id: "MPR", status: "approved", external_reference: "win:E1:ana", transaction_amount: 5000, currency_id: "MXN" });
  assert.strictEqual(get("users/ana/delivery_codes/E1"), undefined);
  await rejectsWith(enter("123456"), "NO_CODE");
});
