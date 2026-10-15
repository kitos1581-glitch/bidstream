/**
 * Disputas: apertura, ventana de 72 h, congelamiento de liquidación,
 * resoluciones con reembolso idempotente y abuso.
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
const dis = require(path.join(__dirname, "..", "disputes.js"));
const rep = require(path.join(__dirname, "..", "reputation.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const children = (prefix) =>
  [...S.keys()]
    .filter((p) => p.startsWith(prefix + "/") && !p.slice(prefix.length + 1).includes("/"))
    .map((p) => ({ id: p.split("/").pop(), ...S.get(p).data }));

/** Venta pagada de verdad: depósito $200 aplicado + pago MP de $9,800. */
async function paidSale() {
  fake.__reset();
  mp.__reset();
  put("users/vendedor", { full_name: "Vero Vendedora", verified: true });
  put("users/ana", { full_name: "Ana Pérez", deposit: { status: "held", amount: 200, mp_payment_id: "DEP1" } });
  put("lots/S1", { title: "Silla", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 10000 });
  await pay.startWinnerPayment(fake.firestore().collection("lots").doc("S1"), get("lots/S1"), "ana");
  await pay.applyApprovedPayment({ id: "MP9", status: "approved", external_reference: "win:S1:ana", transaction_amount: 9800, currency_id: "MXN" });
  assert.strictEqual(get("lots/S1").payment_status, "paid");
  assert.strictEqual(get("payments/payout-S1").status, "held", "retenida hasta confirmar la entrega");
}
const open = (over = {}, uid = "ana", now) =>
  dis.openDisputeImpl({ lotId: "S1", reason: "not_as_described", details: "La silla llegó con la piel rota y no se dijo.", ...over }, uid, now);
async function rejectsWith(p, code) {
  await assert.rejects(p, (e) => e.details && e.details.code === code);
}

test("abrir disputa congela la liquidación, marca el lote y el perfil 'en disputa'", async () => {
  await paidSale();
  const r = await open({ photos: ["disputes/ana/1.jpg"] });
  assert.deepStrictEqual(r, { ok: true, disputeId: "S1", status: "open" });
  assert.strictEqual(get("payments/payout-S1").status, "on_hold");
  assert.strictEqual(get("lots/S1").dispute_status, "open");
  assert.strictEqual(get("public_profiles/vendedor").open_disputes, 1);
  await rep.refreshProfile("vendedor");
  assert.ok(get("public_profiles/vendedor").badges.includes("en_disputa"));
  assert.ok(children("users/vendedor/notifications").some((n) => n.type === "dispute_opened"));
});

test("abuso al abrir: no comprador, sin pago, fuera de plazo, doble reclamo, fotos ajenas", async () => {
  await paidSale();
  await rejectsWith(open({}, "beto"), "NOT_BUYER");
  await rejectsWith(open({}, null), "UNAUTHENTICATED");
  await rejectsWith(open({ reason: "porque si" }), "INVALID_ARGUMENT");
  await rejectsWith(open({ details: "corto" }), "INVALID_ARGUMENT");
  await rejectsWith(open({ photos: ["verifications/vero/ine.png"] }), "INVALID_ARGUMENT");
  await rejectsWith(open({ photos: ["disputes/ana/../vero/x.jpg"] }), "INVALID_ARGUMENT");
  await rejectsWith(open({}, "ana", Date.now() + 8 * 86400_000), "WINDOW_CLOSED");
  await open();
  await rejectsWith(open(), "ALREADY_EXISTS");
  S.get("lots/S1").data.payment_status = "pending";
  await rejectsWith(open({}, "ana"), "NOT_PAID");
});

test("disputa abierta bloquea la calificación del comprador", async () => {
  await paidSale();
  await open();
  await assert.rejects(rep.submitFeedbackImpl({ lotId: "S1", rating: 1 }, "ana"), (e) => e.details.code === "DISPUTE_OPEN");
});

test("con disputa abierta el admin NO puede marcar la liquidación como transferida", async () => {
  await paidSale();
  await open();
  assert.strictEqual(get("payments/payout-S1").status, "on_hold"); // adminMarkPayoutSent exige "ready"
});

