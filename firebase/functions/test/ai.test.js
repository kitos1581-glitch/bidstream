const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const fake = require("./helpers/fake_admin");
const calls = [];
let nextResponse = null;
class FakeAnthropic {
  constructor() {
    this.messages = {
      create: async (req) => {
        calls.push(req);
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

const ctx = { auth: { uid: "ana", token: { email_verified: true } } };
const img = { mime: "image/jpeg", data: Buffer.from("foto").toString("base64") };

test("borra teléfonos y correos que la IA pudiera incluir", () => {
  const s = ai.stripContactInfo("Llama al 614 123 4567 o escribe a ana@mail.com. Año 2015, 120000 km");
  assert.ok(!s.includes("614"));
  assert.ok(!s.includes("ana@mail.com"));
  assert.ok(s.includes("2015") && s.includes("120000"));
});

test("sanitiza categoría inválida y recorta listas", () => {
  const r = ai.sanitizeSuggestion({
    title: "Bici",
    category: "Juguetes raros",
    description: "x",
    missing_info: ["a", "b", "c", "d", "e", "f", "g"],
    prohibited: "sí",
  });
  assert.strictEqual(r.category, "Otros");
  assert.strictEqual(r.missing_info.length, 5);
  assert.strictEqual(r.prohibited, false);
});

test("valida fotos: formato y tamaño", () => {
  assert.strictEqual(ai.validateImages([]).ok, false);
  assert.strictEqual(ai.validateImages([{ mime: "application/pdf", data: "AAAA" }]).ok, false);
  const big = { mime: "image/jpeg", data: "A".repeat(3 * 1024 * 1024) };
  assert.strictEqual(ai.validateImages([big]).ok, false);
  assert.strictEqual(ai.validateImages([img, img, img, img, img, img]).images.length, 4);
});

test("llama a Claude con fotos, estado y notas, y regresa la propuesta", async () => {
  fake.__reset();
  nextResponse = {
    content: [
      {
        type: "tool_use",
        name: "proponer_publicacion",
        input: {
          title: "Bicicleta de montaña rodada 29",
          category: "Deportes",
          description: "Qué es:\nBicicleta...\nEstado:\nUsada...\nDetalles a considerar:\nRayón en el cuadro.",
          detected_issues: ["Rayón en el cuadro"],
          missing_info: ["¿Talla del cuadro?"],
          condition_mismatch: "",
          prohibited: false,
          prohibited_reason: "",
        },
      },
    ],
  };
  const r = await ai.generateLotDescription.run(
    { images: [img], condition: "used_good", notes: "Tiene 2 años de uso" },
    ctx
  );
  assert.strictEqual(r.category, "Deportes");
  assert.deepStrictEqual(r.detected_issues, ["Rayón en el cuadro"]);
  const req = calls[calls.length - 1];
  assert.strictEqual(req.tool_choice.name, "proponer_publicacion");
  assert.strictEqual(req.messages[0].content[0].type, "image");
  assert.ok(req.messages[0].content[1].text.includes("Usado en buen estado"));
  assert.ok(req.messages[0].content[1].text.includes("2 años"));
});

test("exige estado del artículo y respeta el límite diario", async () => {
  fake.__reset();
  await assert.rejects(
    ai.generateLotDescription.run({ images: [img], condition: "" }, ctx),
    (e) => e.code === "invalid-argument"
  );
  await ai.generateLotDescription.run({ images: [img], condition: "new" }, ctx);
  await ai.generateLotDescription.run({ images: [img], condition: "new" }, ctx);
  await assert.rejects(
    ai.generateLotDescription.run({ images: [img], condition: "new" }, ctx),
    (e) => e.code === "resource-exhausted"
  );
});
