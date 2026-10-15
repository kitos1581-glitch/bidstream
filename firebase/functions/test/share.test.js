const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");
const fake = require("./helpers/fake_admin");
const resolved = require.resolve("firebase-admin");
require.cache[resolved] = { id: resolved, filename: resolved, loaded: true, exports: fake };
const { renderLotCard } = require(path.join(__dirname, "..", "share.js"));

const lot = {
  title: 'Caballo "Relámpago" <cuarto de milla>',
  description: "Manso, 4 años.\nCon registro.",
  status: "active",
  current_bid: 87500,
  image_urls: ["emoji:🐎:1:2", "https://firebasestorage.googleapis.com/x.jpg"],
};

test("tarjeta: título, precio, primera foto https y redirección al lote", () => {
  const { status, html } = renderLotCard("L1", lot, "https://subastaloaqui.mx");
  assert.strictEqual(status, 200);
  assert.match(html, /og:image" content="https:\/\/firebasestorage.googleapis.com\/x.jpg"/);
  assert.match(html, /87,500 MXN/);
  assert.match(html, /url=https:\/\/subastaloaqui.mx\/lotDetailView\?lotId=L1/);
  assert.match(html, /name="robots" content="noindex"/);
});

test("tarjeta: escapa HTML del título (no se puede inyectar código)", () => {
  const { html } = renderLotCard("L1", lot, "https://x.mx");
  assert.ok(!html.includes("<cuarto"));
  assert.ok(html.includes("&quot;Relámpago&quot; &lt;cuarto de milla&gt;"));
});

test("tarjeta: lote inexistente → 404 y regreso al inicio", () => {
  const { status, html } = renderLotCard("NO", null, "https://x.mx");
  assert.strictEqual(status, 404);
  assert.match(html, /url=https:\/\/x.mx\//);
});
