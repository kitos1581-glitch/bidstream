/**
 * Asistente de publicación con IA (Claude).
 *
 * El vendedor manda hasta 4 fotos + el estado del artículo (nuevo/usado) +
 * notas opcionales. La IA propone título, categoría y una descripción
 * honesta, y además señala:
 *   - detalles visibles que el comprador debe saber (golpes, desgaste...)
 *   - datos que faltan y que los compradores van a preguntar
 *   - si el artículo parece prohibido
 *
 * La IA NO publica nada: solo llena el formulario y el vendedor revisa.
 *
 * Variables de entorno (functions/.env):
 *   ANTHROPIC_API_KEY   llave de la API de Claude (console.anthropic.com)
 *   AI_MODEL            modelo (default claude-sonnet-5-5)
 *   AI_DAILY_LIMIT      usos por usuario por día (default 20)
 */
const functions = require("firebase-functions");
const { assertAppCheck } = require("./appcheck");
const admin = require("firebase-admin");
const Anthropic = require("@anthropic-ai/sdk");

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const { FieldValue } = admin.firestore;
const REGION = "us-central1";

/**
 * Configuración del proveedor. Se valida ESTRICTAMENTE: un valor inválido
 * (p. ej. AI_DAILY_LIMIT="abc") desactiva el asistente con un error
 * explícito, en vez de quedar sin límite o usar otro valor en silencio.
 * Solo se desactiva el asistente; el resto de la app sigue funcionando.
 */
class AiConfigError extends Error {}

function readAiConfig(env = process.env) {
  const has = (k) => env[k] !== undefined && String(env[k]).trim() !== "";
  const intIn = (k, def, min, max) => {
    if (!has(k)) return def;
    const n = Number(env[k]);
    if (!Number.isInteger(n) || n < min || n > max) {
      throw new AiConfigError(`${k} inválido: "${env[k]}" (entero de ${min} a ${max}).`);
    }
    return n;
  };
  if (!has("ANTHROPIC_API_KEY")) throw new AiConfigError("Falta ANTHROPIC_API_KEY.");
  const model = has("AI_MODEL") ? String(env.AI_MODEL).trim() : "claude-sonnet-5-5";
  if (!/^[a-z0-9][a-z0-9.\-]{2,80}$/.test(model)) {
    throw new AiConfigError(`AI_MODEL inválido: "${env.AI_MODEL}".`);
  }
  return {
    apiKey: String(env.ANTHROPIC_API_KEY).trim(),
    model,
    dailyLimit: intIn("AI_DAILY_LIMIT", 20, 1, 1000),
    // Tope de usos de TODA la plataforma por día (controla el gasto).
    globalDailyLimit: intIn("AI_GLOBAL_DAILY_LIMIT", 2000, 1, 1000000),
  };
}
const MAX_IMAGES = 4;
const MAX_IMAGE_BYTES = 1.5 * 1024 * 1024;
const ALLOWED_MIME = ["image/jpeg", "image/png", "image/webp"];

// Deben coincidir con kLotCategories de la app.
const CATEGORIES = [
  "Vehículos",
  "Ganado y caballos",
  "Maquinaria y herramientas",
  "Electrónica",
  "Hogar y muebles",
  "Joyería y relojes",
  "Arte y colección",
  "Deportes",
  "Ropa y accesorios",
  "Otros",
];

// Estado del artículo. Deben coincidir con kLotConditions de la app.
const CONDITIONS = {
  new: "Nuevo (sin usar, en empaque o sin señales de uso)",
  like_new: "Como nuevo (usado muy poco, sin detalles visibles)",
  used_good: "Usado en buen estado (desgaste normal por uso)",
  used_fair: "Usado con detalles (golpes, rayones o fallas menores)",
  for_parts: "Para reparar o refacciones (no funciona o funciona parcialmente)",
};

