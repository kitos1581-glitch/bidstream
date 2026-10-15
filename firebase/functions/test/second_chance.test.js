/**
 * Segunda oportunidad: subcampeón correcto, una sola oferta, aceptar,
 * rechazar, vencer y abusos.
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
const sc = require(path.join(__dirname, "..", "second_chance.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });
const children = (prefix) =>
  [...S.keys()]
    .filter((p) => p.startsWith(prefix + "/") && !p.slice(prefix.length + 1).includes("/"))
    .map((p) => ({ id: p.split("/").pop(), ...S.get(p).data }));
const lotRef = () => fake.firestore().collection("lots").doc("C1");
const ts = (ms) => Timestamp.fromMillis(ms);

/** Ana ganó (no pagó); Beto y Caro pujaron; el vendedor también "pujó" (abuso). */
async function forfeitedLot() {
  fake.__reset();
  mp.__reset();
  put("users/vendedor", { full_name: "Vero Vendedora" });
  put("users/ana", { full_name: "Ana Pérez", deposit: { status: "held", amount: 200, mp_payment_id: "D1" } });
  put("users/beto", { full_name: "Beto Ruiz", deposit: { status: "held", amount: 200, mp_payment_id: "D2" } });
  put("users/caro", { full_name: "Caro Díaz" });
  put("lots/C1", { title: "Caballo", status: "ended", seller_uid: "vendedor", winner_uid: "ana", starting_price: 30000, current_bid: 52000 });
  const t = Date.now() - 100_000;
  put("lots/C1/bids/b1", { user_id: "ana", max_amount: 60000, timestamp: ts(t + 5) });
  put("lots/C1/bids/b2", { user_id: "beto", max_amount: 45000, timestamp: ts(t + 1) });
  put("lots/C1/bids/b3", { user_id: "beto", max_amount: 50000, timestamp: ts(t + 3) });
  put("lots/C1/bids/b4", { user_id: "caro", max_amount: 50000, timestamp: ts(t + 4) });
  put("lots/C1/bids/b5", { user_id: "vendedor", max_amount: 59000, timestamp: ts(t + 2) });
  await pay.startWinnerPayment(lotRef(), get("lots/C1"), "ana");
  S.get("lots/C1").data.payment_due_time = ts(Date.now() - 1000);
  assert.strictEqual(await pay.forfeitWin(lotRef()), true);
}
const respond = (uid, accept, now) => sc.respondImpl({ lotId: "C1", accept }, uid, accept, now);
async function rejectsWith(p, code) {
  await assert.rejects(p, (e) => e.details && e.details.code === code);
}

test("subcampeón: máximo más alto de otro postor; empate → quien llegó primero; nunca vendedor ni moroso", () => {
  const bids = [
    { user_id: "ana", max_amount: 60000, timestamp: 5 },
    { user_id: "beto", max_amount: 50000, timestamp: 3 },
    { user_id: "caro", max_amount: 50000, timestamp: 4 },
    { user_id: "vendedor", max_amount: 59000, timestamp: 2 },
  ];
  assert.deepStrictEqual(sc.pickRunnerUp(bids, ["vendedor", "ana"]), { uid: "beto", amount: 50000 });
  assert.strictEqual(sc.pickRunnerUp([{ user_id: "ana", max_amount: 1 }], ["ana"]), null);
});

test("al incumplir el ganador: se ofrece al subcampeón por su máximo, una sola vez", async () => {
  await forfeitedLot();
  const o = await sc.offerSecondChance(lotRef());
  assert.deepStrictEqual(o, { uid: "beto", amount: 50000 });
  const offer = get("lots/C1").second_chance;
  assert.strictEqual(offer.status, "offered");
  assert.strictEqual(offer.name, "Beto R.");
  assert.ok(children("users/beto/notifications").some((n) => n.type === "second_chance"));
  assert.strictEqual(await sc.offerSecondChance(lotRef()), null, "no hay segunda oferta");
  // El vendedor conserva el depósito del moroso.
  assert.strictEqual(get("payments/payout-forfeit-C1").amount, 200);
});

