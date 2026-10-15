/**
 * Pruebas de firestore.rules con el EMULADOR OFICIAL.
 * Uso (desde firebase/rules-tests):  npm install && npm test
 * Requiere Java 11+ y firebase-tools (npm i -g firebase-tools).
 */
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { doc, getDoc, setDoc, updateDoc, getDocs, collection, query, where, Timestamp } =
  require("firebase/firestore");

let env;
const H = 3600 * 1000;

function validLot(over = {}) {
  const now = Date.now();
  return {
    title: "Bicicleta rodada 29",
    description: "Usada, buen estado.",
    category: "Deportes",
    image_urls: ["https://x/1.jpg"],
    stream_url: "",
    starting_price: 1000,
    current_bid: 1000,
    minimum_increment: 100,
    bid_count: 0,
    start_time: Timestamp.fromMillis(now),
    end_time: Timestamp.fromMillis(now + 24 * H),
    status: "active",
    format: "timed",
    condition: "used_good",
    seller_uid: "vero",
    ...over,
  };
}

// Contextos: vero (vendedora verificada), beto (sin INE), ana (suspendida), jefe (admin)
const as = (uid, claims = {}) => env.authenticatedContext(uid, { email_verified: true, ...claims }).firestore();

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-bidstream",
    firestore: { rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8") },
  });
});
test.after(async () => env && env.cleanup());
test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/vero"), { full_name: "Vero", verified: true });
    await setDoc(doc(db, "users/beto"), { full_name: "Beto", verified: false });
    await setDoc(doc(db, "users/ana"), { full_name: "Ana", verified: true, banned: true });
    await setDoc(doc(db, "lots/L1"), validLot());
    await setDoc(doc(db, "lots/L2"), validLot({ bid_count: 3, current_bid: 1500, highest_bidder_uid: "beto" }));
    await setDoc(doc(db, "lots/L1/bids/b1"), { user_id: "beto", max_amount: 5000 });
    await setDoc(doc(db, "lots/L1/history/h1"), { bidder_name: "Beto R.", amount: 1000 });
    await setDoc(doc(db, "lots/L1/private/proxy_state"), { leader_uid: "beto", leader_max: 5000 });
    await setDoc(doc(db, "payments/p1"), { uid: "vero", kind: "payout" });
  });
});

// ------------------------------- Crear lotes -------------------------------
test("crear: lote válido de vendedora verificada", async () => {
  await assertSucceeds(setDoc(doc(as("vero"), "lots/N1"), validLot()));
});

test("crear: rechaza incremento negativo, cero, precio inválido y datos inconsistentes", async () => {
  const db = as("vero");
  for (const over of [
    { minimum_increment: -200 },
    { minimum_increment: 0 },
    { starting_price: -5, current_bid: -5 },
    { starting_price: "1000", current_bid: "1000" },
    { current_bid: 900 },
    { bid_count: 2 },
    { status: "ended" },
    { end_time: Timestamp.fromMillis(Date.now() - 1000) },
    { end_time: Timestamp.fromMillis(Date.now() + 90 * 24 * H) }, // > 60 días
    { format: "otro" },
    { condition: "roto" },
    { title: "x" },
    { image_urls: Array(11).fill("u") },
    { highest_bidder_uid: "yo" },
    { seller_uid: "otra" },
  ]) {
    await assertFails(setDoc(doc(db, `lots/X${Math.random()}`), validLot(over)));
  }
});

test("crear: sin INE o suspendido no puede vender", async () => {
  await assertFails(setDoc(doc(as("beto"), "lots/N2"), validLot({ seller_uid: "beto" })));
  await assertFails(setDoc(doc(as("ana"), "lots/N3"), validLot({ seller_uid: "ana" })));
  await assertFails(
    setDoc(doc(env.authenticatedContext("vero", { email_verified: false }).firestore(), "lots/N4"), validLot())
  );
});

// ----------------------------- Actualizar lotes ----------------------------
test("AUDITORÍA: actualizar a incremento negativo se rechaza (antes se permitía)", async () => {
  await assertFails(updateDoc(doc(as("vero"), "lots/L1"), { minimum_increment: -200 }));
  await assertFails(updateDoc(doc(as("vero"), "lots/L1"), { minimum_increment: 0 }));
});

