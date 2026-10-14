const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const fake = require("./helpers/fake_admin");
const mp = require("./helpers/fake_mp");
const storageFiles = new Set();
const revoked = [];
fake.storage = () => ({
  bucket: () => ({ file: (p) => ({ exists: async () => [storageFiles.has(p)] }) }),
});
fake.auth = () => ({ revokeRefreshTokens: async (uid) => revoked.push(uid) });
function inject(name, obj) {
  const r = require.resolve(name);
  require.cache[r] = { id: r, filename: r, loaded: true, exports: obj };
}
inject("firebase-admin", fake);
inject("mercadopago", mp);
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";
process.env.MP_ACCESS_TOKEN = "TEST";
const fns = require(path.join(__dirname, "..", "index.js"));

const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const user = (uid) => ({ auth: { uid, token: { email_verified: true } } });
const adminCtx = { auth: { uid: "jefe", token: { email_verified: true, admin: true } } };

function reset() {
  fake.__reset();
  mp.__reset();
  storageFiles.clear();
  put("users/ana", { full_name: "Ana Pérez", email: "ana@x.com" });
}
const files = (uid) => ({
  ine_front: `verifications/${uid}/ine_front.jpg`,
  ine_back: `verifications/${uid}/ine_back.jpg`,
  selfie: `verifications/${uid}/selfie.jpg`,
});

test("verificación: enviar, aprobar y quedar verificado", async () => {
  reset();
  Object.values(files("ana")).forEach((f) => storageFiles.add(f));
  await fns.submitIdentityVerification.run({ files: files("ana") }, user("ana"));
  assert.strictEqual(get("verifications/ana").status, "pending");

  await fns.adminReviewVerification.run({ uid: "ana", approve: true }, adminCtx);
  assert.strictEqual(get("verifications/ana").status, "approved");
  assert.strictEqual(get("users/ana").verified, true);
  assert.ok([...S.keys()].some((k) => k.startsWith("admin_log/")));
});

test("verificación: no acepta fotos de otra persona ni faltantes", async () => {
  reset();
  await assert.rejects(
    fns.submitIdentityVerification.run({ files: files("beto") }, user("ana")),
    (e) => e.code === "invalid-argument"
  );
  await assert.rejects(
    fns.submitIdentityVerification.run({ files: files("ana") }, user("ana")), // no existen
    (e) => e.code === "invalid-argument"
  );
});

test("rechazo exige motivo", async () => {
  reset();
  Object.values(files("ana")).forEach((f) => storageFiles.add(f));
  await fns.submitIdentityVerification.run({ files: files("ana") }, user("ana"));
  await assert.rejects(
    fns.adminReviewVerification.run({ uid: "ana", approve: false }, adminCtx),
    (e) => e.code === "invalid-argument"
  );
  await fns.adminReviewVerification.run({ uid: "ana", approve: false, reason: "INE borrosa" }, adminCtx);
  assert.strictEqual(get("users/ana").verified, false);
});

test("un usuario normal no puede usar funciones de admin", async () => {
  reset();
  await assert.rejects(
    fns.adminSetBan.run({ uid: "ana", banned: true }, user("beto")),
    (e) => e.code === "permission-denied"
  );
});

test("suspender revoca la sesión; marcar payout enviado una sola vez", async () => {
  reset();
  await fns.adminSetBan.run({ uid: "ana", banned: true, reason: "fraude" }, adminCtx);
  assert.strictEqual(get("users/ana").banned, true);
  assert.ok(revoked.includes("ana"));

  put("payments/payout-L1", { kind: "payout", status: "ready", uid: "vendedor", amount: 900, lot_id: "L1" });
  await fns.adminMarkPayoutSent.run({ paymentId: "payout-L1", reference: "SPEI123" }, adminCtx);
  assert.strictEqual(get("payments/payout-L1").status, "sent");
  await assert.rejects(
    fns.adminMarkPayoutSent.run({ paymentId: "payout-L1", reference: "SPEI123" }, adminCtx),
    (e) => e.code === "failed-precondition"
  );
});

test("cancelar lote activo avisa a vendedor y líder", async () => {
  reset();
  put("lots/L1", { title: "Bici", status: "active", seller_uid: "vendedor", highest_bidder_uid: "ana" });
  await fns.adminCancelLot.run({ lotId: "L1", reason: "Artículo prohibido" }, adminCtx);
  assert.strictEqual(get("lots/L1").status, "cancelled");
  const n = [...S.keys()].filter((k) => k.includes("/notifications/"));
  assert.strictEqual(n.length, 2);
});

test("reintentar cobro cuando Mercado Pago había fallado", async () => {
  reset();
  put("users/ana", { full_name: "Ana", deposit: { status: "held", amount: 200, mp_payment_id: "D" } });
  put("users/vendedor", { full_name: "Vero" });
  put("lots/L1", {
    title: "Bici", status: "ended", seller_uid: "vendedor", current_bid: 1000,
    winner_uid: "ana", payment_status: "payment_error",
  });
  const r = await fns.adminRetryWinnerPayment.run({ lotId: "L1" }, adminCtx);
  assert.ok(r.url);
  assert.strictEqual(get("lots/L1").payment_status, "pending");
  assert.strictEqual(get("lots/L1").amount_due, 800);
});

test("pujas altas requieren identidad verificada", async () => {
  reset();
  put("users/ana", {
    full_name: "Ana P", phone: "1", accepted_terms: true,
    deposit: { status: "held", amount: 200 },
  });
  put("lots/L", {
    title: "Auto", status: "active", seller_uid: "vendedor", starting_price: 100000,
    current_bid: 100000, minimum_increment: 1000, bid_count: 0,
    start_time: fake.firestore.Timestamp.fromMillis(Date.now() - 1000),
    end_time: fake.firestore.Timestamp.fromMillis(Date.now() + 3600_000),
  });
  await assert.rejects(
    fns.placeBid.run({ lotId: "L", max_amount: 150000 }, user("ana")),
    (e) => e.details && e.details.code === "IDENTITY_REQUIRED"
  );
  S.get("users/ana").data.verified = true;
  const r = await fns.placeBid.run({ lotId: "L", max_amount: 150000 }, user("ana"));
  assert.strictEqual(r.ok, true);
});
