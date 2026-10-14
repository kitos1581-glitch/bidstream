/**
 * Concurrencia y fallos de placeBid (Firestore simulado con transacciones
 * optimistas y reintentos).
 */
const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const fake = require("./helpers/fake_admin");
const r = require.resolve("firebase-admin");
require.cache[r] = { id: r, filename: r, loaded: true, exports: fake };
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";
const fns = require(path.join(__dirname, "..", "index.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const db = fake.__db;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const children = (prefix) =>
  [...S.keys()]
    .filter((p) => p.startsWith(prefix + "/") && !p.slice(prefix.length + 1).includes("/"))
    .map((p) => ({ id: p.split("/").pop(), ...S.get(p).data }));

const USERS = ["u0", "u1", "u2", "u3", "u4", "u5", "u6", "u7", "u8", "u9"];
function seed() {
  fake.__reset();
  for (const uid of [...USERS, "vendedor"]) {
    S.set(`users/${uid}`, {
      version: 1,
      data: {
        full_name: `Usuario ${uid}`,
        phone: "6140000000",
        accepted_terms: true,
        deposit: { status: "held", amount: 200 },
      },
    });
  }
  S.set("lots/L1", {
    version: 1,
    data: {
      title: "Lote",
      status: "active",
      seller_uid: "vendedor",
      starting_price: 1000,
      current_bid: 1000,
      minimum_increment: 100,
      bid_count: 0,
      start_time: Timestamp.fromMillis(Date.now() - 1000),
      end_time: Timestamp.fromMillis(Date.now() + 3600_000),
    },
  });
}
const ctx = (uid) => ({ auth: { uid, token: { email_verified: true } } });
const bid = (uid, max) => fns.placeBid.run({ lotId: "L1", max_amount: max }, ctx(uid));

test("10 pujas simultáneas: gana el máximo más alto y paga segundo máximo + incremento", async () => {
  seed();
  const maxes = [2300, 5100, 1800, 4700, 3900, 2600, 4950, 1200, 3300, 2050];
  const res = await Promise.allSettled(USERS.map((u, i) => bid(u, maxes[i])));
  assert.ok(db.retries > 0, "debe haber conflictos y reintentos");
  // Ninguna se pierde: todas confirmadas o rechazadas con motivo.
  for (const x of res) {
    if (x.status === "rejected") assert.ok(x.reason.code, String(x.reason));
  }
  const lot = get("lots/L1");
  assert.strictEqual(lot.highest_bidder_uid, "u1"); // máximo 5100
  assert.strictEqual(lot.current_bid, 5050); // min(5100, 4950 + 100)
  // Coherencia: estado privado = líder del lote; conteo = historial.
  const st = get("lots/L1/private/proxy_state");
  assert.strictEqual(st.leader_uid, "u1");
  assert.strictEqual(st.leader_max, 5100);
  assert.strictEqual(lot.bid_count, children("lots/L1/history").length);
  // El historial nunca baja.
  const hist = children("lots/L1/history").sort(
    (a, b) => a.created_time.toMillis() - b.created_time.toMillis() || a.amount - b.amount
  );
  for (let i = 1; i < hist.length; i++) assert.ok(hist[i].amount >= hist[i - 1].amount);
});

test("doble toque del mismo usuario: una sola puja efectiva, sin inconsistencias", async () => {
  seed();
  const res = await Promise.allSettled([bid("u0", 3000), bid("u0", 3000)]);
  assert.strictEqual(res.filter((x) => x.status === "fulfilled").length, 1);
  assert.strictEqual(res.find((x) => x.status === "rejected").reason.code, "already-exists");
  assert.strictEqual(get("lots/L1").bid_count, 1);
  assert.strictEqual(children("lots/L1/bids").length, 1);
});

test("si lo suspenden entre la revisión rápida y la transacción, se rechaza", async () => {
  seed();
  db.beforeTx = async () => {
    S.get("users/u0").data.banned = true;
  };
  await assert.rejects(bid("u0", 3000), (e) => e.code === "permission-denied");
  assert.strictEqual(get("lots/L1").bid_count, 0);
});

test("si retira la aceptación de términos en medio, se rechaza", async () => {
  seed();
  db.beforeTx = async () => {
    S.get("users/u0").data.accepted_terms = false;
  };
  await assert.rejects(bid("u0", 3000), (e) => e.code === "failed-precondition");
  assert.strictEqual(children("lots/L1/bids").length, 0);
});

test("si le revocan la verificación de identidad en medio, una puja alta se rechaza", async () => {
  seed();
  S.get("users/u0").data.verified = true;
  db.beforeTx = async () => {
    S.get("users/u0").data.verified = false;
  };
  await assert.rejects(
    bid("u0", 25000),
    (e) => e.details && e.details.code === "IDENTITY_REQUIRED"
  );
});

test("si el perfil se borra en medio, se rechaza", async () => {
  seed();
  db.beforeTx = async () => {
    S.delete("users/u0");
  };
  await assert.rejects(bid("u0", 3000), (e) => e.code === "failed-precondition");
});

test("el aviso 'te superaron' se escribe en la misma transacción que la puja", async () => {
  seed();
  await bid("u0", 3000);
  await bid("u1", 5000); // supera a u0
  const notes = children("users/u0/notifications");
  assert.strictEqual(notes.length, 1);
  assert.strictEqual(notes[0].type, "outbid");
});

test("una falla al escribir el aviso no deja una puja confirmada reportada como rechazada", async () => {
  seed();
  await bid("u0", 3000);
  db.failWrites = /\/notifications\//;
  // El commit es atómico: si algo falla, NO hay puja; la respuesta (error)
  // corresponde con la realidad (sin puja), nunca "error" con puja guardada.
  await assert.rejects(bid("u1", 5000));
  const lot = get("lots/L1");
  assert.strictEqual(lot.highest_bidder_uid, "u0");
  assert.strictEqual(children("lots/L1/bids").length, 1);
  // Al reintentar sin la falla, la puja entra normalmente.
  db.failWrites = null;
  const r = await bid("u1", 5000);
  assert.strictEqual(r.leading, true);
});

test("falla del push no afecta nada (el trigger la absorbe)", async () => {
  fake.__reset();
  fake.messaging = () => ({
    sendEachForMulticast: async () => {
      throw new Error("FCM caído");
    },
  });
  S.set("users/u0/fcm_tokens/tok", { version: 1, data: { platform: "android" } });
  const push = require(path.join(__dirname, "..", "push.js"));
  await assert.doesNotReject(
    push.onNotificationCreated.run(
      { data: () => ({ type: "outbid", title: "x" }) },
      { params: { uid: "u0", notificationId: "n1" } }
    )
  );
});

test("lote con datos corruptos (incremento negativo) rechaza la puja sin tocar nada", async () => {
  seed();
  S.get("lots/L1").data.minimum_increment = -200;
  S.get("lots/L1").data.bid_count = 1;
  S.get("lots/L1").data.highest_bidder_uid = "u0";
  S.set("lots/L1/private/proxy_state", { version: 1, data: { leader_uid: "u0", leader_max: 5000 } });
  await assert.rejects(bid("u1", 800), (e) => e.code === "failed-precondition");
  assert.strictEqual(get("lots/L1").current_bid, 1000);
});
