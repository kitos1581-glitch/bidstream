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
const admin = require("firebase-admin");
const Anthropic = require("@anthropic-ai/sdk");

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const { FieldValue } = admin.firestore;
const REGION = "us-central1";

const AI_MODEL = process.env.AI_MODEL || "claude-sonnet-5-5";
const AI_DAILY_LIMIT = Number(process.env.AI_DAILY_LIMIT || 20);
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
    out.push({ mime, data });
  }
  return { ok: true, images: out };
}

/** Cuenta usos por usuario por día (zona México). Lanza error si excede. */
async function consumeDailyQuota(uid) {
  const day = new Date().toLocaleDateString("en-CA", { timeZone: "America/Mexico_City" });
  const ref = db.collection("users").doc(uid).collection("ai_usage").doc(day);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = snap.exists ? Number(snap.data().count) || 0 : 0;
    if (count >= AI_DAILY_LIMIT) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        `Llegaste al límite de ${AI_DAILY_LIMIT} usos del asistente por hoy. Intenta mañana.`
      );
    }
    tx.set(ref, { count: count + 1, updated_time: FieldValue.serverTimestamp() }, { merge: true });
  });
}

let anthropicClient = null;
function client() {
  if (!process.env.ANTHROPIC_API_KEY) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "El asistente de IA no está configurado en el servidor."
    );
  }
  anthropicClient = anthropicClient || new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
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
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Inicia sesión.");
    }
    if (context.auth.token.email_verified !== true) {
      throw new functions.https.HttpsError("failed-precondition", "Verifica tu correo primero.");
    }
    const condition = String((data && data.condition) || "");
    if (!CONDITIONS[condition]) {
      throw new functions.https.HttpsError("invalid-argument", "Indica si el artículo es nuevo o usado.");
    }
    const check = validateImages(data && data.images);
    if (!check.ok) throw new functions.https.HttpsError("invalid-argument", check.message);
    const notes = stripContactInfo(String((data && data.notes) || "")).slice(0, 1000);

    await consumeDailyQuota(context.auth.uid);

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

    let response;
    try {
      response = await client().messages.create({
        model: AI_MODEL,
        max_tokens: 1500,
        system: SYSTEM_PROMPT,
        tools: [TOOL],
        tool_choice: { type: "tool", name: TOOL.name },
        messages: [{ role: "user", content }],
      });
    } catch (err) {
      functions.logger.error("Error de la API de IA", err);
      throw new functions.https.HttpsError(
        "unavailable",
        "El asistente no respondió. Intenta de nuevo en un momento."
      );
    }

    const block = (response.content || []).find((b) => b.type === "tool_use");
    if (!block) {
      throw new functions.https.HttpsError("internal", "El asistente no generó una propuesta.");
    }
    return sanitizeSuggestion(block.input);
  });

module.exports = {
  ...module.exports,
  sanitizeSuggestion,
  validateImages,
  stripContactInfo,
  CATEGORIES,
  CONDITIONS,
  SYSTEM_PROMPT,
  TOOL,
};