test("aceptar: pasa a ser ganador y se genera su cobro (depósito aplicado)", async () => {
  await forfeitedLot();
  await sc.offerSecondChance(lotRef());
  const r = await respond("beto", true);
  assert.strictEqual(r.accepted, true);
  assert.strictEqual(r.amountDue, 49800);
  const lot = get("lots/C1");
  assert.strictEqual(lot.winner_uid, "beto");
  assert.strictEqual(lot.current_bid, 50000);
  assert.strictEqual(lot.payment_status, "pending");
  assert.deepStrictEqual(lot.forfeited_uids, ["ana"]);
  assert.strictEqual(lot.second_chance.status, "accepted");
  // El moroso ya no puede pagar este lote: su pago tardío se devuelve.
  const late = await pay.applyApprovedPayment({ id: "LATE", status: "approved", external_reference: "win:C1:ana", transaction_amount: 51800, currency_id: "MXN" });
  assert.strictEqual(late.action, "refund");
  // Beto paga y se liquida una vez.
  await pay.applyApprovedPayment({ id: "B1", status: "approved", external_reference: "win:C1:beto", transaction_amount: 49800, currency_id: "MXN" });
  assert.strictEqual(get("lots/C1").payment_status, "paid");
});

test("rechazar o dejar vencer no castiga; abusos rechazados", async () => {
  await forfeitedLot();
  await sc.offerSecondChance(lotRef());
  await rejectsWith(respond("caro", true), "NOT_YOUR_OFFER");
  await rejectsWith(respond("ana", true), "NOT_YOUR_OFFER");
  await rejectsWith(respond(null, true), "UNAUTHENTICATED");
  await rejectsWith(respond("beto", true, Date.now() + sc.OFFER_WINDOW_MS + 1), "OFFER_EXPIRED");
  const r = await respond("beto", false);
  assert.strictEqual(r.accepted, false);
  assert.strictEqual(get("lots/C1").second_chance.status, "declined");
  assert.strictEqual(get("users/beto").strikes, undefined, "rechazar no da strike");
  await rejectsWith(respond("beto", true), "NO_OFFER");
});

test("oferta vencida: se cierra y se avisa al vendedor", async () => {
  await forfeitedLot();
  await sc.offerSecondChance(lotRef());
  assert.strictEqual(await sc.expireSecondChances(Date.now() + sc.OFFER_WINDOW_MS + 1), 1);
  assert.strictEqual(get("lots/C1").second_chance.status, "expired");
  assert.ok(children("users/vendedor/notifications").some((n) => n.type === "second_chance_expired"));
});

test("subcampeón suspendido o por debajo del precio inicial: no hay oferta", async () => {
  await forfeitedLot();
  S.get("users/beto").data.banned = true;
  S.get("users/caro").data.banned = true;
  assert.strictEqual(await sc.offerSecondChance(lotRef()), null);
  await forfeitedLot();
  S.get("lots/C1").data.starting_price = 55000;
  assert.strictEqual(await sc.offerSecondChance(lotRef()), null);
});

test("dos aceptaciones simultáneas: un solo cambio de ganador y un solo cobro", async () => {
  await forfeitedLot();
  await sc.offerSecondChance(lotRef());
  const rs = await Promise.allSettled([respond("beto", true), respond("beto", true)]);
  assert.strictEqual(rs.filter((r) => r.status === "fulfilled").length, 1);
  assert.strictEqual(mp.__calls.preferences.filter((p) => String(p.external_reference).includes("beto")).length, 1);
});

test("la segunda oportunidad nunca baja de la reserva del vendedor", async () => {
  await forfeitedLot();
  put("lots/C1/private/reserve", { amount: 55000 });
  assert.strictEqual(await sc.offerSecondChance(lotRef()), null);
});
