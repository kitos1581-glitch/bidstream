/**
 * Reputación: calificaciones, agregados, insignias y abuso.
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

const rep = require(path.join(__dirname, "..", "reputation.js"));
const pay = require(path.join(__dirname, "..", "payments.js"));
const { Timestamp } = fake.firestore;
const S = fake.__store;
const get = (p) => (S.get(p) ? S.get(p).data : undefined);
const put = (p, data) => S.set(p, { version: 1, data });

function reset() {
  fake.__reset();
  mp.__reset();
  put("users/vendedor", { full_name: "Vero Vendedora", verified: true, phone: "614" });
  put("users/ana", { full_name: "Ana Pérez" });
  put("users/beto", { full_name: "Beto Ruiz" });
  put("lots/V1", { title: "Silla de montar", seller_uid: "vendedor", winner_uid: "ana", payment_status: "paid", status: "ended", current_bid: 9000 });
  put("lots/V2", { title: "Reloj", seller_uid: "vendedor", winner_uid: "beto", payment_status: "paid", status: "ended", current_bid: 7000 });
}
const submit = (d, uid = "ana", now) => rep.submitFeedbackImpl(d, uid, now);
async function rejectsWith(p, code) {
  await assert.rejects(p, (e) => e.details && e.details.code === code);
}

test("insignias: verificado, destacado (≥10 ventas y ≥4.5) y nuevo (<3 ventas)", () => {
  assert.deepStrictEqual(rep.computeBadges({ verified: true, sales_count: 0 }), ["verificado", "nuevo"]);
  assert.deepStrictEqual(rep.computeBadges({ verified: true, sales_count: 10, rating_avg: 4.5, rating_count: 8 }), ["verificado", "destacado"]);
  assert.deepStrictEqual(rep.computeBadges({ verified: false, sales_count: 12, rating_avg: 4.4, rating_count: 9 }), []);
});

test("el comprador que pagó califica; se actualizan promedio y conteo del vendedor", async () => {
  reset();
  const r = await submit({ lotId: "V1", rating: 5, comment: "Excelente, llegó como se describió" });
  assert.deepStrictEqual(r, { ok: true, lotId: "V1", rating: 5 });
  await submit({ lotId: "V2", rating: 4 }, "beto");
  const prof = get("public_profiles/vendedor");
  assert.strictEqual(prof.rating_count, 2);
  assert.strictEqual(prof.rating_avg, 4.5);
  assert.strictEqual(prof.display_name, "Vero V.");
  assert.strictEqual(prof.phone, undefined, "el perfil público no lleva teléfono");
  const fb = get("feedback/V1");
  assert.strictEqual(fb.author_name, "Ana P.");
  assert.strictEqual(fb.author_uid, "ana");
});

test("abuso: quien no compró, sin pago, doble calificación, datos inválidos", async () => {
  reset();
  await rejectsWith(submit({ lotId: "V1", rating: 5 }, "beto"), "NOT_BUYER");
  await rejectsWith(submit({ lotId: "V1", rating: 5 }, "vendedor"), "NOT_BUYER");
  await rejectsWith(submit({ lotId: "V1", rating: 5 }, null), "UNAUTHENTICATED");
  await rejectsWith(submit({ lotId: "V1", rating: 6 }), "INVALID_ARGUMENT");
  await rejectsWith(submit({ lotId: "V1", rating: 4.5 }), "INVALID_ARGUMENT");
  await rejectsWith(submit({ lotId: "V1", rating: 5, comment: "x".repeat(501) }), "INVALID_ARGUMENT");
  await rejectsWith(submit({ lotId: "NO", rating: 5 }), "LOT_NOT_FOUND");
  S.get("lots/V1").data.payment_status = "pending";
  await rejectsWith(submit({ lotId: "V1", rating: 5 }), "NOT_PAID");
  S.get("lots/V1").data.payment_status = "paid";
  await submit({ lotId: "V1", rating: 5 });
  await rejectsWith(submit({ lotId: "V1", rating: 1 }), "ALREADY_RATED");
  assert.strictEqual(get("public_profiles/vendedor").rating_count, 1);
});

test("dos calificaciones simultáneas de la misma compra: cuenta una sola", async () => {
  reset();
  const rs = await Promise.allSettled([submit({ lotId: "V1", rating: 5 }), submit({ lotId: "V1", rating: 1 })]);
  assert.strictEqual(rs.filter((r) => r.status === "fulfilled").length, 1);
  assert.strictEqual(get("public_profiles/vendedor").rating_count, 1);
});

test("disputa abierta bloquea calificar y editar", async () => {
  reset();
  S.get("lots/V1").data.dispute_status = "open";
  await rejectsWith(submit({ lotId: "V1", rating: 1 }), "DISPUTE_OPEN");
});

test("comentarios públicos sin teléfonos ni correos", () => {
  const { comment } = rep.parseInput({ lotId: "V1", rating: 5, comment: "Llámale al 614 123 4567 o a vero@mail.com" });
  assert.ok(!comment.includes("614 123 4567"));
  assert.ok(!comment.includes("vero@mail.com"));
});

test("editar: solo el autor, dentro de 7 días; el promedio se recalcula sin duplicar", async () => {
  reset();
  const t0 = Date.now();
  await submit({ lotId: "V1", rating: 2 }, "ana", t0);
  await rep.updateFeedbackImpl({ lotId: "V1", rating: 5, comment: "Se resolvió bien" }, "ana", t0 + 3600_000);
  let prof = get("public_profiles/vendedor");
  assert.strictEqual(prof.rating_count, 1);
  assert.strictEqual(prof.rating_avg, 5);
  await rejectsWith(rep.updateFeedbackImpl({ lotId: "V1", rating: 1 }, "beto", t0), "NOT_BUYER");
  await rejectsWith(rep.updateFeedbackImpl({ lotId: "V1", rating: 1 }, "ana", t0 + rep.EDIT_WINDOW_MS + 1), "EDIT_WINDOW_CLOSED");
  prof = get("public_profiles/vendedor");
  assert.strictEqual(prof.rating_avg, 5);
});

test("cada venta pagada suma 1 al contador de ventas del vendedor (una sola vez)", async () => {
  reset();
  put("lots/P1", { title: "Tractor", status: "ended", seller_uid: "vendedor", winner_uid: "ana", current_bid: 1000, payment_status: "pending", amount_due: 1000 });
  const pmt = { id: "MP1", status: "approved", external_reference: "win:P1:ana", transaction_amount: 1000, currency_id: "MXN" };
  await pay.applyApprovedPayment(pmt);
  await pay.applyApprovedPayment(pmt); // webhook repetido
  assert.strictEqual(get("public_profiles/vendedor").sales_count, 1);
});

test("refreshProfile: insignias y verificado al día con el usuario", async () => {
  reset();
  put("public_profiles/vendedor", { sales_count: 12, rating_sum: 46, rating_count: 10, rating_avg: 4.6 });
  await rep.refreshProfile("vendedor");
  assert.deepStrictEqual(get("public_profiles/vendedor").badges, ["verificado", "destacado"]);
});
