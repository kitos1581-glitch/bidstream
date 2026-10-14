/**
 * Flujo de dinero de punta a punta con Firestore y Mercado Pago simulados.
 */
const test = require("node:test");
const assert = require("node:assert");
const crypto = require("node:crypto");
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
const fns = require(path.join(__dirname, "..", "index.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const children = (prefix) =>
  [...S.keys()]
    .filter((p) => p.startsWith(prefix + "/") && !p.slice(prefix.length + 1).includes("/"))
    .map((p) => ({ id: p.split("/").pop(), ...S.get(p).data }));
const payouts = () => children("payments").filter((p) => p.kind === "payout");

function reset() {
  fake.__reset();
  mp.__reset();
  put("users/vendedor", { full_name: "Vero Vendedora", phone: "6140000000", city: "Camargo" });
  put("users/ana", {
    full_name: "Ana Pérez",
    phone: "6141111111",
    accepted_terms: true,
    deposit: { status: "held", amount: 200, mp_payment_id: "DEP1" },
  });
}

function endedLot(id, price, over = {}) {
  put(`lots/${id}`, {
    title: `Lote ${id}`,
    status: "active",
    seller_uid: "vendedor",
    starting_price: 100,
    current_bid: price,
    minimum_increment: 50,
    bid_count: 1,
    highest_bidder_uid: "ana",
    highest_bidder_name: "Ana P.",
    start_time: Timestamp.fromMillis(Date.now() - 7200_000),
    end_time: Timestamp.fromMillis(Date.now() - 1000),
    ...over,
  });
}

async function closeAll() {
  await fns.closeEndedAuctions.run({});
}

function webhookReq(paymentId) {
  const ts = "1700000000";
  const requestId = crypto.randomUUID();
  const manifest = `id:${String(paymentId).toLowerCase()};request-id:${requestId};ts:${ts};`;
  const v1 = crypto.createHmac("sha256", "secreto").update(manifest).digest("hex");
  return {
    query: { type: "payment", "data.id": String(paymentId) },
    headers: { "x-signature": `ts=${ts},v1=${v1}`, "x-request-id": requestId },
    body: {},
  };
}
function fakeRes() {
  const r = { code: null, body: null };
  r.status = (c) => { r.code = c; return r; };
  r.send = (b) => { r.body = b; return r; };
  return r;
}
async function webhook(paymentId) {
  const res = fakeRes();
  await fns.mpWebhook(webhookReq(paymentId), res);
  return res;
}

// ---------------------------------------------------------------------

test("el depósito solo se descuenta UNA vez aunque gane varios lotes", async () => {
  reset();
  endedLot("A", 1000);
  endedLot("B", 1000);
  await closeAll();
  const due = [get("lots/A").amount_due, get("lots/B").amount_due].sort((a, b) => a - b);
  assert.deepStrictEqual(due, [800, 1000]); // 1000−200 y 1000 completo
  assert.strictEqual(get("users/ana").deposit.status, "reserved");
  assert.strictEqual(mp.__calls.preferences.length, 2);
  // La preferencia expira con la fecha límite.
  assert.ok(mp.__calls.preferences.every((p) => p.expires === true));
});

test("si el depósito supera el precio, se liquida y se reembolsa la diferencia", async () => {
  reset();
  endedLot("A", 150);
  await closeAll();
  const lot = get("lots/A");
  assert.strictEqual(lot.payment_status, "paid");
  assert.strictEqual(get("users/ana").deposit.status, "applied");
  assert.deepStrictEqual(mp.__calls.refunds, [{ payment_id: "DEP1", amount: 50 }]);
  assert.strictEqual(payouts()[0].amount, 135); // 150 − 10%
});

test("pago del ganador aprobado: liquida una sola vez y comparte contactos", async () => {
  reset();
  endedLot("A", 1000);
  await closeAll();
  // Antes de pagar, el ganador NO tiene el teléfono del vendedor.
  const before = children("users/ana/notifications").map((n) => n.body).join(" ");
  assert.ok(!before.includes("6140000000"));

  mp.__payments.set("P1", {
    id: "P1",
    status: "approved",
    external_reference: "win:A:ana",
    transaction_amount: 800,
    currency_id: "MXN",
  });
  const r1 = await webhook("P1");
  const r2 = await webhook("P1"); // MP reenvía la notificación
  assert.strictEqual(r1.code, 200);
  assert.strictEqual(r2.code, 200);

  assert.strictEqual(get("lots/A").payment_status, "paid");
  assert.strictEqual(get("users/ana").deposit.status, "applied");
  assert.strictEqual(payouts().length, 1);
  assert.strictEqual(payouts()[0].amount, 900);
  const after = children("users/ana/notifications").map((n) => n.body).join(" ");
  assert.ok(after.includes("6140000000"), "tras pagar sí recibe el contacto");
});

test("pago con monto menor al adeudado se reembolsa y no liquida", async () => {
  reset();
  endedLot("A", 1000);
  await closeAll();
  mp.__payments.set("P2", {
    id: "P2", status: "approved", external_reference: "win:A:ana",
    transaction_amount: 10, currency_id: "MXN",
  });
  await webhook("P2");
  assert.strictEqual(get("lots/A").payment_status, "pending");
  assert.strictEqual(payouts().length, 0);
  assert.deepStrictEqual(mp.__calls.refunds, [{ payment_id: "P2", amount: undefined }]);
});

test("no pagó a tiempo: pierde el depósito reservado, strike y compensación", async () => {
  reset();
  endedLot("A", 1000);
  await closeAll();
  S.get("lots/A").data.payment_due_time = Timestamp.fromMillis(Date.now() - 1);
  await fns.expireUnpaidWins.run({});
  assert.strictEqual(get("lots/A").payment_status, "forfeited");
  const ana = get("users/ana");
  assert.strictEqual(ana.deposit.status, "forfeited");
  assert.strictEqual(ana.strikes, 1);
  assert.strictEqual(payouts()[0].reason, "deposit_forfeit");
  assert.strictEqual(payouts()[0].amount, 200);
});

test("pago tardío después del castigo: se reembolsa, no se paga doble al vendedor", async () => {
  reset();
  endedLot("A", 1000);
  await closeAll();
  S.get("lots/A").data.payment_due_time = Timestamp.fromMillis(Date.now() - 1);
  await fns.expireUnpaidWins.run({});
  mp.__payments.set("P3", {
    id: "P3", status: "approved", external_reference: "win:A:ana",
    transaction_amount: 800, currency_id: "MXN",
  });
  await webhook("P3");
  assert.strictEqual(get("lots/A").payment_status, "forfeited");
  assert.strictEqual(payouts().length, 1); // solo la compensación
  assert.ok(mp.__calls.refunds.some((r) => r.payment_id === "P3"));
});

test("segundo incumplimiento banea la cuenta", async () => {
  reset();
  S.get("users/ana").data.strikes = 1;
  endedLot("A", 1000);
  await closeAll();
  S.get("lots/A").data.payment_due_time = Timestamp.fromMillis(Date.now() - 1);
  await fns.expireUnpaidWins.run({});
  assert.strictEqual(get("users/ana").banned, true);
});

test("si Mercado Pago falla al cerrar, el lote queda en payment_error (no se castiga)", async () => {
  reset();
  mp.__setFailPreference(true);
  endedLot("A", 1000);
  await closeAll();
  assert.strictEqual(get("lots/A").payment_status, "payment_error");
  assert.strictEqual(get("lots/A").payment_due_time, null);
});

test("depósito por webhook: se activa una vez; un segundo depósito se reembolsa", async () => {
  reset();
  put("users/beto", { full_name: "Beto R", phone: "1", accepted_terms: true });
  mp.__payments.set("D1", {
    id: "D1", status: "approved", external_reference: "deposit:beto",
    transaction_amount: 200, currency_id: "MXN",
  });
  mp.__payments.set("D2", {
    id: "D2", status: "approved", external_reference: "deposit:beto",
    transaction_amount: 200, currency_id: "MXN",
  });
  await webhook("D1");
  await webhook("D1");
  assert.strictEqual(get("users/beto").deposit.status, "held");
  assert.strictEqual(get("users/beto").deposit.mp_payment_id, "D1");
  await webhook("D2");
  assert.ok(mp.__calls.refunds.some((r) => r.payment_id === "D2"));
  assert.strictEqual(get("users/beto").deposit.mp_payment_id, "D1");
});

test("firma inválida del webhook se rechaza", async () => {
  reset();
  const req = webhookReq("X1");
  req.headers["x-signature"] = "ts=1,v1=deadbeef";
  const res = fakeRes();
  await fns.mpWebhook(req, res);
  assert.strictEqual(res.code, 401);
});

test("reembolso de depósito: bloqueado si va ganando; si no, una sola vez", async () => {
  reset();
  put("lots/V", { status: "active", highest_bidder_uid: "ana", seller_uid: "vendedor" });
  const ctx = { auth: { uid: "ana", token: { email_verified: true } } };
  await assert.rejects(fns.requestDepositRefund.run({}, ctx), (e) => e.code === "failed-precondition");

  S.delete("lots/V");
  const results = await Promise.allSettled([
    fns.requestDepositRefund.run({}, ctx),
    fns.requestDepositRefund.run({}, ctx),
  ]);
  assert.strictEqual(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.strictEqual(mp.__calls.refunds.length, 1);
  assert.strictEqual(get("users/ana").deposit.status, "refunded");
});

test("no se puede pujar mientras el depósito se está reembolsando", async () => {
  reset();
  S.get("users/ana").data.deposit.status = "refunding";
  put("lots/L", {
    title: "x", status: "active", seller_uid: "vendedor", starting_price: 100,
    current_bid: 100, minimum_increment: 10, bid_count: 0,
    start_time: Timestamp.fromMillis(Date.now() - 1000),
    end_time: Timestamp.fromMillis(Date.now() + 3600_000),
  });
  const ctx = { auth: { uid: "ana", token: { email_verified: true } } };
  await assert.rejects(
    fns.placeBid.run({ lotId: "L", max_amount: 500 }, ctx),
    (e) => e.details && e.details.code === "DEPOSIT_REQUIRED"
  );
});
