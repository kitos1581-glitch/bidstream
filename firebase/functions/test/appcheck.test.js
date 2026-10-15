const test = require("node:test");
const assert = require("node:assert");
const { assertAppCheck, appCheckMode } = require("../appcheck");

const code = (fn) => {
  try { fn(); return null; } catch (e) { return e.details && e.details.code; }
};

test("App Check: modo por defecto 'monitor' deja pasar sin token (transición)", () => {
  assert.deepStrictEqual(appCheckMode({}), { mode: "monitor" });
  assert.strictEqual(code(() => assertAppCheck({ auth: { uid: "a" } }, {})), null);
});

test("App Check: 'enforce' rechaza sin token y acepta con token", () => {
  const env = { APP_CHECK_MODE: "enforce" };
  assert.strictEqual(code(() => assertAppCheck({ auth: { uid: "a" } }, env)), "APP_CHECK_REQUIRED");
  assert.strictEqual(code(() => assertAppCheck({ auth: { uid: "a" }, app: { appId: "x" } }, env)), null);
});

test("App Check: valor inválido = error de configuración explícito (no se adivina)", () => {
  assert.ok(appCheckMode({ APP_CHECK_MODE: "siempre" }).error);
  assert.strictEqual(code(() => assertAppCheck({ app: {} }, { APP_CHECK_MODE: "siempre" })), "APP_CHECK_CONFIG");
});

test("App Check: 'off' no revisa", () => {
  assert.strictEqual(code(() => assertAppCheck({}, { APP_CHECK_MODE: "off" })), null);
});