test("reembolso total: devuelve pago (9,800) + depósito (200), cancela liquidación, una sola vez", async () => {
  await paidSale();
  await open();
  const r = await dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_full", note: "Fotos confirman daño" }, "jefe");
  assert.strictEqual(r.refundAmount, 10000);
  const refunds = mp.__calls.refunds;
  assert.deepStrictEqual(refunds.map((x) => [x.payment_id, x.amount]).sort(), [["DEP1", 200], ["MP9", 9800]]);
  assert.strictEqual(get("payments/payout-S1").status, "cancelled");
  assert.strictEqual(get("disputes/S1").status, "resolved");
  assert.strictEqual(get("lots/S1").dispute_status, "resolved");
  assert.strictEqual(get("public_profiles/vendedor").open_disputes, 0);
  await rejectsWith(dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_full" }, "jefe"), "NOT_OPEN");
  assert.strictEqual(mp.__calls.refunds.length, 2, "no se reembolsa dos veces");
  assert.ok(children("admin_log").some((l) => l.action === "dispute_resolved"));
});

test("reembolso parcial: baja la liquidación en ese monto y la deja retenida como antes", async () => {
  await paidSale();
  const before = get("payments/payout-S1").amount;
  await open();
  await dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_partial", amount: 1500 }, "jefe");
  const payout = get("payments/payout-S1");
  assert.strictEqual(payout.status, "held");
  assert.strictEqual(payout.amount, before - 1500);
  assert.deepStrictEqual(mp.__calls.refunds.map((x) => [x.payment_id, x.amount]), [["MP9", 1500]]);
});

test("reembolso parcial inválido (0, negativo o ≥ precio) se rechaza sin tocar dinero", async () => {
  await paidSale();
  await open();
  for (const amount of [0, -5, 10000, 20000, "abc"]) {
    await rejectsWith(dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_partial", amount }, "jefe"), "INVALID_ARGUMENT");
  }
  assert.strictEqual(mp.__calls.refunds.length, 0);
  assert.strictEqual(get("disputes/S1").status, "open");
});

test("rechazar: la liquidación vuelve a como estaba (retenida) sin reembolsos", async () => {
  await paidSale();
  await open();
  await dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "reject" }, "jefe");
  assert.strictEqual(get("payments/payout-S1").status, "held");
  assert.strictEqual(mp.__calls.refunds.length, 0);
  assert.ok(children("users/ana/notifications").some((n) => n.type === "dispute_resolved"));
});

test("si ya se había transferido al vendedor, el reembolso registra un clawback", async () => {
  await paidSale();
  S.get("payments/payout-S1").data.status = "sent";
  await open();
  assert.strictEqual(get("disputes/S1").payout_already_sent, true);
  await dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_partial", amount: 800 }, "jefe");
  const cb = get("payments/clawback-S1");
  assert.strictEqual(cb.kind, "clawback");
  assert.strictEqual(cb.amount, 800);
  assert.strictEqual(cb.uid, "vendedor");
});

test("Mercado Pago rechaza el reembolso: la disputa queda 'refund_failed' y se puede reintentar", async () => {
  await paidSale();
  await open();
  mp.__failRefunds(true);
  await rejectsWith(dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_partial", amount: 500 }, "jefe"), "REFUND_FAILED");
  assert.strictEqual(get("disputes/S1").status, "refund_failed");
  assert.strictEqual(get("payments/payout-S1").status, "on_hold", "la liquidación sigue congelada");
  mp.__failRefunds(false);
  await dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_partial", amount: 500 }, "jefe");
  assert.strictEqual(get("disputes/S1").status, "resolved");
});

test("solo administradores resuelven", () => {
  assert.throws(() => dis.requireAdminUid({}), (e) => e.details.code === "UNAUTHENTICATED");
  assert.throws(() => dis.requireAdminUid({ auth: { uid: "ana", token: {} } }), (e) => e.details.code === "PERMISSION_DENIED");
  assert.strictEqual(dis.requireAdminUid({ auth: { uid: "jefe", token: { admin: true } } }), "jefe");
});


test("reembolso total da strike al vendedor; al segundo se suspende; el admin puede evitarlo", async () => {
  await paidSale();
  await open();
  const r = await dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_full" }, "jefe");
  assert.strictEqual(r.sellerStrikes, 1);
  assert.strictEqual(get("users/vendedor").banned, undefined);
  await paidSale();
  S.get("users/vendedor").data.seller_strikes = 1;
  await open();
  const r2 = await dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_full" }, "jefe");
  assert.strictEqual(r2.sellerStrikes, 2);
  assert.strictEqual(get("users/vendedor").banned, true);
  await paidSale();
  await open();
  const r3 = await dis.adminResolveDisputeImpl({ disputeId: "S1", resolution: "refund_full", sellerStrike: false }, "jefe");
  assert.strictEqual(r3.sellerStrikes, null);
});

test("después de confirmar de recibido ya no se puede reclamar", async () => {
  await paidSale();
  const esc = require(path.join(__dirname, "..", "escrow.js"));
  await esc.confirmReceiptImpl({ lotId: "S1" }, "ana");
  await rejectsWith(open(), "WINDOW_CLOSED");
});
