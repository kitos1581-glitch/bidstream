/**
 * App Check en las funciones callable.
 *
 * APP_CHECK_MODE (functions/.env):
 *   "monitor" (por defecto) → acepta la llamada pero registra las que no traen
 *                             token. Sirve para la transición mientras las apps
 *                             instaladas se actualizan.
 *   "enforce"               → rechaza llamadas sin token válido de App Check.
 *   "off"                   → no revisa (solo para pruebas locales).
 * Un valor distinto es un error de configuración explícito: se rechaza la
 * llamada en lugar de adivinar el modo.
 */
const functions = require("firebase-functions");

const MODES = ["monitor", "enforce", "off"];

function appCheckMode(env = process.env) {
  const raw = String(env.APP_CHECK_MODE === undefined ? "monitor" : env.APP_CHECK_MODE).trim().toLowerCase();
  if (!MODES.includes(raw)) return { error: `APP_CHECK_MODE inválido: "${env.APP_CHECK_MODE}"` };
  return { mode: raw };
}

/**
 * Lanza HttpsError si la llamada no cumple con App Check según el modo.
 * @param {{app?: object}} context contexto de onCall (v1)
 */
function assertAppCheck(context, env = process.env) {
  const { mode, error } = appCheckMode(env);
  if (error) {
    functions.logger.error(error);
    throw new functions.https.HttpsError("internal", "Configuración del servidor inválida.", {
      code: "APP_CHECK_CONFIG",
    });
  }
  if (mode === "off") return;
  const ok = Boolean(context && context.app);
  if (ok) return;
  if (mode === "monitor") {
    functions.logger.warn("Llamada sin token de App Check (modo monitor: se permite)", {
      uid: context && context.auth ? context.auth.uid : null,
    });
    return;
  }
  throw new functions.https.HttpsError(
    "failed-precondition",
    "Actualiza la app para continuar (verificación de dispositivo).",
    { code: "APP_CHECK_REQUIRED" }
  );
}

module.exports = { assertAppCheck, appCheckMode };
