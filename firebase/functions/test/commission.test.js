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
const {
  computeCommission,
  parseTiers,
  readCommissionConfig,
  CommissionConfigError,
} = require(path.join(__dirname, "..", "payments.js"));

const cfg = readCommissionConfig({ COMMISSION_TIERS: "10000:0.10,100000:0.08,inf:0.06" });

test("tramos marginales", () => {
  assert.strictEqual(computeCommission(5000, cfg), 500);
  assert.strictEqual(computeCommission(10000, cfg), 1000);
  assert.strictEqual(computeCommission(50000, cfg), 1000 + 3200);
  assert.strictEqual(computeCommission(300000, cfg), 1000 + 7200 + 12000);
});

test("sin brincos al cruzar un tramo", () => {
  assert.ok(computeCommission(10001, cfg) - computeCommission(9999, cfg) < 1);
});

test("comisión mínima y nunca mayor al precio", () => {
  const c = readCommissionConfig({ COMMISSION_TIERS: "10000:0.10,inf:0.05", COMMISSION_MIN: "50" });
  assert.strictEqual(computeCommission(200, c), 50);
  assert.strictEqual(computeCommission(30, c), 30);
});

test("sin variables: 10% plano por defecto (explícito y documentado)", () => {
  assert.strictEqual(computeCommission(1000, readCommissionConfig({})), 100);
  assert.strictEqual(computeCommission(1000, readCommissionConfig({ COMMISSION_PCT: "0.07" })), 70);
});

test("configuraciones inválidas producen error explícito, nunca otro porcentaje", () => {
  const bad = [
    { COMMISSION_TIERS: "10000:0.1,5000:0.2,inf:0.1" }, // desordenado
    { COMMISSION_TIERS: "10000:0.1" }, // falta inf
    { COMMISSION_TIERS: "10000:diez,inf:0.1" }, // no numérico
    { COMMISSION_TIERS: "10000:1.5,inf:0.1" }, // 150%
    { COMMISSION_TIERS: "10000:-0.1,inf:0.1" }, // negativo
    { COMMISSION_TIERS: " , " }, // vacío
    { COMMISSION_TIERS: "10000-0.1,inf:0.1" }, // mal escrito
    { COMMISSION_PCT: "10" }, // 1000%
    { COMMISSION_PCT: "abc" },
    { COMMISSION_MIN: "-5" },
  ];
  for (const env of bad) {
    assert.throws(() => readCommissionConfig(env), CommissionConfigError, JSON.stringify(env));
  }
  assert.throws(() => parseTiers("10000:0.1"), CommissionConfigError);
});

test("sin configuración válida, calcular la comisión lanza error", () => {
  assert.throws(() => computeCommission(1000, null), CommissionConfigError);
});
