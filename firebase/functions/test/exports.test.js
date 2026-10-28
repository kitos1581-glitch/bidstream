/**
 * Cada export de index.js debe ser una función de Cloud Functions real.
 * Un export `undefined` (p. ej. por reasignar module.exports en un módulo y
 * seguir usando `exports.x = ...`) hace que Firebase la omita sin avisar.
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

test("index.js: las 35 funciones exportadas existen (ninguna undefined)", () => {
  const fns = require(path.join(__dirname, "..", "index.js"));
  const names = Object.keys(fns);
  const missing = names.filter((n) => typeof fns[n] !== "function" && (typeof fns[n] !== "object" || fns[n] === null));
  assert.deepStrictEqual(missing, [], `exports vacíos: ${missing.join(", ")}`);
  assert.ok(fns.adminSetStorePlan && fns.adminSetFoundingSeller);
  assert.strictEqual(names.length, 35);
});
