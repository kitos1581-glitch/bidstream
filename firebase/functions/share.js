/**
 * Tarjeta para compartir un lote (WhatsApp, Facebook, X).
 *
 * Los rastreadores de redes sociales no ejecutan la app Flutter, así que no
 * ven las etiquetas Open Graph. Esta función responde /l/{lotId} con HTML
 * mínimo (og:title, og:description, og:image = primera foto) y redirige a
 * las personas al detalle del lote en la app.
 * Firebase Hosting enruta /l/** a esta función (ver firebase.json).
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// Mientras siga en vista previa, también se pide no indexar estas páginas.
const NOINDEX = String(process.env.SEO_NOINDEX || "true").toLowerCase() !== "false";

function esc(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function money(n) {
  return "$" + Number(n || 0).toLocaleString("es-MX", { maximumFractionDigits: 0 }) + " MXN";
}

/** HTML de la tarjeta (función pura, se prueba sin Firestore). */
function renderLotCard(lotId, lot, origin) {
  const appUrl = `${origin}/lotDetailView?lotId=${encodeURIComponent(lotId)}`;
  if (!lot) {
    return {
      status: 404,
      html: `<!doctype html><html lang="es-MX"><head><meta charset="utf-8"><title>Lote no encontrado · Subástalo Aquí</title><meta http-equiv="refresh" content="0;url=${esc(origin)}/"></head><body>Lote no encontrado.</body></html>`,
    };
  }
  const title = `${lot.title || "Lote"} · Subástalo Aquí`;
  const price = money(lot.current_bid || lot.starting_price);
  const desc =
    lot.status === "active"
      ? `Puja actual ${price}. ${String(lot.description || "").replace(/\s+/g, " ").slice(0, 150)}`
      : `Subasta terminada. ${String(lot.category || "")}`;
  const image = (Array.isArray(lot.image_urls) ? lot.image_urls : []).find((u) => /^https:\/\//.test(u));
  const html = `<!doctype html>
<html lang="es-MX"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
${NOINDEX ? '<meta name="robots" content="noindex">' : ""}
<meta name="description" content="${esc(desc)}">
<link rel="canonical" href="${esc(appUrl)}">
<meta property="og:type" content="product">
<meta property="og:site_name" content="Subástalo Aquí">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}">
<meta property="og:url" content="${esc(appUrl)}">
${image ? `<meta property="og:image" content="${esc(image)}">` : ""}
<meta name="twitter:card" content="${image ? "summary_large_image" : "summary"}">
<meta http-equiv="refresh" content="0;url=${esc(appUrl)}">
</head><body><a href="${esc(appUrl)}">Ver el lote en Subástalo Aquí</a></body></html>`;
  return { status: 200, html };
}

exports.lotPreview = functions.region("us-central1").https.onRequest(async (req, res) => {
  const m = /^\/l\/([A-Za-z0-9_-]{1,128})\/?$/.exec(req.path || "");
  const origin = `https://${req.get("x-forwarded-host") || req.get("host")}`;
  if (!m) {
    res.redirect(302, origin + "/");
    return;
  }
  try {
    const snap = await db.collection("lots").doc(m[1]).get();
    const { status, html } = renderLotCard(m[1], snap.exists ? snap.data() : null, origin);
    res.set("Cache-Control", "public, max-age=300, s-maxage=600");
    res.status(status).type("html").send(html);
  } catch (err) {
    functions.logger.error("lotPreview", err);
    res.redirect(302, origin + "/");
  }
});

module.exports = { ...module.exports, renderLotCard, esc };