test("actualizar: la misma validación que al crear", async () => {
  const db = as("vero");
  await assertSucceeds(updateDoc(doc(db, "lots/L1"), { title: "Bicicleta de montaña" }));
  await assertSucceeds(updateDoc(doc(db, "lots/L1"), { starting_price: 1200, current_bid: 1200 }));
  await assertFails(updateDoc(doc(db, "lots/L1"), { title: "x" }));
  await assertFails(updateDoc(doc(db, "lots/L1"), { starting_price: 1500 })); // current_bid (1200) ≠ starting
  await assertFails(updateDoc(doc(db, "lots/L1"), { current_bid: 5 }));
  await assertFails(updateDoc(doc(db, "lots/L1"), { status: "ended" }));
  await assertFails(updateDoc(doc(db, "lots/L1"), { bid_count: 5 }));
});

test("actualizar: con pujas no se tocan precio, incremento ni fechas", async () => {
  const db = as("vero");
  await assertSucceeds(updateDoc(doc(db, "lots/L2"), { description: "Más detalles" }));
  await assertFails(updateDoc(doc(db, "lots/L2"), { minimum_increment: 1 }));
  await assertFails(updateDoc(doc(db, "lots/L2"), { end_time: Timestamp.fromMillis(Date.now() + 48 * H) }));
});

test("actualizar: otro usuario o vendedora suspendida no pueden", async () => {
  await assertFails(updateDoc(doc(as("beto"), "lots/L1"), { title: "Robado" }));
  await env.withSecurityRulesDisabled((c) => updateDoc(doc(c.firestore(), "users/vero"), { banned: true }));
  await assertFails(updateDoc(doc(as("vero"), "lots/L1"), { title: "Bicicleta nueva" }));
});

// ------------------------- Pujas y estado privado --------------------------
test("máximos secretos: cada quien solo lee los suyos; nadie escribe", async () => {
  await assertSucceeds(getDoc(doc(as("beto"), "lots/L1/bids/b1")));
  await assertFails(getDoc(doc(as("vero"), "lots/L1/bids/b1")));
  await assertSucceeds(getDocs(query(collection(as("beto"), "lots/L1/bids"), where("user_id", "==", "beto"))));
  await assertFails(getDocs(collection(as("vero"), "lots/L1/bids")));
  await assertFails(setDoc(doc(as("beto"), "lots/L1/bids/b2"), { user_id: "beto", max_amount: 9 }));
});

test("historial público legible; estado privado del proxy cerrado", async () => {
  await assertSucceeds(getDoc(doc(as("vero"), "lots/L1/history/h1")));
  await assertFails(setDoc(doc(as("vero"), "lots/L1/history/h2"), { amount: 1 }));
  await assertFails(getDoc(doc(as("beto"), "lots/L1/private/proxy_state")));
});

// --------------------------------- Usuarios --------------------------------
test("usuarios: no pueden darse verificación, depósito, rol ni quitarse suspensión", async () => {
  const db = as("beto");
  await assertSucceeds(updateDoc(doc(db, "users/beto"), { phone: "6141234567" }));
  for (const f of [
    { verified: true },
    { deposit: { status: "held", amount: 200 } },
    { role: "admin" },
    { banned: false },
    { strikes: 0 },
    { verification_status: "approved" },
  ]) {
    await assertFails(updateDoc(doc(db, "users/beto"), f));
  }
  await assertFails(getDoc(doc(as("vero"), "users/beto")));
  await assertSucceeds(getDoc(doc(as("jefe", { admin: true }), "users/beto")));
});

test("pagos: dueño y admin leen; nadie escribe desde la app", async () => {
  await assertSucceeds(getDoc(doc(as("vero"), "payments/p1")));
  await assertFails(getDoc(doc(as("beto"), "payments/p1")));
  await assertSucceeds(getDoc(doc(as("jefe", { admin: true }), "payments/p1")));
  await assertFails(setDoc(doc(as("vero"), "payments/p2"), { uid: "vero" }));
});

test("cuota de IA: solo lectura propia", async () => {
  await assertFails(setDoc(doc(as("vero"), "users/vero/ai_usage/2026-10-14"), { count: 0 }));
});

test("características (specs): mapa aceptado, otro tipo o demasiadas se rechazan", async () => {
  const db = as("vero");
  await assertSucceeds(updateDoc(doc(db, "lots/L1"), { specs: { marca: "Trek", talla: "Rodada 29" } }));
  await assertFails(updateDoc(doc(db, "lots/L1"), { specs: "Trek" }));
  const many = {};
  for (let i = 0; i < 31; i++) many["k" + i] = "v";
  await assertFails(updateDoc(doc(db, "lots/L1"), { specs: many }));
});

