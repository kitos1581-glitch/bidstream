/**
 * Filtro de datos de contacto: detecta teléfonos, correos, WhatsApp, redes y
 * "@usuario"; NO marca precios, medidas, años, registros ni modelos.
 */
const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const fake = require("./helpers/fake_admin");
function inject(name, exportsObj) {
  const resolved = require.resolve(name);
  require.cache[resolved] = { id: resolved, filename: resolved, loaded: true, exports: exportsObj };
}
inject("firebase-admin", fake);
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";

const cf = require(path.join(__dirname, "..", "contact_filter.js"));
const has = (t, r) => cf.findContactInfo(t).includes(r);

test("detecta teléfonos con cualquier formato", () => {
  for (const t of [
    "Llámame 6141234567",
    "cel 614 123 4567",
    "tel: (614) 123-45-67",
    "614.123.4567",
    "+52 1 614 123 4567",
    "seis uno cuatro uno dos tres cuatro cinco seis siete",
    "6 4 8 1 0 2 8 7 8 1",
  ]) {
    assert.ok(has(t, "phone"), `debió detectar: ${t}`);
  }
});

test("detecta correo, mensajería, redes, @usuario y frases", () => {
  assert.ok(has("escríbeme a juan.perez@gmail.com", "email"));
  assert.ok(has("juan arroba gmail punto com", "email"));
  assert.ok(has("Mándame WhatsApp", "messaging"));
  assert.ok(has("info por wsp", "messaging"));
  assert.ok(has("wa.me/526141234567", "messaging"));
  assert.ok(has("búscame en facebook.com/juanventas", "social"));
  assert.ok(has("sígueme @ventas_juan", "handle"));
  assert.ok(has("más info por inbox", "contact_phrase"));
});

test("NO marca descripciones normales (precios, medidas, años, registros)", () => {
  for (const t of [
    "Complejo energético Cheminova 100 ml. Registro SAGARPA Q-7048-020. Uso veterinario.",
    "Camioneta Ford 2018, 145,000 km, motor 5.4, precio $185,000",
    "Silla de montar 16 pulgadas, cuero, 3 años de uso",
    "Celular Samsung A54 128 GB, IMEI disponible al comprador",
    "Caballo cuarto de milla, 5 años, 1.52 m de alzada",
    "Lote de 24 piezas a $1,250 cada una",
  ]) {
    assert.deepStrictEqual(cf.findContactInfo(t), [], `falso positivo: ${t}`);
  }
});

test("moderationPatch: activa con contacto → revisión; corregida → activa; otros estados no se tocan", () => {
  const dirty = { status: "active", title: "Silla", description: "cel 6141234567", seller_uid: "v" };
  const p = cf.moderationPatch(dirty);
  assert.strictEqual(p.status, "review");
  assert.deepStrictEqual(p.moderation.reasons, ["phone"]);
  // Ya en revisión y sigue sucia: no se vuelve a escribir (sin bucles).
  assert.strictEqual(cf.moderationPatch({ ...dirty, status: "review", moderation: p.moderation }), null);
  // Corregida.
  const fixed = cf.moderationPatch({ status: "review", title: "Silla", description: "Buen estado", moderation: { kind: "contact_info" } });
  assert.strictEqual(fixed.status, "active");
  // Terminadas, canceladas o limpias: nada.
  assert.strictEqual(cf.moderationPatch({ ...dirty, status: "ended" }), null);
  assert.strictEqual(cf.moderationPatch({ status: "active", title: "Silla", description: "Buen estado" }), null);
  // También revisa características.
  assert.strictEqual(cf.moderationPatch({ status: "active", title: "Silla", specs: { Contacto: "wa.me/52614" } }).status, "review");
});