const SYSTEM_PROMPT = `Eres el asistente de publicación de BidStream, una plataforma mexicana de subastas en línea.
Ayudas a vendedores a describir sus artículos de forma clara, atractiva y, sobre todo, HONESTA.

Reglas obligatorias:
1. Describe SOLO lo que se ve en las fotos o lo que el vendedor dijo en sus notas. Nunca inventes marca, modelo, año, medidas, kilometraje, capacidad, materiales ni especificaciones.
2. Si algo no se distingue con claridad, dilo con "parece" o déjalo fuera. Si no puedes leer la marca o modelo, no lo pongas.
3. Respeta el estado que declaró el vendedor. Si las fotos muestran algo distinto (por ejemplo dice "nuevo" y se ven rayones), menciónalo en "detected_issues" y en "condition_mismatch".
4. Los defectos visibles SIEMPRE van en la descripción, con lenguaje neutral. Un comprador bien informado puja con confianza y no reclama después.
5. Nunca incluyas teléfonos, correos, redes sociales, direcciones ni invitaciones a tratar fuera de la plataforma.
6. Español de México, claro y sin exagerar ("increíble", "único", "imperdible" no). Nada de emojis.
7. En "missing_info" pon las preguntas que un comprador haría y que el vendedor debería responder en la descripción (por ejemplo: kilometraje, factura, si funciona, medidas, edad del animal, papeles).
8. Marca "prohibited" si el artículo parece ser: armas de fuego o municiones, drogas, medicamentos controlados, animales silvestres protegidos, documentos oficiales, artículos robados o falsificados evidentes, contenido sexual, o cualquier cosa ilegal en México.
9. Para ganado y caballos: describe lo visible (pelaje, complexión aparente) y pide en missing_info edad, registro/papeles, vacunas, guía de tránsito y certificados sanitarios.
10. Para vehículos: pide en missing_info año, kilometraje, factura (original o de aseguradora), tenencias/refrendos pagados, si es nacional o importado/legalizado.

Formato de la descripción (texto plano, con estas secciones y saltos de línea):
Qué es:
Estado:
Incluye:
Detalles a considerar:
(Omite "Incluye" si no aplica. "Detalles a considerar" siempre va; si no hay, escribe "Sin detalles visibles en las fotos.")`;

const TOOL = {
  name: "proponer_publicacion",
  description: "Propone el contenido de la publicación del lote.",
  input_schema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "Título claro, máximo 80 caracteres. Qué es + dato clave visible (marca/modelo solo si se lee).",
      },
      category: { type: "string", enum: CATEGORIES },
      description: { type: "string", description: "Descripción con las secciones indicadas, 60 a 250 palabras." },
      detected_issues: {
        type: "array",
        items: { type: "string" },
        description: "Defectos o detalles visibles en las fotos.",
      },
      missing_info: {
        type: "array",
        items: { type: "string" },
        description: "Preguntas que el vendedor debería responder (máx 5).",
      },
      condition_mismatch: {
        type: "string",
        description: "Vacío si el estado declarado coincide con las fotos; si no, explica brevemente.",
      },
      prohibited: { type: "boolean" },
      prohibited_reason: { type: "string" },
    },
    required: [
      "title",
      "category",
      "description",
      "detected_issues",
      "missing_info",
      "condition_mismatch",
      "prohibited",
      "prohibited_reason",
    ],
  },
};

// Teléfonos (10+ dígitos), correos y @usuarios: se eliminan por si acaso.
function stripContactInfo(text) {
  return String(text || "")
    .replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, "[dato de contacto eliminado]")
    .replace(/(\+?\d[\d\s().-]{8,}\d)/g, (m) =>
      m.replace(/\D/g, "").length >= 10 ? "[dato de contacto eliminado]" : m
    );
}

/** Limpia y acota la respuesta de la IA (pura, para probarla). */
function sanitizeSuggestion(raw) {
  const s = raw || {};
  const list = (v, max) =>
    (Array.isArray(v) ? v : [])
      .map((x) => stripContactInfo(String(x)).trim())
      .filter(Boolean)
      .slice(0, max);
  return {
    title: stripContactInfo(s.title).trim().slice(0, 120),
    category: CATEGORIES.includes(s.category) ? s.category : "Otros",
    description: stripContactInfo(s.description).trim().slice(0, 3000),
    detected_issues: list(s.detected_issues, 10),
    missing_info: list(s.missing_info, 5),
    condition_mismatch: stripContactInfo(s.condition_mismatch).trim().slice(0, 300),
    prohibited: s.prohibited === true,
    prohibited_reason: String(s.prohibited_reason || "").trim().slice(0, 300),
  };
}

/** Tipo real de una imagen en base64 por su firma. null si no se reconoce. */
function sniffImageType(b64) {
  let head;
  try {
    head = Buffer.from(String(b64).slice(0, 64), "base64");
  } catch (_) {
    return null;
  }
  if (head.length < 12) return null;
  if (head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff) return "image/jpeg";
  if (head[0] === 0x89 && head[1] === 0x50 && head[2] === 0x4e && head[3] === 0x47) return "image/png";
  if (head.toString("ascii", 0, 4) === "RIFF" && head.toString("ascii", 8, 12) === "WEBP") return "image/webp";
  if (head.toString("ascii", 0, 3) === "GIF") return "image/gif";
  if (head.toString("ascii", 4, 8) === "ftyp") return "heic";
  return null;
}

