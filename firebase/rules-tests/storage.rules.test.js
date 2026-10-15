/**
 * Pruebas de storage.rules con el emulador oficial.
 */
const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const { initializeTestEnvironment, assertSucceeds, assertFails } = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getMetadata } = require("firebase/storage");

let env;
const png = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);
const img = { contentType: "image/png" };

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-bidstream",
    storage: { rules: fs.readFileSync(path.join(__dirname, "..", "storage.rules"), "utf8") },
  });
});
test.after(async () => env && env.cleanup());
test.beforeEach(async () => {
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const st = ctx.storage();
    await uploadBytes(ref(st, "lots/vero/foto.png"), png, img);
    await uploadBytes(ref(st, "verifications/vero/ine.png"), png, img);
  });
});

test("fotos de lotes: cualquiera las ve, incluso sin cuenta", async () => {
  await assertSucceeds(getMetadata(ref(env.unauthenticatedContext().storage(), "lots/vero/foto.png")));
  await assertSucceeds(getMetadata(ref(env.authenticatedContext("beto").storage(), "lots/vero/foto.png")));
});

test("fotos de lotes: solo el dueño sube a su carpeta, solo imágenes", async () => {
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(), "lots/vero/x.png"), png, img));
  await assertFails(uploadBytes(ref(env.authenticatedContext("beto").storage(), "lots/vero/x.png"), png, img));
  await assertSucceeds(uploadBytes(ref(env.authenticatedContext("vero").storage(), "lots/vero/x.png"), png, img));
  await assertFails(
    uploadBytes(ref(env.authenticatedContext("vero").storage(), "lots/vero/x.exe"), png, { contentType: "application/octet-stream" })
  );
});

test("INE: privada (ni invitados ni otros usuarios); el dueño y admin sí", async () => {
  await assertFails(getMetadata(ref(env.unauthenticatedContext().storage(), "verifications/vero/ine.png")));
  await assertFails(getMetadata(ref(env.authenticatedContext("beto").storage(), "verifications/vero/ine.png")));
  await assertSucceeds(getMetadata(ref(env.authenticatedContext("vero").storage(), "verifications/vero/ine.png")));
  await assertSucceeds(getMetadata(ref(env.authenticatedContext("jefe", { admin: true }).storage(), "verifications/vero/ine.png")));
});
