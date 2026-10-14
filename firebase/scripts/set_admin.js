/**
 * Da (o quita) permisos de administrador a un usuario.
 *
 * Uso (desde la carpeta firebase/):
 *   1. Descarga una llave de cuenta de servicio:
 *      Consola de Firebase → Configuración del proyecto → Cuentas de servicio
 *      → Generar nueva clave privada. Guárdala FUERA del proyecto y nunca la subas a git.
 *   2. export GOOGLE_APPLICATION_CREDENTIALS=/ruta/a/llave.json
 *   3. node scripts/set_admin.js correo@ejemplo.com          (dar admin)
 *      node scripts/set_admin.js correo@ejemplo.com --quitar (quitar admin)
 *   4. El usuario debe cerrar sesión y volver a entrar para que aplique.
 */
const admin = require("./../functions/node_modules/firebase-admin");

async function main() {
  const email = process.argv[2];
  const remove = process.argv.includes("--quitar");
  if (!email) {
    console.error("Uso: node scripts/set_admin.js correo@ejemplo.com [--quitar]");
    process.exit(1);
  }
  admin.initializeApp({ projectId: "bidstream-656cf" });
  const user = await admin.auth().getUserByEmail(email);
  const claims = { ...(user.customClaims || {}) };
  if (remove) delete claims.admin;
  else claims.admin = true;
  await admin.auth().setCustomUserClaims(user.uid, claims);
  await admin
    .firestore()
    .collection("users")
    .doc(user.uid)
    .set({ role: remove ? "user" : "admin" }, { merge: true });
  console.log(`${email} ${remove ? "ya NO es" : "ahora es"} administrador (uid ${user.uid}).`);
  console.log("Pídele que cierre sesión y vuelva a entrar.");
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
