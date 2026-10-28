const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const fake = require("./helpers/fake_admin");
const calls = [];
let nextResponse = null;
let nextError = null;
class FakeAnthropic {
  constructor() {
    this.messages = {
      create: async (req) => {
        calls.push(req);
        if (nextError) throw nextError;
        return nextResponse;
      },
    };
  }
}
function inject(name, obj) {
  const r = require.resolve(name);
  require.cache[r] = { id: r, filename: r, loaded: true, exports: obj };
}
inject("firebase-admin", fake);
inject("@anthropic-ai/sdk", FakeAnthropic);
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";
process.env.ANTHROPIC_API_KEY = "test";
process.env.AI_DAILY_LIMIT = "2";
const ai = require(path.join(__dirname, "..", "ai.js"));

const S = fake.__store;
const ctx = { auth: { uid: "ana", token: { email_verified: true } } };
const img = { mime: "image/jpeg", data: Buffer.from("foto").toString("base64") };
const good = {
  stop_reason: "tool_use",
  content: [
    {
      type: "tool_use",
      name: "proponer_publicacion",
      input: {
        title: "Bicicleta de montaña rodada 29",
        category: "Deportes",
        description: "Qué es:\nBicicleta\nEstado:\nUsada\nDetalles a considerar:\nRayón en el cuadro.",
        detected_issues: ["Rayón en el cuadro"],
        missing_info: ["¿Talla del cuadro?"],
        condition_mismatch: "",
        prohibited: false,
        prohibited_reason: "",
      },
    },
  ],
};
function reset(user = { full_name: "Ana", verified: true }) {
  fake.__reset();
  nextResponse = good;
  nextError = null;
  process.env.ANTHROPIC_API_KEY = "test";
  delete process.env.AI_MODEL;
  process.env.AI_DAILY_LIMIT = "2";
  delete process.env.AI_GLOBAL_DAILY_LIMIT;
  if (user) S.set("users/ana", { version: 1, data: user });
}
const usage = () => {
  const day = new Date().toLocaleDateString("en-CA", { timeZone: "America/Mexico_City" });
  const e = S.get(`users/ana/ai_usage/${day}`);
  return e ? e.data.count : 0;
};
const run = (over = {}) =>
  ai.generateLotDescription.run({ images: [img], condition: "used_good", ...over }, ctx);

test("borra teléfonos y correos que la IA pudiera incluir", () => {
  const s = ai.stripContactInfo("Llama al 614 123 4567 o escribe a ana@mail.com. Año 2015, 120000 km");
  assert.ok(!s.includes("614") && !s.includes("ana@mail.com"));
  assert.ok(s.includes("2015") && s.includes("120000"));
});

test("sanitiza categoría inválida y recorta listas", () => {
  const r = ai.sanitizeSuggestion({ title: "Bici", category: "X", description: "x", missing_info: "abcdefg".split(""), prohibited: "sí" });
  assert.strictEqual(r.category, "Otros");
  assert.strictEqual(r.missing_info.length, 5);
  assert.strictEqual(r.prohibited, false);
});

test("valida fotos: formato y tamaño", () => {
  assert.strictEqual(ai.validateImages([]).ok, false);
  assert.strictEqual(ai.validateImages([{ mime: "application/pdf", data: "AAAA" }]).ok, false);
  assert.strictEqual(ai.validateImages([{ mime: "image/jpeg", data: "A".repeat(3 * 1024 * 1024) }]).ok, false);
  assert.strictEqual(ai.validateImages([img, img, img, img, img, img]).images.length, 4);
});

test("configuración del proveedor: estricta y explícita", () => {
  assert.throws(() => ai.readAiConfig({}), ai.AiConfigError); // sin llave
  assert.throws(() => ai.readAiConfig({ ANTHROPIC_API_KEY: "k", AI_DAILY_LIMIT: "abc" }), ai.AiConfigError);
  assert.throws(() => ai.readAiConfig({ ANTHROPIC_API_KEY: "k", AI_DAILY_LIMIT: "0" }), ai.AiConfigError);
  assert.throws(() => ai.readAiConfig({ ANTHROPIC_API_KEY: "k", AI_DAILY_LIMIT: "2.5" }), ai.AiConfigError);
  assert.throws(() => ai.readAiConfig({ ANTHROPIC_API_KEY: "k", AI_MODEL: "modelo con espacios" }), ai.AiConfigError);
  const c = ai.readAiConfig({ ANTHROPIC_API_KEY: "k" });
  assert.deepStrictEqual([c.model, c.dailyLimit], ["claude-sonnet-5-5", 20]);
});