test("sin cuenta: se ve el catálogo y el historial, pero no máximos, ni se escribe", async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(anon, "lots/L1")));
  await assertSucceeds(getDocs(query(collection(anon, "lots"), where("status", "==", "active"))));
  await assertSucceeds(getDoc(doc(anon, "lots/L1/history/h1")));
  await assertFails(getDoc(doc(anon, "lots/L1/bids/b1")));
  await assertFails(getDoc(doc(anon, "lots/L1/private/proxy_state")));
  await assertFails(getDoc(doc(anon, "users/vero")));
  await assertFails(setDoc(doc(anon, "lots/N9"), validLot({ seller_uid: "nadie" })));
  await assertFails(updateDoc(doc(anon, "lots/L1"), { title: "Hackeado" }));
});

test("reputación: calificaciones y perfiles públicos se leen sin cuenta; nadie los escribe", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "feedback/L1"), { rating: 5, seller_uid: "vero", author_uid: "beto" });
    await setDoc(doc(db, "public_profiles/vero"), { display_name: "Vero V.", rating_avg: 5 });
  });
  const anon = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(anon, "feedback/L1")));
  await assertSucceeds(getDoc(doc(anon, "public_profiles/vero")));
  await assertFails(setDoc(doc(as("beto"), "feedback/L2"), { rating: 5, seller_uid: "vero", author_uid: "beto" }));
  await assertFails(updateDoc(doc(as("vero"), "public_profiles/vero"), { rating_avg: 5, badges: ["destacado"] }));
  await assertFails(setDoc(doc(as("vero"), "public_profiles/vero"), { rating_avg: 5 }));
});

test("reputación: el vendedor no puede inventarse insignias ni calificación al publicar", async () => {
  await assertFails(setDoc(doc(as("vero"), "lots/N5"), validLot({ seller_badges: ["destacado"] })));
  await assertFails(setDoc(doc(as("vero"), "lots/N6"), validLot({ seller_rating_avg: 5, seller_rating_count: 99 })));
  await assertFails(updateDoc(doc(as("vero"), "lots/L1"), { seller_badges: ["destacado"] }));
});

test("precio de reserva: secreto para todos (ni el vendedor lo lee desde la app) y nadie lo escribe", async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "lots/L1/private/reserve"), { amount: 5000 });
  });
  await assertFails(getDoc(doc(as("vero"), "lots/L1/private/reserve")));
  await assertFails(getDoc(doc(as("beto"), "lots/L1/private/reserve")));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "lots/L1/private/reserve")));
  await assertFails(setDoc(doc(as("vero"), "lots/L1/private/reserve"), { amount: 1 }));
  await assertFails(setDoc(doc(as("vero"), "lots/N7"), validLot({ has_reserve: true, reserve_met: true })));
});

test("municipio y entrega: valores válidos al publicar; envío solo se cambia sin pujas", async () => {
  const db = as("vero");
  await assertSucceeds(setDoc(doc(db, "lots/M1"), validLot({
    municipality: "camargo",
    delivery: { pickup: true, regional: true, shipping_cost: 350, shipping_included: false, destinations: ["delicias", "parral"] },
  })));
  await assertFails(setDoc(doc(db, "lots/M2"), validLot({ municipality: "marte" })));
  await assertFails(setDoc(doc(db, "lots/M3"), validLot({ delivery: { pickup: false, regional: false } })));
  await assertFails(setDoc(doc(db, "lots/M4"), validLot({ delivery: { pickup: true, regional: true, shipping_cost: -10 } })));
  await assertFails(setDoc(doc(db, "lots/M5"), validLot({ delivery: { pickup: true, hack: 1 } })));
  await assertFails(setDoc(doc(db, "lots/M6"), validLot({ shipping_charge: 0, delivery_choice: "pickup" })));
  await assertSucceeds(updateDoc(doc(db, "lots/L1"), { municipality: "jimenez" }));
  await assertFails(updateDoc(doc(db, "lots/L2"), { delivery: { pickup: true, regional: true, shipping_cost: 1 } }));
});

test("usuarios: no se pueden dar plan de tienda ni borrar sus strikes de vendedor", async () => {
  await assertFails(updateDoc(doc(as("vero"), "users/vero"), { seller_plan: "store" }));
  await assertFails(updateDoc(doc(as("vero"), "users/vero"), { store_plan_until: Timestamp.fromMillis(Date.now() + 1e10) }));
  await assertFails(updateDoc(doc(as("vero"), "users/vero"), { seller_strikes: 0 }));
});
