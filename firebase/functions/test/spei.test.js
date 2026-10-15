/**
 * Pago final por SPEI (Openpay) con Firestore y Openpay simulados.
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
const OP_ENV = {
  OPENPAY_MERCHANT_ID: "m0000000000000000000",
  OPENPAY_PRIVATE_KEY: "sk_00000000000000000000000000000000",
  OPENPAY_SANDBOX: "true",
  OPENPAY_WEBHOOK_USER: "webhook",
  OPENPAY_WEBHOOK_PASS: "una-clave-larga-1234",
};
function setOpenpayEnv(on) {
  for (const [k, v] of Object.entries(OP_ENV)) {
    if (on) process.env[k] = v;
    else delete process.env[k];
  }
}

const openpay = require(path.join(__dirname, "..", "openpay.js"));
const pay = require(path.join(__dirname, "..", "payments.js"));
const spei = require(path.join(__dirname, "..", "spei.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const children = (prefix) =>
  [...S.keys()]
    .filter((p) => p.startsWith(prefix + "/") && !p.slice(prefix.length + 1).includes("/"))
    .map((p) => ({ id: p.split("/").pop(), ...S.get(p).data }));

// ---------------- Openpay falso ----------------
const op = { creates: [], gets: [], charges: new Map(), failCreate: null, orders: new Set() };
function fakeClient() {
  return {
    async createSpeiCharge(args) {
      if (op.failCreate) throw op.failCreate;
      if (op.orders.has(args.orderId)) {
        throw new openpay.ProviderError("duplicate order", { provider: "openpay", providerCode: 1006, httpStatus: 409 });
      }
      op.orders.add(args.orderId);
      op.creates.push(args);
      const id = `tr_${op.creates.length}`;
      op.charges.set(id, { id, status: "in_progress", method: "bank_account", amount: args.amount, currency: "MXN", orderId: args.orderId });
      return { id, status: "in_progress", amount: args.amount, clabe: "646180109400000001", bank: "STP", reference: "1234567", dueDate: null };
    },
    async getCharge(id) {
      op.gets.push(id);
      const c = op.charges.get(id);
      if (!c) throw new openpay.ProviderError("not found", { provider: "openpay", httpStatus: 404 });
      return c;
    },
  };
}
spei.__setClientFactory(() => fakeClient());

function reset({ configured = true } = {}) {
  fake.__reset();
  mp.__reset();
  op.creates = [];
  op.gets = [];
  op.charges = new Map();
  op.failCreate = null;
  op.orders = new Set();
  setOpenpayEnv(configured);
  put("users/vendedor", { full_name: "Vero Vendedora", phone: "6140000000", city: "Camargo" });
  put("users/ana", { full_name: "Ana Pérez", email: "ana@test.mx", phone: "6141111111" });
  put("lots/T1", {
    title: "Tractor",
    status: "ended",
    seller_uid: "vendedor",
    winner_uid: "ana",
    winner_name: "Ana P.",
    current_bid: 300000,
    final_price: 300000,
    payment_status: "pending",
    amount_due: 299800,
    deposit_applied: 200,
    payment_due_time: Timestamp.fromMillis(Date.now() + 3600_000),
    payment_options: ["mercadopago", "spei"],
    winner_payment_url: "https://mp.test/checkout/pref_1",
  });
}
const choose = (data, uid = "ana") => spei.chooseWinnerPaymentMethodImpl(data, uid);
async function rejectsWith(promise, code) {
  await assert.rejects(promise, (e) => e.details && e.details.code === code);
}
function completeCharge(id, over = {}) {
  op.charges.set(id, { ...op.charges.get(id), status: "completed", ...over });
}

// ---------------- Configuración estricta ----------------
test("config de Openpay: falta o inválida → error explícito, nunca valores por defecto", () => {
  assert.throws(() => openpay.readOpenpayConfig({}), openpay.PaymentConfigError);
  assert.throws(() => openpay.readOpenpayConfig({ ...OP_ENV, OPENPAY_SANDBOX: "" }), /OPENPAY_SANDBOX/);
  assert.throws(() => openpay.readOpenpayConfig({ ...OP_ENV, OPENPAY_PRIVATE_KEY: "pk_123" }), /sk_/);
  assert.throws(() => openpay.readOpenpayConfig({ ...OP_ENV, OPENPAY_WEBHOOK_PASS: "corta" }), /WEBHOOK/);
  const c = openpay.readOpenpayConfig(OP_ENV);
  assert.strictEqual(c.baseUrl, "https://sandbox-api.openpay.mx/v1/m0000000000000000000");
  assert.strictEqual(openpay.readOpenpayConfig({ ...OP_ENV, OPENPAY_SANDBOX: "false" }).baseUrl.startsWith("https://api.openpay.mx"), true);
});

test("cliente Openpay: manda auth básica y traduce errores (reintentable o no)", async () => {
  const seen = [];
  const fetchOk = async (url, init) => {
    seen.push({ url, init });
    return { ok: true, status: 200, json: async () => ({ id: "tr_9", status: "in_progress", amount: 100, payment_method: { clabe: "646", bank: "STP", name: "ref" } }) };
  };
  const client = openpay.createOpenpayClient(openpay.readOpenpayConfig(OP_ENV), { fetchImpl: fetchOk });
  const r = await client.createSpeiCharge({ amount: 100, description: "x", orderId: "win_T1" });
  assert.strictEqual(r.clabe, "646");
  assert.match(seen[0].init.headers.Authorization, /^Basic /);
  assert.strictEqual(JSON.parse(seen[0].init.body).method, "bank_account");

  const fetch500 = async () => ({ ok: false, status: 503, json: async () => ({ description: "down", error_code: 1000 }) });
  const c2 = openpay.createOpenpayClient(openpay.readOpenpayConfig(OP_ENV), { fetchImpl: fetch500 });
  await assert.rejects(c2.getCharge("x"), (e) => e instanceof openpay.ProviderError && e.retryable === true);
  const fetch409 = async () => ({ ok: false, status: 409, json: async () => ({ description: "dup", error_code: 1006 }) });
  const c3 = openpay.createOpenpayClient(openpay.readOpenpayConfig(OP_ENV), { fetchImpl: fetch409 });
  await assert.rejects(c3.createSpeiCharge({ amount: 1, orderId: "a" }), (e) => e.providerCode === 1006 && !e.retryable);
});

// ---------------- Elegir método ----------------
test("SPEI: el ganador obtiene CLABE; llamar dos veces devuelve la MISMA referencia", async () => {
  reset();
  const a = await choose({ lotId: "T1", method: "spei" });
  assert.strictEqual(a.ok, true);
  assert.strictEqual(a.method, "spei");
  assert.strictEqual(a.clabe, "646180109400000001");
  assert.strictEqual(a.amount, 299800);
  const b = await choose({ lotId: "T1", method: "spei" });
  assert.strictEqual(b.clabe, a.clabe);
  assert.strictEqual(op.creates.length, 1, "no se crea una segunda referencia");
  assert.strictEqual(op.creates[0].orderId, "win_T1_ana");
  assert.strictEqual(get("lots/T1").payment_method_chosen, "spei");
  assert.strictEqual(get("payments/openpay_charge_tr_1").lot_id, "T1");
  // El lote es público: no debe contener la CLABE.
  assert.strictEqual(JSON.stringify(get("lots/T1")).includes("646180109400000001"), false);
  assert.strictEqual(get("lots/T1").spei_charge_id, "tr_1");
});

test("SPEI: validaciones (no ganador, ya pagado, vencido, método no ofrecido, argumentos)", async () => {
  reset();
  await rejectsWith(choose({ lotId: "T1", method: "spei" }, null), "UNAUTHENTICATED");
  await rejectsWith(choose({ lotId: "T1", method: "spei" }, "beto"), "NOT_WINNER");
  await rejectsWith(choose({ lotId: "T1", method: "bitcoin" }), "INVALID_ARGUMENT");
  await rejectsWith(choose({ lotId: "a/b", method: "spei" }), "INVALID_ARGUMENT");
  await rejectsWith(choose({ lotId: "NOPE", method: "spei" }), "LOT_NOT_FOUND");
  S.get("lots/T1").data.payment_due_time = Timestamp.fromMillis(Date.now() - 1000);
  await rejectsWith(choose({ lotId: "T1", method: "spei" }), "PAYMENT_EXPIRED");
  reset();
  S.get("lots/T1").data.payment_options = ["mercadopago"];
  await rejectsWith(choose({ lotId: "T1", method: "spei" }), "METHOD_NOT_AVAILABLE");
  reset();
  S.get("lots/T1").data.payment_status = "paid";
  await rejectsWith(choose({ lotId: "T1", method: "spei" }), "NOT_PENDING");
  assert.strictEqual(op.creates.length, 0);
});

test("SPEI sin configurar → PROVIDER_NOT_CONFIGURED y se libera el candado", async () => {
  reset({ configured: false });
  await rejectsWith(choose({ lotId: "T1", method: "spei" }), "PROVIDER_NOT_CONFIGURED");
  assert.strictEqual(get("lots/T1").spei_creating_until, undefined);
});

test("Openpay caído → PROVIDER_ERROR, sin referencia guardada, y se puede reintentar", async () => {
  reset();
  op.failCreate = new openpay.ProviderError("down", { provider: "openpay", httpStatus: 503, retryable: true });
  await rejectsWith(choose({ lotId: "T1", method: "spei" }), "PROVIDER_ERROR");
  assert.strictEqual(get("lots/T1").spei, undefined);
  assert.strictEqual(get("lots/T1").spei_creating_until, undefined);
  op.failCreate = null;
  const ok = await choose({ lotId: "T1", method: "spei" });
  assert.strictEqual(ok.ok, true);
});

test("dos solicitudes SPEI simultáneas: solo una crea referencia", async () => {
  reset();
  const results = await Promise.allSettled([
    choose({ lotId: "T1", method: "spei" }),
    choose({ lotId: "T1", method: "spei" }),
  ]);
  assert.strictEqual(op.creates.length, 1);
  assert.ok(results.some((r) => r.status === "fulfilled"));
  for (const r of results) {
    if (r.status === "rejected") assert.strictEqual(r.reason.details.code, "IN_PROGRESS");
  }
});

test("Mercado Pago sigue disponible como opción y devuelve su liga", async () => {
  reset();
  const r = await choose({ lotId: "T1", method: "mercadopago" });
  assert.deepStrictEqual(r, { ok: true, method: "mercadopago", url: "https://mp.test/checkout/pref_1", amount: 299800 });
});

// ---------------- Webhook ----------------
test("webhook: SPEI completado liquida el lote UNA sola vez (aunque llegue repetido)", async () => {
  reset();
  const a = await choose({ lotId: "T1", method: "spei" });
  assert.ok(a.clabe);
  completeCharge("tr_1");
  const evt = { type: "charge.succeeded", transaction: { id: "tr_1", amount: 1 } }; // monto falso en el cuerpo: se ignora
  assert.strictEqual(await spei.handleOpenpayEvent(evt), 200);
  assert.strictEqual(await spei.handleOpenpayEvent(evt), 200);
  const lot = get("lots/T1");
  assert.strictEqual(lot.payment_status, "paid");
  assert.strictEqual(lot.paid_with, "openpay");
  const payouts = children("payments").filter((p) => p.kind === "payout");
  assert.strictEqual(payouts.length, 1, "un solo pago al vendedor");
  assert.strictEqual(get("payments/openpay_tr_1").status, "approved");
  assert.ok(op.gets.length >= 1, "se consulta Openpay en lugar de confiar en el cuerpo");
});

test("webhook: cargo no completado, monto menor u otro order_id no liquida", async () => {
  reset();
  await choose({ lotId: "T1", method: "spei" });
  await spei.handleOpenpayEvent({ type: "charge.succeeded", transaction: { id: "tr_1" } }); // sigue in_progress
  assert.strictEqual(get("lots/T1").payment_status, "pending");
  completeCharge("tr_1", { orderId: "otro" });
  await spei.handleOpenpayEvent({ type: "charge.succeeded", transaction: { id: "tr_1" } });
  assert.strictEqual(get("lots/T1").payment_status, "pending");
  completeCharge("tr_1", { orderId: "win_T1_ana", amount: 1000 });
  await spei.handleOpenpayEvent({ type: "charge.succeeded", transaction: { id: "tr_1" } });
  assert.strictEqual(get("lots/T1").payment_status, "pending", "monto menor no liquida");
  assert.strictEqual(get("payments/refund_openpay_tr_1").status, "manual_required");
});

test("webhook: SPEI tardío (ya castigado) → reembolso manual registrado y aviso", async () => {
  reset();
  await choose({ lotId: "T1", method: "spei" });
  S.get("lots/T1").data.payment_status = "forfeited";
  completeCharge("tr_1");
  await spei.handleOpenpayEvent({ type: "charge.succeeded", transaction: { id: "tr_1" } });
  const refund = get("payments/refund_openpay_tr_1");
  assert.strictEqual(refund.status, "manual_required");
  assert.strictEqual(refund.amount, 299800);
  assert.ok(children("users/ana/notifications").some((n) => n.type === "payment_refund_pending"));
});

test("pagó por Mercado Pago Y por SPEI: el segundo pago se rechaza (no se paga doble al vendedor)", async () => {
  reset();
  await choose({ lotId: "T1", method: "spei" });
  // Primero llega Mercado Pago.
  await pay.applyApprovedPayment({ id: "MP77", status: "approved", external_reference: "win:T1:ana", transaction_amount: 299800, currency_id: "MXN" });
  assert.strictEqual(get("lots/T1").payment_status, "paid");
  completeCharge("tr_1");
  await spei.handleOpenpayEvent({ type: "charge.succeeded", transaction: { id: "tr_1" } });
  assert.strictEqual(children("payments").filter((p) => p.kind === "payout").length, 1);
  assert.strictEqual(get("payments/refund_openpay_tr_1").status, "manual_required");
});

test("webhook: verificación y eventos ajenos responden 200 sin efectos; cargo desconocido se ignora", async () => {
  reset();
  assert.strictEqual(await spei.handleOpenpayEvent({ type: "verification", verification_code: "ABC" }), 200);
  assert.strictEqual(await spei.handleOpenpayEvent({ type: "charge.refunded" }), 200);
  assert.strictEqual(await spei.handleOpenpayEvent({ type: "charge.succeeded", transaction: { id: "tr_x" } }), 200);
  assert.strictEqual(op.gets.length, 0);
});

test("autenticación básica del webhook", () => {
  const cfg = openpay.readOpenpayConfig(OP_ENV);
  const good = "Basic " + Buffer.from("webhook:una-clave-larga-1234").toString("base64");
  const bad = "Basic " + Buffer.from("webhook:otra").toString("base64");
  assert.strictEqual(spei.checkBasicAuth(good, cfg), true);
  assert.strictEqual(spei.checkBasicAuth(bad, cfg), false);
  assert.strictEqual(spei.checkBasicAuth(undefined, cfg), false);
});

test("al quedar pendiente el pago, el lote ofrece SPEI solo si Openpay está configurado", async () => {
  for (const configured of [true, false]) {
    reset({ configured });
    put("users/ana", { full_name: "Ana Pérez", email: "a@t.mx", deposit: { status: "held", amount: 200, mp_payment_id: "D1" } });
    put("lots/N1", { title: "Novillos", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 50000 });
    await pay.startWinnerPayment(fake.firestore().collection("lots").doc("N1"), get("lots/N1"), "ana");
    assert.deepStrictEqual(get("lots/N1").payment_options, configured ? ["mercadopago", "spei"] : ["mercadopago"]);
  }
});