test("con configuración inválida responde error claro y NO consume cuota", async () => {
  reset();
  process.env.AI_DAILY_LIMIT = "abc";
  await assert.rejects(run(), (e) => e.code === "failed-precondition" && /configuración/.test(e.message));
  assert.strictEqual(usage(), 0);
});

test("llama a Claude con fotos, estado y notas; exige revisión humana", async () => {
  reset();
  const r = await run({ notes: "Tiene 2 años de uso" });
  assert.strictEqual(r.category, "Deportes");
  assert.strictEqual(r.requires_review, true);
  const req = calls[calls.length - 1];
  assert.strictEqual(req.tool_choice.type, "auto", "Sonnet 5.5 no acepta tool_choice forzado");
  assert.ok(req.tools.some((t) => t.name === "proponer_publicacion"));
  assert.strictEqual(req.messages[0].content[0].type, "image");
  assert.ok(req.messages[0].content[1].text.includes("Usado en buen estado"));
  assert.strictEqual(usage(), 1);
});

test("permisos: suspendidos y sin identidad verificada no pueden usarlo", async () => {
  reset({ full_name: "Ana", verified: true, banned: true });
  await assert.rejects(run(), (e) => e.code === "permission-denied");
  reset({ full_name: "Ana", verified: false });
  await assert.rejects(run(), (e) => e.code === "failed-precondition");
  reset(null);
  await assert.rejects(run(), (e) => e.code === "failed-precondition");
  assert.strictEqual(usage(), 0);
});

test("exige estado del artículo (y no acepta claves heredadas)", async () => {
  reset();
  await assert.rejects(run({ condition: "" }), (e) => e.code === "invalid-argument");
  await assert.rejects(run({ condition: "toString" }), (e) => e.code === "invalid-argument");
});

test("límite diario por usuario", async () => {
  reset();
  await run();
  await run();
  await assert.rejects(run(), (e) => e.code === "resource-exhausted");
});

test("límite diario global de la plataforma", async () => {
  reset();
  process.env.AI_GLOBAL_DAILY_LIMIT = "1";
  await run();
  S.set("users/ana", { version: 1, data: { full_name: "Ana", verified: true } });
  await assert.rejects(run(), (e) => e.code === "resource-exhausted" && /asistente alcanzó/.test(e.message));
});

test("si el proveedor falla, se devuelve el uso consumido", async () => {
  reset();
  nextError = new Error("529 overloaded");
  await assert.rejects(run(), (e) => e.code === "unavailable");
  assert.strictEqual(usage(), 0);
});

test("respuesta truncada o sin propuesta: error y se devuelve el uso", async () => {
  reset();
  nextResponse = { ...good, stop_reason: "max_tokens" };
  await assert.rejects(run(), (e) => e.code === "unavailable");
  nextResponse = { stop_reason: "end_turn", content: [{ type: "text", text: "hola" }] };
  await assert.rejects(run(), (e) => e.code === "unavailable");
  assert.strictEqual(usage(), 0);
});

test("uso concurrente no rebasa el límite", async () => {
  reset();
  const res = await Promise.allSettled([run(), run(), run(), run()]);
  assert.strictEqual(res.filter((x) => x.status === "fulfilled").length, 2);
  assert.strictEqual(usage(), 2);
});

test("sniffImageType: usa el tipo real de la foto (el celular puede mentir)", () => {
  const b64 = (bytes) => Buffer.from(bytes).toString("base64");
  const pad = new Array(16).fill(0);
  assert.strictEqual(ai.sniffImageType(b64([0xff, 0xd8, 0xff, 0xe0, ...pad])), "image/jpeg");
  assert.strictEqual(ai.sniffImageType(b64([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...pad])), "image/png");
  assert.strictEqual(ai.sniffImageType(b64([...Buffer.from("RIFF"), 0, 0, 0, 0, ...Buffer.from("WEBP"), ...pad])), "image/webp");
  assert.strictEqual(ai.sniffImageType(b64([0, 0, 0, 0x18, ...Buffer.from("ftypheic"), ...pad])), "heic");
  // Declarada jpeg pero es PNG → se manda como PNG.
  const png = b64([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...pad]);
  assert.strictEqual(ai.validateImages([{ mime: "image/jpeg", data: png }]).images[0].mime, "image/png");
  assert.strictEqual(ai.validateImages([{ mime: "image/jpeg", data: b64([0, 0, 0, 0x18, ...Buffer.from("ftypheic"), ...pad]) }]).ok, false);
});
