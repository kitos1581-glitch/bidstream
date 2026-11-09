/** Códigos de referido: alta solo en cuentas nuevas, una vez, nunca el propio; ventas atribuidas. */
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

const ref = require(path.join(__dirname, "..", "referral.js"));
const pay = require(path.join(__dirname, "..", "payments.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });

test("normalizeCode", () => {
  assert.strictEqual(ref.normalizeCode(" pepe10 "), "PEPE10");
  assert.strictEqual(ref.normalizeCode("ab"), null);
  assert.strictEqual(ref.normalizeCode("con espacio"), null);
  assert.strictEqual(ref.normalizeCode("a/b"), null);
});

test("admin crea código; no se repite", async () => {
  fake.__reset();
  const r = await ref.createReferralCodeImpl({ code: "pepe10", name: "Pepe TikTok" }, "jefe");
  assert.strictEqual(r.code, "PEPE10");
  assert.match(r.link, /\?ref=PEPE10$/);
  assert.strictEqual(get("referral_codes/PEPE10").signups, 0);
  await assert.rejects(ref.createReferralCodeImpl({ code: "PEPE10", name: "Otro" }, "jefe"), /ya existe/);
});

test("claim: cuenta nueva sí (una vez); vieja, código inexistente o propio no", async () => {
  fake.__reset();
  const now = Date.now();
  put("referral_codes/PEPE10", { name: "Pepe", active: true, signups: 0, owner_uid: "pepe" });
  put("users/ana", { created_time: Timestamp.fromMillis(now - 86400000) });
  put("users/vieja", { created_time: Timestamp.fromMillis(now - 30 * 86400000) });
  put("users/pepe", { created_time: Timestamp.fromMillis(now) });
  assert.deepStrictEqual(await ref.claimReferralImpl({ code: "pepe10" }, "ana", now), { ok: true, code: "PEPE10" });
  assert.strictEqual(get("users/ana").referred_by, "PEPE10");
  assert.strictEqual(get("referral_codes/PEPE10").signups, 1);
  assert.strictEqual((await ref.claimReferralImpl({ code: "PEPE10" }, "ana", now)).reason, "ALREADY");
  assert.strictEqual(get("referral_codes/PEPE10").signups, 1, "no se cuenta dos veces");
  assert.strictEqual((await ref.claimReferralImpl({ code: "PEPE10" }, "vieja", now)).reason, "NOT_NEW");
  assert.strictEqual((await ref.claimReferralImpl({ code: "NOEXISTE" }, "pepe", now)).reason, "UNKNOWN_CODE");
  assert.strictEqual((await ref.claimReferralImpl({ code: "PEPE10" }, "pepe", now)).reason, "OWN_CODE");
  await assert.rejects(ref.claimReferralImpl({ code: "PEPE10" }, null, now), /Inicia sesión/);
});

test("la venta pagada suma al código del comprador y al del vendedor", async () => {
  fake.__reset();
  mp.__reset();
  put("referral_codes/COMPRA", { name: "A", active: true });
  put("referral_codes/VENDE", { name: "B", active: true });
  put("users/vendedor", { full_name: "Vero V", verified: true, referred_by: "VENDE" });
  put("users/ana", { full_name: "Ana P", email: "a@t.mx", referred_by: "COMPRA" });
  put("lots/R1", { title: "Silla", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 1500, closed_time: Timestamp.fromMillis(Date.now()) });
  await pay.startWinnerPayment(fake.firestore().collection("lots").doc("R1"), get("lots/R1"), "ana");
  await pay.applyApprovedPayment({ id: "PR1", status: "approved", external_reference: "win:R1:ana", transaction_amount: 1500, currency_id: "MXN" });
  assert.strictEqual(get("referral_codes/COMPRA").buyers_purchases, 1);
  assert.strictEqual(get("referral_codes/COMPRA").buyers_amount, 1500);
  assert.strictEqual(get("referral_codes/VENDE").sellers_sales, 1);
  // El mismo aviso de pago otra vez no duplica.
  await pay.applyApprovedPayment({ id: "PR1", status: "approved", external_reference: "win:R1:ana", transaction_amount: 1500, currency_id: "MXN" });
  assert.strictEqual(get("referral_codes/COMPRA").buyers_purchases, 1);
});