/** Valida las imágenes recibidas (pura, para probarla). */
function validateImages(images) {
  if (!Array.isArray(images) || images.length === 0) {
    return { ok: false, message: "Agrega al menos una foto." };
  }
  const out = [];
  for (const img of images.slice(0, MAX_IMAGES)) {
    const mime = String((img && img.mime) || "");
    const data = String((img && img.data) || "");
    if (!ALLOWED_MIME.includes(mime)) {
      return { ok: false, message: "Formato de foto no compatible (usa JPG, PNG o WEBP)." };
    }
    const bytes = Math.floor((data.length * 3) / 4);
    if (!data || bytes > MAX_IMAGE_BYTES) {
      return { ok: false, message: "Una foto es demasiado grande." };
    }
    // El tipo REAL se toma de los primeros bytes: el celular a veces dice
    // "jpeg" de una foto PNG/HEIC y el proveedor rechaza la petición (400).
    const real = sniffImageType(data);
    if (real === "heic") {
      return { ok: false, message: "Formato HEIC no compatible: toma la foto en JPG o haz captura de pantalla." };
    }
    out.push({ mime: real || mime, data });
  }
  return { ok: true, images: out };
}

/** ¿Puede este usuario usar el asistente? (mismos requisitos que publicar). */
function aiEligibilityError(user) {
  if (!user) return { code: "failed-precondition", message: "Completa tu perfil primero." };
  if (user.banned === true) return { code: "permission-denied", message: "Tu cuenta está suspendida." };
  if (user.verified !== true) {
    return {
      code: "failed-precondition",
      message: "El asistente es para vendedores con identidad verificada (INE).",
    };
  }
  return null;
}

const mxDay = () => new Date().toLocaleDateString("en-CA", { timeZone: "America/Mexico_City" });

/**
 * Revisa permisos (con el perfil fresco) y consume 1 uso del usuario y 1 de
 * la plataforma, todo en una transacción. Devuelve una función para
 * DEVOLVER el uso si la solicitud a la IA falla.
 */
async function consumeQuota(uid, cfg) {
  const day = mxDay();
  const userRef = db.collection("users").doc(uid);
  const ref = userRef.collection("ai_usage").doc(day);
  const globalRef = db.collection("ai_usage_global").doc(day);
  await db.runTransaction(async (tx) => {
    const [userSnap, snap, gSnap] = await Promise.all([tx.get(userRef), tx.get(ref), tx.get(globalRef)]);
    const err = aiEligibilityError(userSnap.exists ? userSnap.data() : null);
    if (err) throw new functions.https.HttpsError(err.code, err.message);
    const count = snap.exists ? Number(snap.data().count) || 0 : 0;
    const gCount = gSnap.exists ? Number(gSnap.data().count) || 0 : 0;
    if (count >= cfg.dailyLimit) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        `Llegaste al límite de ${cfg.dailyLimit} usos del asistente por hoy. Intenta mañana.`
      );
    }
    if (gCount >= cfg.globalDailyLimit) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "El asistente alcanzó su límite diario. Intenta mañana o escribe la descripción a mano."
      );
    }
    tx.set(ref, { count: count + 1, updated_time: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(globalRef, { count: gCount + 1, updated_time: FieldValue.serverTimestamp() }, { merge: true });
  });

  return async function refund() {
    try {
      await db.runTransaction(async (tx) => {
        const [snap, gSnap] = await Promise.all([tx.get(ref), tx.get(globalRef)]);
        const count = snap.exists ? Number(snap.data().count) || 0 : 0;
        const gCount = gSnap.exists ? Number(gSnap.data().count) || 0 : 0;
        tx.set(ref, { count: Math.max(0, count - 1), updated_time: FieldValue.serverTimestamp() }, { merge: true });
        tx.set(globalRef, { count: Math.max(0, gCount - 1), updated_time: FieldValue.serverTimestamp() }, { merge: true });
      });
    } catch (e) {
      functions.logger.error("No se pudo devolver el uso del asistente", e);
    }
  };
}

let anthropicClient = null;
let anthropicKey = null;
function client(cfg) {
  if (!anthropicClient || anthropicKey !== cfg.apiKey) {
    anthropicClient = new Anthropic({ apiKey: cfg.apiKey });
    anthropicKey = cfg.apiKey;
  }
  return anthropicClient;
}

/**
 * generateLotDescription
 * data: {
 *   images: [{ mime: 'image/jpeg', data: '<base64>' }],  (1 a 4)
 *   condition: 'new' | 'like_new' | 'used_good' | 'used_fair' | 'for_parts',
 *   notes?: string   (lo que el vendedor quiera aclarar: año, km, fallas...)
 * }
 */
