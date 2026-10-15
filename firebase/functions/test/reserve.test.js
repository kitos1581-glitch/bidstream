/**
 * Precio de reserva: secreto, sube el precio a la reserva al alcanzarla,
 * cierre sin venta si no se alcanza, solo bajar con pujas, nunca en vivo.
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

const fns = require(path.join(__dirname, "..", "index.js"));
const { applyReserve } = require(path.join(__dirname, "..", "auction_logic.js"));
const reserve = require(path.join(__dirname, "..", "reserve.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const children = (prefix) =>
  [...S.keys()]
    .filter((p) => p.startsWith(prefix + "/") && !p.slice(prefix.length + 1).includes("/"))
    .map((p) => ({ id: p.split("/").pop(), ...S.get(p).data }));

function seed({ format = "timed", endInMs = 3600_000 } = {}) {
  fake.__reset();
  mp.__reset();
  const now = Date.now();
  for (const uid of ["ana", "beto", "vendedor"]) {
    S.set(`users/${uid}`, {
      version: 1,
      data: { full_name: `${uid} Pérez`, phone: "614", accepted_terms: true, deposit: { status: "held", amount: 200, mp_payment_id: `D_${uid}` } },
    });
  }
  S.set("lots/R1", {
    version: 1,
    data: {
      title: "Novillos", status: "active", format, seller_uid: "vendedor",
      starting_price: 1000, current_bid: 1000, minimum_increment: 100, bid_count: 0,
      start_time: Timestamp.fromMillis(now - 1000), end_time: Timestamp.fromMillis(now + endInMs), image_urls: [],
    },
  });
}
const ctx = (uid) => ({ auth: { uid, token: { email_verified: true } } });
const bid = (uid, max) => fns.placeBid.run({ lotId: "R1", max_amount: max }, ctx(uid));
const setRes = (amount, uid = "vendedor") => reserve.setReservePriceImpl({ lotId: "R1", amount }, uid);
async function rejectsWith(p, code) {
  await assert.rejects(p, (e) => e.details && e.details.code === code);
}

test("applyReserve: sube a la reserva solo si el máximo la alcanza; nunca rebasa el máximo", () => {
  const base = { ok: true, outcome: "first", newCurrentBid: 1000, newLeaderMax: 6000, bidderEffective: 1000, publicEvent: true };
  assert.strictEqual(applyReserve(base, 5000).newCurrentBid, 5000);
  assert.strictEqual(applyReserve(base, 5000).bidderEffective, 5000);
  assert.strictEqual(applyReserve(base, 7000).newCurrentBid, 1000);
  assert.strictEqual(applyReserve(base, 7000).reserveMet, false);
  const raised = { ...base, outcome: "max_raised", publicEvent: false };
  assert.strictEqual(applyReserve(raised, 5000).publicEvent, true, "subir el máximo y cruzar la reserva sí es público");
  const outbid = { ...base, outcome: "outbid", previousLeaderEffective: 2000, newCurrentBid: 2000 };
  assert.strictEqual(applyReserve(outbid, 5000).previousLeaderEffective, 5000);
  assert.strictEqual(applyReserve(base, 0).reserveMet, true);
});

test("la reserva es secreta: el lote solo dice si tiene y si se alcanzó", async () => {
  seed();
  await setRes(5000);
  const lot = get("lots/R1");
  assert.strictEqual(lot.has_reserve, true);
  assert.strictEqual(lot.reserve_met, false);
  assert.ok(!JSON.stringify(lot).includes("5000"), "el monto no aparece en el lote");
  assert.strictEqual(get("lots/R1/private/reserve").amount, 5000);
  const r = await bid("ana", 3000);
  assert.match(r.message, /reserva/);
  assert.strictEqual(r.reserve_met, false);
  assert.ok(!children("lots/R1/history").some((h) => h.amount === 5000));
});

test("al alcanzar la reserva el precio sube a la reserva; luego la puja proxy sigue normal", async () => {
  seed();
  await setRes(5000);
  await bid("ana", 3000);
  assert.strictEqual(get("lots/R1").current_bid, 1000);
  await bid("beto", 8000);
  let lot = get("lots/R1");
  assert.strictEqual(lot.current_bid, 5000, "salta a la reserva (no a 3,100)");
  assert.strictEqual(lot.reserve_met, true);
  assert.strictEqual(lot.highest_bidder_uid, "beto");
  await bid("ana", 6000);
  lot = get("lots/R1");
  assert.strictEqual(lot.current_bid, 6100);
  assert.strictEqual(lot.highest_bidder_uid, "beto");
});

test("el líder sube su máximo por encima de la reserva: el precio salta a la reserva", async () => {
  seed();
  await setRes(5000);
  await bid("ana", 3000);
  await bid("ana", 9000);
  const lot = get("lots/R1");
  assert.strictEqual(lot.current_bid, 5000);
  assert.strictEqual(lot.reserve_met, true);
});

test("cierre con reserva no alcanzada: sin ganador, sin cobro, avisos a vendedor y líder", async () => {
  seed({ endInMs: -1000 });
  S.get("lots/R1").data.end_time = Timestamp.fromMillis(Date.now() + 3600_000);
  await setRes(5000);
  await bid("ana", 3000);
  S.get("lots/R1").data.end_time = Timestamp.fromMillis(Date.now() - 1000);
  await fns.closeEndedAuctions.run({});
  const lot = get("lots/R1");
  assert.strictEqual(lot.status, "ended_unsold_reserve");
  assert.strictEqual(lot.winner_uid, null);
  assert.strictEqual(lot.payment_status, "none");
  assert.strictEqual(mp.__calls.preferences.length, 0, "no se genera cobro");
  assert.ok(children("users/vendedor/notifications").some((n) => n.type === "unsold_reserve"));
  assert.ok(children("users/ana/notifications").some((n) => n.type === "reserve_not_met"));
  assert.strictEqual(get("users/ana").deposit.status, "held", "el depósito sigue disponible");
});

test("cierre con reserva alcanzada: venta normal", async () => {
  seed();
  await setRes(5000);
  await bid("ana", 6000);
  S.get("lots/R1").data.end_time = Timestamp.fromMillis(Date.now() - 1000);
  await fns.closeEndedAuctions.run({});
  const lot = get("lots/R1");
  assert.strictEqual(lot.status, "ended");
  assert.strictEqual(lot.winner_uid, "ana");
  assert.strictEqual(lot.final_price, 5000);
  assert.strictEqual(lot.payment_status, "pending");
});

test("reglas de la reserva: solo el vendedor, > precio inicial, nunca en vivo, con pujas solo bajar", async () => {
  seed();
  await rejectsWith(setRes(5000, "ana"), "NOT_SELLER");
  await rejectsWith(setRes(900), "INVALID_ARGUMENT");
  await rejectsWith(setRes(-5), "INVALID_ARGUMENT");
  await rejectsWith(setRes(1e12), "INVALID_ARGUMENT");
  await setRes(5000);
  await bid("ana", 2000);
  await rejectsWith(setRes(7000), "ONLY_LOWER");
  const low = await setRes(1500);
  assert.strictEqual(low.reserveMet, true, "al bajarla por debajo del máximo del líder, ya se alcanzó");
  assert.strictEqual(get("lots/R1").current_bid, 1500, "y el precio sube a la nueva reserva");
  assert.ok(children("lots/R1/history").some((h) => h.amount === 1500 && h.auto === true));
  const off = await setRes(null);
  assert.strictEqual(off.hasReserve, false);
  await rejectsWith(setRes(3000), "ONLY_LOWER");
  seed({ format: "live" });
  await rejectsWith(setRes(5000), "LIVE_NOT_ALLOWED");
});
