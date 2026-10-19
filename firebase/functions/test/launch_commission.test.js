/**
 * Periodo de lanzamiento: 0 % de comisión para todos hasta LAUNCH_FREE_UNTIL,
 * con tope de ventas por mes (LAUNCH_FREE_MAX_MONTHLY_SALES). Desde la venta
 * siguiente al tope, en ese mes, comisión normal. Tienda Oficial: 0 % siempre
 * (cuota fija). El conteo lo lleva el servidor dentro de la transacción.
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
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const std = (p) => pay.computeCommission(p);
const UNTIL = "2027-03-31T23:59:59-06:00";
const NOV = Date.parse("2026-11-20T12:00:00-06:00");
const APR = Date.parse("2027-04-01T00:00:01-06:00");

function withEnv(vars, fn) {
  const old = {};
  for (const k of Object.keys(vars)) {
    old[k] = process.env[k];
    process.env[k] = vars[k];
  }
  return Promise.resolve()
    .then(fn)
    .finally(() => {
      for (const k of Object.keys(vars)) {
        if (old[k] === undefined) delete process.env[k];
        else process.env[k] = old[k];
      }
    });
}

test("readLaunch: vacío = sin lanzamiento; formato estricto; tope 30 por defecto", () => {
  assert.deepStrictEqual(policy.readLaunch({}), { launch: null });
  assert.deepStrictEqual(policy.readLaunch({ LAUNCH_FREE_UNTIL: UNTIL }).launch, { end: Date.parse(UNTIL), max: 30 });
  assert.strictEqual(policy.readLaunch({ LAUNCH_FREE_UNTIL: UNTIL, LAUNCH_FREE_MAX_MONTHLY_SALES: "50" }).launch.max, 50);
  assert.ok(policy.readLaunch({ LAUNCH_FREE_UNTIL: "2027-03-31" }).error, "sin hora ni zona → error");
  assert.ok(policy.readLaunch({ LAUNCH_FREE_UNTIL: UNTIL, LAUNCH_FREE_MAX_MONTHLY_SALES: "0" }).error);
  assert.ok(policy.readLaunch({ LAUNCH_FREE_UNTIL: UNTIL, LAUNCH_FREE_MAX_MONTHLY_SALES: "treinta" }).error);
  assert.ok(policy.readLaunch({ LAUNCH_FREE_UNTIL: UNTIL, LAUNCH_FREE_MAX_MONTHLY_SALES: "2.5" }).error);
});

test("monthKey: usa la hora del centro de México (la medianoche del 1 en UTC sigue siendo el mes anterior)", () => {
  assert.strictEqual(policy.monthKey(Date.parse("2026-12-01T03:00:00Z")), "2026-11");
  assert.strictEqual(policy.monthKey(Date.parse("2026-12-01T06:00:00Z")), "2026-12");
});

test("saleCommission: 0 % en lanzamiento hasta el tope; la 31.ª paga; después de la fecha, normal", () => {
  const lc = policy.readLaunch({ LAUNCH_FREE_UNTIL: UNTIL });
  const pc = { promo: null };
  const base = { finalPrice: 10000, seller: {}, computeStandard: std, promoConfig: pc, launchConfig: lc };
  assert.deepStrictEqual(policy.saleCommission({ ...base, closedMs: NOV, monthSaleNumber: 1 }), { commission: 0, policy: "launch", launchMax: 30 });
  assert.strictEqual(policy.saleCommission({ ...base, closedMs: NOV, monthSaleNumber: 30 }).policy, "launch");
  const over = policy.saleCommission({ ...base, closedMs: NOV, monthSaleNumber: 31 });
  assert.strictEqual(over.policy, "standard");
  assert.strictEqual(over.launchLimitReached, true);
  assert.ok(over.commission > 0);
  const later = policy.saleCommission({ ...base, closedMs: APR, monthSaleNumber: 1 });
  assert.strictEqual(later.policy, "standard");
  assert.ok(!later.launchLimitReached);
  // La tienda sigue en 0 % aunque pase el tope (paga cuota fija).
  const store = { seller_plan: "store", store_plan_until: Timestamp.fromMillis(APR + 86400_000) };
  assert.strictEqual(policy.saleCommission({ ...base, seller: store, closedMs: NOV, monthSaleNumber: 99 }).policy, "store");
  // La campaña (Buen Fin) va antes que el tope: sin límite de ventas.
  const promo = policy.readPromo({ COMMISSION_PROMO: "2026-11-13T00:00:00-06:00/2026-11-17T23:59:59-06:00" });
  assert.strictEqual(policy.saleCommission({ ...base, promoConfig: promo, closedMs: Date.parse("2026-11-15T12:00:00-06:00"), monthSaleNumber: 99 }).policy, "promo");
  assert.throws(() => policy.saleCommission({ ...base, launchConfig: { error: "x" }, closedMs: NOV }));
});

async function sellAndPay(id, closedMs, seller = {}) {
  if (!get("users/vendedor")) put("users/vendedor", { full_name: "Vero Vendedora", verified: true, ...seller });
  if (!get("users/ana")) put("users/ana", { full_name: "Ana Pérez", email: "a@t.mx" });
  put(`lots/${id}`, { title: `Artículo ${id}`, status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 10000, closed_time: Timestamp.fromMillis(closedMs) });
  await pay.startWinnerPayment(fake.firestore().collection("lots").doc(id), get(`lots/${id}`), "ana");
  await pay.applyApprovedPayment({ id: `P_${id}`, status: "approved", external_reference: `win:${id}:ana`, transaction_amount: 10000, currency_id: "MXN" });
  return get(`payments/payout-${id}`);
}

test("liquidación: cuenta las ventas del mes y cobra desde la que pasa el tope (tope 2 para la prueba)", async () => {
  await withEnv({ LAUNCH_FREE_UNTIL: UNTIL, LAUNCH_FREE_MAX_MONTHLY_SALES: "2" }, async () => {
    fake.__reset();
    mp.__reset();
    const p1 = await sellAndPay("A1", NOV);
    const p2 = await sellAndPay("A2", NOV + 1000);
    const p3 = await sellAndPay("A3", NOV + 2000);
    assert.deepStrictEqual([p1.commission_policy, p2.commission_policy, p3.commission_policy], ["launch", "launch", "standard"]);
    assert.deepStrictEqual([p1.month_sale_number, p2.month_sale_number, p3.month_sale_number], [1, 2, 3]);
    assert.strictEqual(p1.commission, 0);
    assert.ok(p3.commission > 0);
    assert.strictEqual(get("users/vendedor").monthly_sales["2026-11"], 3);
    const notes = [...S.keys()].filter((k) => k.startsWith("users/vendedor/notifications/")).map((k) => S.get(k).data.body);
    assert.ok(notes.some((b) => /venta 1 de 2 este mes/.test(b)));
    assert.ok(notes.some((b) => /Llegaste a 2 ventas sin comisión/.test(b)), "aviso al llegar al tope");
    assert.ok(notes.some((b) => /ya pasaste las 2 ventas sin comisión/.test(b)));
    // Mes nuevo: el conteo empieza de cero.
    const dec = await sellAndPay("A4", Date.parse("2026-12-02T12:00:00-06:00"));
    assert.strictEqual(dec.commission_policy, "launch");
    assert.strictEqual(dec.month_sale_number, 1);
    assert.strictEqual(get("users/vendedor").monthly_sales["2026-11"], 3, "noviembre no se toca");
  });
});

test("cuenta por mes de CIERRE: un pago tardío de un lote de noviembre no gasta el cupo de diciembre", async () => {
  await withEnv({ LAUNCH_FREE_UNTIL: UNTIL, LAUNCH_FREE_MAX_MONTHLY_SALES: "1" }, async () => {
    fake.__reset();
    mp.__reset();
    put("users/vendedor", { full_name: "Vero", verified: true, monthly_sales: { "2026-12": 1 } });
    const p = await sellAndPay("B1", NOV);
    assert.strictEqual(p.commission_policy, "launch", "es la 1.ª de noviembre");
    assert.strictEqual(get("users/vendedor").monthly_sales["2026-12"], 1);
  });
});

test("configuración inválida → en revisión; el admin recalcula con el número de venta guardado", async () => {
  await withEnv({ LAUNCH_FREE_UNTIL: "marzo", LAUNCH_FREE_MAX_MONTHLY_SALES: "1" }, async () => {
    fake.__reset();
    mp.__reset();
    put("users/vendedor", { full_name: "Vero", verified: true, monthly_sales: { "2026-11": 4 } });
    const p = await sellAndPay("C1", NOV);
    assert.strictEqual(p.status, "needs_review");
    assert.strictEqual(p.month_sale_number, 5);
    process.env.LAUNCH_FREE_UNTIL = UNTIL;
    await adminFns.adminRecalculatePayout.run({ paymentId: "payout-C1" }, { auth: { uid: "jefe", token: { admin: true } } });
    const fixed = get("payments/payout-C1");
    assert.strictEqual(fixed.commission_policy, "standard", "la 5.ª pasa el tope de 1");
    assert.ok(fixed.commission > 0);
  });
});
