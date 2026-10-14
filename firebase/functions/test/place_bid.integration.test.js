/**
 * Prueba de punta a punta de la Cloud Function placeBid (index.js) con un
 * Firestore falso en memoria: verifica campos guardados, privacidad del
 * máximo, anti-sniping y pujas simultáneas.
 */
const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

// Inyectar el firebase-admin falso ANTES de cargar index.js.
const fake = require("./helpers/fake_admin");
require.cache[require.resolve("firebase-admin")] = {
  id: "firebase-admin",
  filename: require.resolve("firebase-admin"),
  loaded: true,
  exports: fake,
};
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";
const fns = require(path.join(__dirname, "..", "index.js"));
const { Timestamp } = fake.firestore;

const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const children = (prefix) =>
  [...S.keys()]
    .filter((p) => p.startsWith(prefix + "/") && !p.slice(prefix.length + 1).includes("/"))
    .map((p) => ({ id: p.split("/").pop(), ...S.get(p).data }));

function seed({ endInMs = 3600_000 } = {}) {
  fake.__reset();
  const now = Date.now();
  for (const uid of ["ana", "beto", "caro", "vendedor"]) {
    S.set(`users/${uid}`, {
      version: 1,
      data: {
        full_name: `${uid[0].toUpperCase()}${uid.slice(1)} Pérez`,
        phone: "6141234567",
        accepted_terms: true,
        deposit: { status: "held", amount: 200 },
      },
    });
  }
  S.set("lots/L1", {
    version: 1,
    data: {
      title: "Bicicleta",
      status: "active",
      seller_uid: "vendedor",
      starting_price: 1000,
      current_bid: 1000,
      minimum_increment: 100,
      bid_count: 0,
      start_time: Timestamp.fromMillis(now - 1000),
      end_time: Timestamp.fromMillis(now + endInMs),
      image_urls: [],
    },
  });
}

const ctx = (uid) => ({ auth: { uid, token: { email_verified: true } } });
const bid = (uid, max) => fns.placeBid.run({ lotId: "L1", max_amount: max }, ctx(uid));

test("guarda la oferta con los campos pedidos y oculta el máximo", async () => {
  seed();
  const r = await bid("ana", 5000);
  assert.strictEqual(r.outcome, "first");
  assert.strictEqual(r.current_bid, 1000);

  const bids = children("lots/L1/bids");
  assert.strictEqual(bids.length, 1);
  assert.deepStrictEqual(Object.keys(bids[0]).sort(), [
    "current_effective_bid", "id", "max_amount", "timestamp", "user_id",
  ]);
  assert.strictEqual(bids[0].user_id, "ana");
  assert.strictEqual(bids[0].max_amount, 5000);
  assert.strictEqual(bids[0].current_effective_bid, 1000);

  // El lote (público) NO contiene el máximo secreto.
  const lot = get("lots/L1");
  assert.ok(!JSON.stringify(lot).includes("5000"));
  assert.strictEqual(lot.highest_bidder_uid, "ana");
  // El historial público tampoco.
  assert.ok(!JSON.stringify(children("lots/L1/history")).includes("5000"));
  // El estado privado sí.
  assert.strictEqual(get("lots/L1/private/proxy_state").leader_max, 5000);
});

test("el proxy responde y actualiza la puja efectiva del líder", async () => {
  seed();
  await bid("ana", 5000);
  const r = await bid("beto", 2000);
  assert.strictEqual(r.outcome, "outbid");
  assert.strictEqual(r.leading, false);
  assert.strictEqual(r.current_bid, 2100);

  const lot = get("lots/L1");
  assert.strictEqual(lot.current_bid, 2100);
  assert.strictEqual(lot.highest_bidder_uid, "ana");
  assert.strictEqual(lot.bid_count, 3); // 1 de Ana + Beto + respuesta automática

  const bids = children("lots/L1/bids");
  const ana = bids.find((b) => b.user_id === "ana");
  const beto = bids.find((b) => b.user_id === "beto");
  assert.strictEqual(ana.current_effective_bid, 2100);
  assert.strictEqual(beto.current_effective_bid, 2000);

  const hist = children("lots/L1/history");
  assert.ok(hist.some((h) => h.auto === true && h.amount === 2100 && h.bidder_uid === "ana"));
});

test("cambio de líder: avisa al anterior", async () => {
  seed();
  await bid("ana", 5000);
  const r = await bid("beto", 9000);
  assert.strictEqual(r.outcome, "leading");
  assert.strictEqual(r.current_bid, 5100);
  assert.strictEqual(get("lots/L1").highest_bidder_uid, "beto");
  const notes = children("users/ana/notifications");
  assert.strictEqual(notes.length, 1);
  assert.strictEqual(notes[0].type, "outbid");
  assert.ok(!notes[0].body.includes("9000") && !notes[0].body.includes("9,000"));
});

test("rechaza ofertas menores a puja actual + incremento", async () => {
  seed();
  await bid("ana", 5000);
  await bid("beto", 2000); // precio 2100
  await assert.rejects(bid("caro", 2150), (e) => {
    assert.strictEqual(e.code, "failed-precondition");
    assert.strictEqual(e.details.minimum, 2200);
    return true;
  });
});

test("anti-sniping: oferta a 10 s del cierre lo mueve a ahora + 30 s", async () => {
  seed({ endInMs: 10_000 });
  const before = Date.now();
  const r = await bid("ana", 1500);
  const after = Date.now();
  assert.strictEqual(r.extended, true);
  const end = get("lots/L1").end_time.toMillis();
  assert.ok(end >= before + 30_000 && end <= after + 30_000, `end=${end - before}`);
});

test("anti-sniping: con más de 30 s no se toca el cierre", async () => {
  seed({ endInMs: 120_000 });
  const endBefore = get("lots/L1").end_time.toMillis();
  const r = await bid("ana", 1500);
  assert.strictEqual(r.extended, false);
  assert.strictEqual(get("lots/L1").end_time.toMillis(), endBefore);
});

test("pujas simultáneas: la transacción se reintenta y el resultado es consistente", async () => {
  seed();
  const results = await Promise.allSettled([
    bid("ana", 3000),
    bid("beto", 4000),
    bid("caro", 3500),
  ]);
  assert.ok(fake.__db.retries > 0, "debió haber reintentos por conflicto");
  assert.ok(results.every((x) => x.status === "fulfilled"));

  // Sin importar el orden de llegada: Beto (máx 4000) gana a 3600
  // (segundo máximo 3500 + 100).
  const lot = get("lots/L1");
  assert.strictEqual(lot.highest_bidder_uid, "beto");
  assert.strictEqual(lot.current_bid, 3600);
  assert.strictEqual(children("lots/L1/bids").length, 3);
});

test("sin depósito de garantía no se puja", async () => {
  seed();
  S.get("users/ana").data.deposit = { status: "refunded" };
  await assert.rejects(bid("ana", 2000), (e) => e.code === "failed-precondition");
});
