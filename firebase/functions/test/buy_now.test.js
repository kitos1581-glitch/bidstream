/**
 * Comprar ahora / precio fijo (R-10).
 * Precio fijo = "aparta y paga" (sin depósito ni INE; si no paga, vuelve a
 * la venta). Subasta con Comprar ahora = mismas reglas que pujar.
 * Casos felices, abuso (vendedor, con pujas, vencido, en vivo),
 * concurrencia (dos compran a la vez → solo uno) y que el cobro/escrow sea el
 * mismo de una subasta ganada.
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
process.env.APP_CHECK_MODE = "off";

const fns = require(path.join(__dirname, "..", "index.js"));
const pay = require(path.join(__dirname, "..", "payments.js"));
const reserve = require(path.join(__dirname, "..", "reserve.js"));
const { buyNowError, saleType } = require(path.join(__dirname, "..", "auction_logic.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const children = (prefix) =>
  [...S.keys()]
    .filter((p) => p.startsWith(prefix + "/") && !p.slice(prefix.length + 1).includes("/"))
    .map((p) => ({ id: p.split("/").pop(), ...S.get(p).data }));

function user(uid, extra = {}) {
  S.set(`users/${uid}`, {
    version: 1,
    data: {
      full_name: `${uid} Pérez`,
      phone: "614",
      accepted_terms: true,
      email: `${uid}@x.mx`,
      deposit: { status: "held", amount: 200, mp_payment_id: `D_${uid}` },
      ...extra,
    },
  });
}

function seed(lotExtra = {}) {
  fake.__reset();
  mp.__reset();
  const now = Date.now();
  user("ana");
  user("beto");
  user("vendedor");
  S.set("lots/F1", {
    version: 1,
    data: {
      title: "Silla de montar",
      status: "active",
      format: "timed",
      sale_type: "fixed",
      seller_uid: "vendedor",
      starting_price: 3000,
      current_bid: 3000,
      buy_now_price: 3000,
      minimum_increment: 1,
      bid_count: 0,
      start_time: Timestamp.fromMillis(now - 1000),
      end_time: Timestamp.fromMillis(now + 7 * 86400_000),
      image_urls: [],
      delivery: { pickup: true, regional: false },
      ...lotExtra,
    },
  });
}
const ctx = (uid, verified = true) => ({ auth: { uid, token: { email_verified: verified } } });
const buy = (uid, lotId = "F1") => fns.buyNow.run({ lotId }, ctx(uid));
async function rejectsWith(p, code) {
  await assert.rejects(p, (e) => e.details && e.details.code === code);
}

test("buyNowError: precio fijo, subasta sin pujas, y todos los rechazos", () => {
  const now = 1_000_000;
  const base = { status: "active", seller_uid: "v", start_time_ms: now - 1, end_time_ms: now + 1000 };
  assert.deepStrictEqual(buyNowError({ ...base, sale_type: "fixed", buy_now_price: 3000 }, "a", now), { price: 3000 });
  assert.deepStrictEqual(buyNowError({ ...base, buy_now_price: 5000, bid_count: 0 }, "a", now), { price: 5000 });
  assert.strictEqual(buyNowError({ ...base, buy_now_price: 5000, bid_count: 1 }, "a", now).reason, "HAS_BIDS");
  assert.strictEqual(buyNowError({ ...base, buy_now_price: 5000, format: "live" }, "a", now).reason, "LIVE");
  assert.strictEqual(buyNowError({ ...base, sale_type: "fixed", buy_now_price: 3000 }, "v", now).reason, "OWN_LOT");
  assert.strictEqual(buyNowError({ ...base, sale_type: "fixed", buy_now_price: 3000, status: "ended" }, "a", now).reason, "NOT_ACTIVE");
  assert.strictEqual(buyNowError({ ...base, sale_type: "fixed", buy_now_price: 3000 }, "a", now + 1000).reason, "ENDED");
  assert.strictEqual(buyNowError({ ...base, sale_type: "fixed", buy_now_price: 3000 }, "a", now - 5).reason, "NOT_STARTED");
  assert.strictEqual(buyNowError({ ...base }, "a", now).reason, "NO_BUY_NOW");
  assert.strictEqual(buyNowError({ ...base, buy_now_price: -1 }, "a", now).reason, "NO_BUY_NOW");
  assert.strictEqual(saleType({}), "auction");
  assert.strictEqual(saleType({ sale_type: "fixed" }), "fixed");
});

test("precio fijo (aparta y paga): sin depósito ni INE; se aparta y genera el cobro completo", async () => {
  seed();
  const r = await buy("ana");
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.payFirst, true);
  assert.strictEqual(r.price, 3000);
  assert.strictEqual(r.amount, 3000, "paga el precio completo; el depósito no se usa");
  const lot = get("lots/F1");
  assert.strictEqual(lot.status, "ended");
  assert.strictEqual(lot.pay_first, true);
  assert.strictEqual(lot.winner_uid, "ana");
  assert.strictEqual(lot.payment_status, "pending");
  assert.deepStrictEqual(lot.payment_options, ["mercadopago"], "solo pago inmediato");
  const mins = (lot.payment_due_time.toMillis() - Date.now()) / 60000;
  assert.ok(mins > 25 && mins <= 30, `apartado de 30 min (${mins})`);
  assert.ok(lot.winner_payment_url, "hay enlace de pago");
  assert.strictEqual(get("users/ana").deposit.status, "held", "el depósito no se toca");
  const pref = mp.__calls.preferences.at(-1);
  assert.match(String(pref.items ? pref.items[0].title : JSON.stringify(pref)), /Pago de compra/);
  assert.ok(children("users/ana/notifications").some((n) => /Apartado/.test(n.title)));
  assert.ok(!children("users/vendedor/notifications").some((n) => n.type === "sold"), "al vendedor se le avisa al cobrar");
  // Pago aprobado → vendido y liquidado.
  await pay.applyApprovedPayment({ id: "PF1", status: "approved", external_reference: "win:F1:ana", transaction_amount: 3000, currency_id: "MXN" });
  assert.strictEqual(get("lots/F1").payment_status, "paid");
  assert.ok(get("payments/payout-F1"));
});

test("aparta y paga: quien no tiene depósito ni INE puede comprar, aunque sea caro", async () => {
  seed({ starting_price: 25000, current_bid: 25000, buy_now_price: 25000 });
  user("caro", { deposit: null });
  const r = await buy("caro");
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.amount, 25000);
});

test("aparta y paga: mientras otro paga, se ve como apartado", async () => {
  seed();
  await buy("ana");
  await rejectsWith(buy("beto"), "HELD");
});

test("aparta y paga vencido: vuelve a la venta sin castigo; otro lo puede comprar; el pago tardío se devuelve", async () => {
  seed();
  const endBefore = get("lots/F1").end_time.toMillis();
  await buy("ana");
  S.get("lots/F1").data.payment_due_time = Timestamp.fromMillis(Date.now() - 1000);
  const lotRef = fake.firestore().collection("lots").doc("F1");
  assert.strictEqual(await pay.forfeitWin(lotRef), true);
  const lot = get("lots/F1");
  assert.strictEqual(lot.status, "active");
  assert.strictEqual(lot.end_time.toMillis(), endBefore, "conserva su fecha de fin");
  assert.strictEqual(lot.winner_uid, null);
  assert.strictEqual(lot.payment_status, undefined);
  assert.strictEqual(lot.amount_due, undefined);
  const ana = get("users/ana");
  assert.strictEqual(ana.unpaid_buys, 1);
  assert.ok(!ana.strikes, "sin strike");
  assert.strictEqual(ana.deposit.status, "held", "sin perder depósito");
  assert.ok(children("users/ana/notifications").some((n) => n.type === "hold_expired"));
  // Beto lo compra; el pago tardío de Ana se rechaza para devolverse.
  const r = await buy("beto");
  assert.strictEqual(r.ok, true);
  const late = await pay.applyApprovedPayment({ id: "LATE", status: "approved", external_reference: "win:F1:ana", transaction_amount: 3000, currency_id: "MXN" });
  assert.strictEqual(late.action, "refund");
  assert.strictEqual(get("lots/F1").winner_uid, "beto");
});

test("aparta y paga: si la publicación ya había vencido, termina sin venta", async () => {
  seed({ end_time: Timestamp.fromMillis(Date.now() + 60_000) });
  await buy("ana");
  S.get("lots/F1").data.payment_due_time = Timestamp.fromMillis(Date.now() - 1000);
  S.get("lots/F1").data.listing_end_time = Timestamp.fromMillis(Date.now() - 1);
  await pay.forfeitWin(fake.firestore().collection("lots").doc("F1"));
  assert.strictEqual(get("lots/F1").status, "ended");
  assert.ok(children("users/vendedor/notifications").some((n) => n.type === "unsold"));
});

test("quien deja vencer 3 apartados necesita depósito para volver a apartar", async () => {
  seed();
  user("caro", { deposit: null, unpaid_buys: 3 });
  await rejectsWith(buy("caro"), "DEPOSIT_REQUIRED");
  user("dani", { unpaid_buys: 3 });
  const r = await buy("dani");
  assert.strictEqual(r.payFirst, false, "con depósito: regla normal");
  assert.strictEqual(r.amount, 2800);
});

test("dos compradores al mismo tiempo: solo uno se lo lleva y solo se genera UN cobro", async () => {
  seed();
  const results = await Promise.allSettled([buy("ana"), buy("beto")]);
  const ok = results.filter((x) => x.status === "fulfilled");
  const bad = results.filter((x) => x.status === "rejected");
  assert.strictEqual(ok.length, 1);
  assert.strictEqual(bad.length, 1);
  assert.strictEqual(bad[0].reason.details.code, "NOT_ACTIVE");
  assert.strictEqual(mp.__calls.preferences.length, 1);
  const winner = get("lots/F1").winner_uid;
  const loser = winner === "ana" ? "beto" : "ana";
  assert.strictEqual(get(`users/${loser}`).deposit.status, "held", "al que no compró no se le toca el depósito");
});

test("abuso: el vendedor no puede comprar lo suyo; sin correo verificado, perfil o términos no se compra", async () => {
  seed();
  await rejectsWith(buy("vendedor"), "OWN_LOT");
  await assert.rejects(fns.buyNow.run({ lotId: "F1" }, ctx("ana", false)), /Verifica tu correo/);
  await assert.rejects(fns.buyNow.run({ lotId: "F1" }, { auth: null }), /Inicia sesión/);
  await assert.rejects(fns.buyNow.run({ lotId: "a/b" }, ctx("ana")), /Falta el artículo/);
  user("sinperfil", { phone: "" });
  await assert.rejects(buy("sinperfil"), /nombre y teléfono/);
  user("sinterminos", { accepted_terms: false });
  await assert.rejects(buy("sinterminos"), /términos/);
  user("susp", { banned: true });
  await assert.rejects(buy("susp"), /suspendida/);
  assert.strictEqual(get("lots/F1").status, "active", "nada cambió");
  assert.strictEqual(mp.__calls.preferences.length, 0);
});

test("subasta con Comprar ahora: sigue pidiendo depósito e INE en montos altos (como pujar)", async () => {
  seed({ sale_type: "auction", starting_price: 21000, current_bid: 21000, buy_now_price: 25000, minimum_increment: 100 });
  await rejectsWith(buy("ana"), "IDENTITY_REQUIRED");
  user("caro", { deposit: null, verified: true });
  await rejectsWith(buy("caro"), "DEPOSIT_REQUIRED");
  user("ana", { verified: true });
  const r = await buy("ana");
  assert.strictEqual(r.ok, true);
  assert.strictEqual(r.payFirst, false);
});

test("en precio fijo no se puede pujar", async () => {
  seed();
  await rejectsWith(fns.placeBid.run({ lotId: "F1", max_amount: 5000 }, ctx("ana")), "FIXED_PRICE");
  assert.strictEqual(get("lots/F1").bid_count, 0);
});

test("subasta con Comprar ahora: disponible sin pujas; al primer puja desaparece", async () => {
  seed({ sale_type: "auction", starting_price: 1000, current_bid: 1000, buy_now_price: 5000, minimum_increment: 100 });
  await fns.placeBid.run({ lotId: "F1", max_amount: 1500 }, ctx("beto"));
  await rejectsWith(buy("ana"), "HAS_BIDS");
  seed({ sale_type: "auction", starting_price: 1000, current_bid: 1000, buy_now_price: 5000, minimum_increment: 100 });
  const r = await buy("ana");
  assert.strictEqual(r.price, 5000);
  assert.strictEqual(get("lots/F1").final_price, 5000);
});

test("vencida o ya vendida: no se compra; el cierre sin compradores avisa 'Sin venta'", async () => {
  seed({ end_time: Timestamp.fromMillis(Date.now() - 1000) });
  await rejectsWith(buy("ana"), "ENDED");
  await fns.closeEndedAuctions.run({});
  assert.strictEqual(get("lots/F1").status, "ended");
  assert.strictEqual(get("lots/F1").winner_uid, null);
  assert.ok(children("users/vendedor/notifications").some((n) => n.type === "unsold" && /Sin venta/.test(n.title)));
});

test("subasta con Comprar ahora sin pagar: castigo normal y SIN segunda oportunidad (no hubo pujas)", async () => {
  seed({ sale_type: "auction", starting_price: 1000, current_bid: 1000, buy_now_price: 5000, minimum_increment: 100 });
  await buy("ana");
  S.get("lots/F1").data.payment_due_time = Timestamp.fromMillis(Date.now() - 1000);
  const lotRef = fake.firestore().collection("lots").doc("F1");
  assert.strictEqual(await pay.forfeitWin(lotRef), true);
  assert.strictEqual(get("users/ana").deposit.status, "forfeited");
  const lot = get("lots/F1");
  assert.ok(!lot.second_chance || lot.second_chance.status !== "offered", "no se ofrece a nadie");
});

test("reserva: no en precio fijo; en subasta debe quedar debajo del Comprar ahora", async () => {
  seed();
  await rejectsWith(reserve.setReservePriceImpl({ lotId: "F1", amount: 5000 }, "vendedor"), "FIXED_NOT_ALLOWED");
  seed({ sale_type: "auction", starting_price: 1000, current_bid: 1000, buy_now_price: 5000 });
  await rejectsWith(reserve.setReservePriceImpl({ lotId: "F1", amount: 5000 }, "vendedor"), "ABOVE_BUY_NOW");
  const ok = await reserve.setReservePriceImpl({ lotId: "F1", amount: 4000 }, "vendedor");
  assert.strictEqual(ok.hasReserve, true);
});