exports.generateLotDescription = functions
  .region(REGION)
  .runWith({ timeoutSeconds: 120, memory: "512MB" })
  .https.onCall(async (data, context) => {
    assertAppCheck(context);
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
    }
    if (context.auth.token.email_verified !== true) {
      throw new functions.https.HttpsError("failed-precondition", "Verifica tu correo primero.");
    }
    // 1) Configuración del proveedor (antes de consumir cuota).
    let cfg;
    try {
      cfg = readAiConfig();
    } catch (err) {
      functions.logger.error(`ASISTENTE DE IA MAL CONFIGURADO: ${err.message}`);
      throw new functions.https.HttpsError(
        "failed-precondition",
        "El asistente de IA no está disponible por ahora (configuración del servidor)."
      );
    }

    // 2) Datos de entrada.
    const condition = String((data && data.condition) || "");
    if (!Object.prototype.hasOwnProperty.call(CONDITIONS, condition)) {
      throw new functions.https.HttpsError("invalid-argument", "Indica si el artículo es nuevo o usado.");
    }
    const check = validateImages(data && data.images);
    if (!check.ok) throw new functions.https.HttpsError("invalid-argument", check.message);
    const notes = stripContactInfo(String((data && data.notes) || "")).slice(0, 1000);

    // 3) Permisos (perfil fresco) + cuota, en una transacción.
    const refund = await consumeQuota(context.auth.uid, cfg);

    const content = [
      ...check.images.map((img) => ({
        type: "image",
        source: { type: "base64", media_type: img.mime, data: img.data },
      })),
      {
        type: "text",
        text:
          `Estado declarado por el vendedor: ${CONDITIONS[condition]}.\n` +
          `Notas del vendedor: ${notes || "(sin notas)"}\n\n` +
          "Propón la publicación usando la herramienta.",
      },
    ];

    // 4) Llamada al proveedor. Si falla o la respuesta no sirve, se
    //    DEVUELVE el uso consumido: el vendedor no paga por errores ajenos.
    let response;
    try {
      response = await client(cfg).messages.create({
        model: cfg.model,
        // Sonnet 5.5: piensa por defecto (adaptativo) y NO acepta tool_choice
        // forzado ("tool"/"any" → 400). Se usa "auto" y el prompt exige la
        // herramienta; el margen de tokens cubre el razonamiento.
        max_tokens: 6000,
        system: SYSTEM_PROMPT + "\n\nResponde SIEMPRE llamando a la herramienta " + TOOL.name + ", sin texto adicional.",
        tools: [TOOL],
        tool_choice: { type: "auto" },
        messages: [{ role: "user", content }],
      });
    } catch (err) {
      await refund();
      const status = Number(err && err.status) || 0;
      functions.logger.error(`Error de la API de IA (status ${status || "red"})`, {
        status,
        type: err && err.error && err.error.error ? err.error.error.type : undefined,
        message: err && err.message ? String(err.message).slice(0, 300) : String(err),
      });
      // Código corto para diagnosticar sin exponer detalles internos.
      const code = status === 401 || status === 403 ? "AI_KEY" : status === 404 ? "AI_MODEL"
        : status === 400 ? "AI_REQUEST" : status === 402 ? "AI_BILLING" : status === 429 ? "AI_RATE"
        : status >= 500 ? "AI_PROVIDER" : "AI_NETWORK";
      // Al administrador se le muestra el motivo del proveedor (diagnóstico).
      const isAdmin = !!(context.auth && context.auth.token && context.auth.token.admin === true);
      const detail = isAdmin && err && err.message ? ` [${String(err.message).slice(0, 180)}]` : "";
      throw new functions.https.HttpsError(
        "unavailable",
        `El asistente no respondió (${code}). Intenta de nuevo en un momento (no se te descontó el uso).${detail}`,
        { code }
      );
    }

    const block = (response && response.content ? response.content : []).find(
      (b) => b.type === "tool_use" && b.name === TOOL.name
    );
    const truncated = response && response.stop_reason === "max_tokens";
    const suggestion = block && !truncated ? sanitizeSuggestion(block.input) : null;
    if (!suggestion || !suggestion.title || !suggestion.description) {
      await refund();
      throw new functions.https.HttpsError(
        "unavailable",
        "El asistente no generó una propuesta completa. Intenta de nuevo (no se te descontó el uso)."
      );
    }

    // 5) Revisión humana obligatoria: el servidor NUNCA publica nada; solo
    //    devuelve la propuesta para que el vendedor la revise y corrija.
    return { ...suggestion, requires_review: true };
  });

module.exports = {
  ...module.exports,
  readAiConfig,
  AiConfigError,
  sniffImageType,
  aiEligibilityError,
  sanitizeSuggestion,
  validateImages,
  stripContactInfo,
  CATEGORIES,
  CONDITIONS,
  SYSTEM_PROMPT,
  TOOL,
};
