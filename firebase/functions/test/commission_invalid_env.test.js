/**
 * Con COMMISSION_TIERS inválido: el pago se registra, la liquidación queda
 * en revisión con error explícito y NO se usa otro porcentaje en silencio.
 */
const test = require("node:test");
const assert = require("node:assert");
const crypto = require("node:crypto");
const path = require("node:path");

process.env.COMMISSION_TIERS = "10000:0.10,5000:0.08"; // inválido: desordenado y sin inf
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";
process.env.MP_ACCESS_TOKEN = "TEST";
process.env.MP_WEBHOOK_SECRET = "secreto";

const fake = require("./helpers/fake_admin");
const mp = require("./helpers/fake_mp");
for (const [n, o] of [["firebase-admin", fake], ["mercadopago", mp]]) {
  const r = require.resolve(n);
  require.cache[r] = { id: r, filename: r, loaded: true, exports: o };
}
const pay = require(path.join(__dirname, "..", "payments.js"));
const fns = require(path.join(__dirname, "..", "index.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);

function webhookReq(id) {
  const ts = "1";
  const rid = "r1";
  const v1 = crypto.createHmac("sha256", "secreto").update(`id:${id.toLowerCase()};request-id:${rid};ts:${ts};`).digest("hex");
  return { query: { type: "payment", "data.id": id }, headers: { "x-signature": `ts=${ts},v1=${v1}`, "x-request-id": rid }, body: {} };
}

test("la configuración inválida se reporta y no se reemplaza por otro valor", () => {
  assert.match(pay.getCommissionConfigError(), /orden creciente|inf/);
  assert.throws(() => pay.computeCommission(1000), pay.CommissionConfigError);
});

test("el pago entra, la liquidación queda en revisión y el admin no puede 'arreglarla' sin corregir la config", async () => {
  fake.__reset();
  S.set("users/ana", { version: 1, data: { full_name: "Ana", phone: "1", deposit: { status: "held", amount: 200, mp_payment_id: "D" } } });
  S.set("users/vendedor", { version: 1, data: { full_name: "Vero", phone: "2" } });
  S.set("lots/A", {
    version: 1,
    data: {
      title: "Bici", status: "active", seller_uid: "vendedor", starting_price: 100, current_bid: 1000,
      minimum_increment: 50, bid_count: 1, highest_bidder_uid: "ana", highest_bidder_name: "Ana",
      start_time: Timestamp.fromMillis(Date.now() - 7200_000), end_time: Timestamp.fromMillis(Date.now() - 1000),
    },
  });
  await fns.closeEndedAuctions.run({});
  mp.__payments.set("P1", { id: "P1", status: "approved", external_reference: "win:A:ana", transaction_amount: 800, currency_id: "MXN" });
  const res = { status(c) { this.code = c; return this; }, send() { return this; } };
  await fns.mpWebhook(webhookReq("P1"), res);
  assert.strictEqual(res.code, 200);
  assert.strictEqual(get("lots/A").payment_status, "paid");
  const payout = get("payments/payout-A");
  assert.strictEqual(payout.status, "needs_review");
  assert.strictEqual(payout.amount, null);
  assert.match(payout.error, /Configuración de comisiones inválida/);

  const adminCtx = { auth: { uid: "jefe", token: { admin: true } } };
  await assert.rejects(
    fns.adminRecalculatePayout.run({ paymentId: "payout-A" }, adminCtx),
    (e) => e.code === "failed-precondition" && /sigue inválida/.test(e.message)
  );
});
