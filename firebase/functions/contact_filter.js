/**
 * Filtro de datos de contacto en publicaciones (evitar que se brinquen la
 * plataforma): teléfonos (con espacios, puntos, guiones o escritos en letra),
 * correos, WhatsApp/Telegram, redes sociales y "@usuario".
 *
 * Si un lote activo trae datos de contacto en título, descripción o
 * características, pasa a status "review" (no se ve en el catálogo ni acepta
 * pujas) y se avisa al vendedor. Al corregirlo, regresa solo a "active".
 * Las fotos (OCR) se revisan en una etapa posterior.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue } = admin.firestore;
const REGION = "us-central1";

const NUM_WORDS = [
  "cero", "uno", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve",
];

function normalize(s) {
  return String(s || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "");
}

/** Devuelve la lista de motivos encontrados (vacía si el texto está limpio). */
function findContactInfo(text) {
  const t = normalize(text);
  const reasons = new Set();

  // Teléfono: 10+ dígitos seguidos, permitiendo separadores entre ellos
  // (614 123 4567, 614-123-45-67, (614) 123.4567, +52 1 614...).
  const digitsRuns = t.match(/\+?\d(?:[\s.\-()/]{0,2}\d){9,}/g) || [];
  if (digitsRuns.some((r) => r.replace(/\D/g, "").length >= 10 && r.replace(/\D/g, "").length <= 13)) {
    reasons.add("phone");
  }
  // Teléfono en letra: 7+ números escritos seguidos ("seis uno cuatro ...").
  const words = t.split(/[^a-z0-9]+/).filter(Boolean);
  let run = 0;
  for (const w of words) {
    if (NUM_WORDS.includes(w) || /^\d$/.test(w)) {
      run++;
      if (run >= 7) {
        reasons.add("phone");
        break;
      }
    } else {
      run = 0;
    }
  }
  // Correo (también "arroba" / "punto com").
  if (/[a-z0-9._%+-]+\s*@\s*[a-z0-9-]+\s*\.\s*[a-z]{2,}/.test(t) || /\barroba\b/.test(t)) reasons.add("email");
  // Mensajería.
  if (/\b(whats\s*app|whatsapp|whats|wats|wasap|guasap|wsp|wpp|telegram)\b/.test(t) || /wa\.me|t\.me\//.test(t)) {
    reasons.add("messaging");
  }
  // Redes y enlaces.
  if (/(facebook\.com|fb\.com|fb\.me|m\.me\/|instagram\.com|tiktok\.com|marketplace)/.test(t)) reasons.add("social");
  // "@usuario" suelto (no correo).
  if (/(^|[\s(])@[a-z0-9_.]{3,}/.test(t)) reasons.add("handle");
  // Frases típicas para sacar la venta.
  if (/\b(inbox|mandame (un )?(mensaje|msj|whats)|llamame|marcame|escribeme al|mi (cel|numero|telefono))\b/.test(t)) {
    reasons.add("contact_phrase");
  }
  return [...reasons];
}

function lotText(lot) {
  const specs = lot && lot.specs && typeof lot.specs === "object" ? Object.values(lot.specs).join(" \n ") : "";
  return [lot.title, lot.description, specs].filter(Boolean).join(" \n ");
}

/** Decide qué hacer con un lote. Devuelve null o el patch a aplicar. */
function moderationPatch(lot) {
  if (!lot || !["active", "review"].includes(lot.status)) return null;
  const reasons = findContactInfo(lotText(lot));
  if (reasons.length && lot.status === "active") {
    return { status: "review", moderation: { kind: "contact_info", reasons } };
  }
  if (!reasons.length && lot.status === "review" && lot.moderation && lot.moderation.kind === "contact_info") {
    return { status: "active", moderation: FieldValue.delete() };
  }
  return null;
}

const REASON_TEXT = {
  phone: "teléfono",
  email: "correo",
  messaging: "WhatsApp o mensajería",
  social: "redes sociales o enlaces",
  handle: "usuario de redes (@)",
  contact_phrase: "frases para contactar por fuera",
};

exports.onLotModerate = functions
  .region(REGION)
  .firestore.document("lots/{lotId}")
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    const patch = moderationPatch(after);
    if (!patch) return null;
    await change.after.ref.update(patch);
    if (patch.status === "review") {
      const what = patch.moderation.reasons.map((r) => REASON_TEXT[r] || r).join(", ");
      await db
        .collection("users")
        .doc(after.seller_uid)
        .collection("notifications")
        .add({
          type: "lot_review",
          title: "Tu publicación está en revisión",
          body: `"${after.title}" tiene datos de contacto (${what}). Mientras tanto no se ve ni recibe pujas. Bórrala y vuelve a publicarla sin esos datos (si la corriges, se publica sola). Los contactos se comparten después del pago.`,
          lot_id: context.params.lotId,
          read: false,
          created_time: FieldValue.serverTimestamp(),
        });
    }
    return null;
  });

module.exports = { ...module.exports, findContactInfo, moderationPatch, lotText };
