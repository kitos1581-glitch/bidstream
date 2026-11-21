/**
 * Venta privada con enlace: solo con el token, comprador con INE, tope y límite por pareja.
 * Precio fijo = "aparta y paga" (sin depósito ni INE; si no paga, vuelve a
 * la venta). "Comprar ahora" de una subasta sin pujas = misma compra directa.
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
const buyK = (uid, k, lotId = "F1") => fns.buyNow.run({ lotId, k }, ctx(uid));
const priv = require(path.join(__dirname, "..", "private_sale.js"));
async function rejectsWith(p, code) {
  await assert.rejects(p, (e) => e.details && e.details.code === code);
}
function seedPrivate(extra = {}) {
  seed({ private_sale: true, ...extra });
  S.set("users/ana", { version: 1, data: { ...get("users/ana"), verified: true } });
  S.set("users/beto", { version: 1, data: { ...get("users/beto"), verified: true } });
}
const tokenOf = (link) => new URL(link).searchParams.get("k");

test("el vendedor obtiene un enlace estable; nadie más puede pedirlo", async () => {
  seedPrivate();
  const a = await priv.getPrivateSaleLinkImpl({ lotId: "F1" }, "vendedor");
  assert.match(a.link, /lotDetailView\?lotId=F1&k=/);
  const b = await priv.getPrivateSaleLinkImpl({ lotId: "F1" }, "vendedor");
  assert.strictEqual(a.link, b.link, "mismo enlace al volver a pedirlo");
  await assert.rejects(priv.getPrivateSaleLinkImpl({ lotId: "F1" }, "ana"), /Solo el vendedor/);
  seed();
  await assert.rejects(priv.getPrivateSaleLinkImpl({ lotId: "F1" }, "vendedor"), /no es venta privada/);
});

test("sin enlace o con enlace equivocado no se puede comprar; con el enlace sí", async () => {
  seedPrivate();
  const k = tokenOf((await priv.getPrivateSaleLinkImpl({ lotId: "F1" }, "vendedor")).link);
  await rejectsWith(buyK("ana", undefined), "PRIVATE_LINK");
  await rejectsWith(buyK("ana", "otro-token-123"), "PRIVATE_LINK");
  assert.strictEqual(get("lots/F1").status, "active", "sigue a la venta");
  const r = await buyK("ana", k);
  assert.strictEqual(r.ok, true);
  assert.strictEqual(get("lots/F1").winner_uid, "ana");
  assert.strictEqual(get("private_pairs/vendedor_ana").times.length, 1);
});

test("comprador sin INE, arriba del tope o pareja repetida: rechazado", async () => {
  seedPrivate();
  S.set("users/ana", { version: 1, data: { ...get("users/ana"), verified: false } });
  let k = tokenOf((await priv.getPrivateSaleLinkImpl({ lotId: "F1" }, "vendedor")).link);
  await rejectsWith(buyK("ana", k), "PRIVATE_NEEDS_ID");

  seedPrivate({ starting_price: 35000, current_bid: 35000, buy_now_price: 35000 });
  k = tokenOf((await priv.getPrivateSaleLinkImpl({ lotId: "F1" }, "vendedor")).link);
  await rejectsWith(buyK("ana", k), "PRIVATE_MAX");

  seedPrivate();
  k = tokenOf((await priv.getPrivateSaleLinkImpl({ lotId: "F1" }, "vendedor")).link);
  const now = Date.now();
  S.set("private_pairs/vendedor_ana", { version: 1, data: { times: [now - 86400000, now - 2 * 86400000] } });
  await rejectsWith(buyK("ana", k), "PRIVATE_PAIR_LIMIT");
  // Otra persona (con INE) sí puede, y compras viejas (>30 días) no cuentan.
  S.set("private_pairs/vendedor_beto", { version: 1, data: { times: [now - 40 * 86400000, now - 50 * 86400000] } });
  assert.strictEqual((await buyK("beto", k)).ok, true);
});

test("ventas normales no cambian: sin private_sale no pide enlace ni INE", async () => {
  seed();
  assert.strictEqual((await buyK("ana", undefined)).ok, true);
});

test("sameToken: compara en tiempo constante y rechaza vacíos", () => {
  assert.ok(priv.sameToken("abc", "abc"));
  assert.ok(!priv.sameToken("abc", "abd"));
  assert.ok(!priv.sameToken("", ""));
  assert.ok(!priv.sameToken(undefined, "abc"));
});
