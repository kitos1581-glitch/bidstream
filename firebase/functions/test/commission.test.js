const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const fake = require("./helpers/fake_admin");
const mp = require("./helpers/fake_mp");
for (const [n, o] of [["firebase-admin", fake], ["mercadopago", mp]]) {
  const r = require.resolve(n);
  require.cache[r] = { id: r, filename: r, loaded: true, exports: o };
}
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";
const { computeCommission, parseTiers } = require(path.join(__dirname, "..", "payments.js"));

const tiers = parseTiers("10000:0.10,100000:0.08,inf:0.06");

test("tramos marginales", () => {
  assert.strictEqual(computeCommission(5000, tiers, 0), 500);
  assert.strictEqual(computeCommission(10000, tiers, 0), 1000);
  assert.strictEqual(computeCommission(50000, tiers, 0), 1000 + 3200);
  assert.strictEqual(computeCommission(300000, tiers, 0), 1000 + 7200 + 12000);
});

test("sin brincos al cruzar un tramo", () => {
  const a = computeCommission(9999, tiers, 0);
  const b = computeCommission(10001, tiers, 0);
  assert.ok(b - a < 1);
});

test("comisión mínima y nunca mayor al precio", () => {
  assert.strictEqual(computeCommission(200, tiers, 50), 50);
  assert.strictEqual(computeCommission(30, tiers, 50), 30);
});

test("sin tramos usa porcentaje plano", () => {
  assert.strictEqual(computeCommission(1000, null, 0, 0.1), 100);
});

test("tramos inválidos se ignoran", () => {
  assert.strictEqual(parseTiers("10000:0.1,5000:0.2,inf:0.1"), null);
  assert.strictEqual(parseTiers("10000:0.1"), null); // falta inf
  assert.strictEqual(parseTiers(""), null);
});
