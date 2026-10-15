/**
 * Pago final por SPEI (Openpay) — complemento de Mercado Pago.
 *
 * Flujo:
 *  1. Al cerrar la subasta, startWinnerPayment deja el lote en
 *     payment_status = "pending" con payment_options (["mercadopago","spei"]).
 *  2. El ganador elige SPEI → chooseWinnerPaymentMethod crea UNA referencia
 *     (CLABE + referencia) en Openpay, con la misma fecha límite del pago.
 *     Llamarla otra vez devuelve la misma referencia (idempotente).
 *  3. Openpay avisa a openpayWebhook. NO se confía en el cuerpo: se consulta
 *     el cargo en Openpay y se aplica con applyProviderWinnerPayment
 *     (candado payments/openpay_{chargeId}).
 *  4. Un SPEI tardío o duplicado no se puede devolver por API: queda un
 *     reembolso "manual_required" en payments para el panel de administración.
 *
 * Respuestas tipadas: { ok: true, method, ... } o HttpsError con
 * details.code ∈ ERROR_CODES.
 */
const functions = require("firebase-functions");
const { assertAppCheck } = require("./appcheck");
const admin = require("firebase-admin");
const crypto = require("crypto");

const {
  PaymentConfigError,
  ProviderError,
  OPENPAY_DUPLICATE_ORDER,
  readOpenpayConfig,
  createOpenpayClient,
} = require("./openpay");
const pay = require("./payments");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;
const REGION = "us-central1";

const ERROR_CODES = Object.freeze({
  UNAUTHENTICATED: "UNAUTHENTICATED",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
  LOT_NOT_FOUND: "LOT_NOT_FOUND",
  NOT_WINNER: "NOT_WINNER",
  NOT_PENDING: "NOT_PENDING",
  PAYMENT_EXPIRED: "PAYMENT_EXPIRED",
  METHOD_NOT_AVAILABLE: "METHOD_NOT_AVAILABLE",
  PROVIDER_NOT_CONFIGURED: "PROVIDER_NOT_CONFIGURED",
  PROVIDER_ERROR: "PROVIDER_ERROR",
  IN_PROGRESS: "IN_PROGRESS",
});

const METHODS = ["mercadopago", "spei"];

function fail(httpsCode, code, message) {
  return new functions.https.HttpsError(httpsCode, message, { code });
}

// Permite inyectar un cliente falso en pruebas.
let clientFactory = (config) => createOpenpayClient(config);
function __setClientFactory(f) {
  clientFactory = f;
}

function getClient() {
  const config = readOpenpayConfig(); // lanza PaymentConfigError si no sirve
  return { config, client: clientFactory(config) };
}

function tsMillis(t) {
  if (!t) return null;
  if (typeof t.toMillis === "function") return t.toMillis();
  if (t instanceof Date) return t.getTime();
  return Number(t) || null;
}

function speiResponse(spei, amount, dueMs) {
  return {
    ok: true,
    method: "spei",
    clabe: spei.clabe,
    bank: spei.bank,
    reference: spei.reference,
    amount,
    dueTime: dueMs ? new Date(dueMs).toISOString() : null,
  };
}

/**
 * Lógica pura del callable (exportada para pruebas).
 * @param {{lotId: string, method: string}} data
 * @param {string|null} uid
 */
async function chooseWinnerPaymentMethodImpl(data, uid, nowMs = Date.now()) {
  if (!uid) throw fail("unauthenticated", ERROR_CODES.UNAUTHENTICATED, "Inicia sesión.");
  const lotId = String((data && data.lotId) || "");
  const method = String((data && data.method) || "");
  if (!lotId || lotId.length > 200 || lotId.includes("/")) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Lote inválido.");
  }
  if (!METHODS.includes(method)) {
    throw fail("invalid-argument", ERROR_CODES.INVALID_ARGUMENT, "Método de pago inválido.");
  }

  const lotRef = db.collection("lots").doc(lotId);

  // 1) Validar y reservar la creación (evita dos referencias SPEI simultáneas).
  const plan = await db.runTransaction(async (tx) => {
    const snap = await tx.get(lotRef);
    if (!snap.exists) throw fail("not-found", ERROR_CODES.LOT_NOT_FOUND, "Este lote ya no existe.");
    const lot = snap.data();
    if (lot.winner_uid !== uid) {
      throw fail("permission-denied", ERROR_CODES.NOT_WINNER, "Solo el ganador puede pagar este lote.");
    }
    if (lot.payment_status !== "pending") {
      throw fail(
        "failed-precondition",
        ERROR_CODES.NOT_PENDING,
        lot.payment_status === "paid" ? "Este lote ya está pagado." : "Este lote no tiene un pago pendiente."
      );
    }
    const dueMs = tsMillis(lot.payment_due_time);
    if (dueMs && dueMs <= nowMs) {
      throw fail("failed-precondition", ERROR_CODES.PAYMENT_EXPIRED, "El plazo para pagar ya venció.");
    }
    const options = Array.isArray(lot.payment_options) ? lot.payment_options : ["mercadopago"];
    if (!options.includes(method)) {
      throw fail(
        "failed-precondition",
        ERROR_CODES.METHOD_NOT_AVAILABLE,
        "Ese método de pago no está disponible para este lote."
      );
    }
    const amount = pay.round2(Number(lot.amount_due) || 0);

    if (method === "mercadopago") {
      return { kind: "mp", url: lot.winner_payment_url || null, amount, dueMs };
    }
    if (lot.spei_charge_id) {
      // Datos privados: el lote es público, la CLABE vive en payments/.
      const refSnap = await tx.get(db.collection("payments").doc(`openpay_charge_${lot.spei_charge_id}`));
      if (refSnap.exists) return { kind: "spei_existing", spei: refSnap.data(), amount, dueMs };
    }
    const creating = lot.spei_creating_until && tsMillis(lot.spei_creating_until) > nowMs;
    if (creating) {
      throw fail("aborted", ERROR_CODES.IN_PROGRESS, "Estamos generando tu referencia. Intenta en unos segundos.");
    }
    tx.update(lotRef, { spei_creating_until: Timestamp.fromMillis(nowMs + 60_000) });
    return { kind: "spei_new", lot, amount, dueMs };
  });

  if (plan.kind === "mp") {
    if (!plan.url) {
      throw fail(
        "failed-precondition",
        ERROR_CODES.PROVIDER_ERROR,
        "El cobro con Mercado Pago no está listo. Intenta en unos minutos o elige SPEI."
      );
    }
    await lotRef.update({ payment_method_chosen: "mercadopago" });
    return { ok: true, method: "mercadopago", url: plan.url, amount: plan.amount };
  }
  if (plan.kind === "spei_existing") {
    return speiResponse(plan.spei, plan.amount, plan.dueMs);
  }

  // 2) Crear la referencia en Openpay (fuera de la transacción).
  const release = () => lotRef.update({ spei_creating_until: FieldValue.delete() }).catch(() => {});
  let client;
  try {
    ({ client } = getClient());
  } catch (err) {
    await release();
    if (err instanceof PaymentConfigError) {
      functions.logger.error("SPEI sin configurar", err.message);
      throw fail("failed-precondition", ERROR_CODES.PROVIDER_NOT_CONFIGURED, "El pago por SPEI no está disponible por ahora.");
    }
    throw err;
  }

  const winnerSnap = await db.collection("users").doc(uid).get();
  const winner = winnerSnap.exists ? winnerSnap.data() : {};
  const orderId = `win_${lotId}`;
  let charge;
  try {
    charge = await client.createSpeiCharge({
      amount: plan.amount,
      description: `Subástalo Aquí - ${String(plan.lot.title || "Lote").slice(0, 80)}`,
      orderId,
      dueDate: plan.dueMs,
      customer: { name: winner.full_name || "Comprador", email: winner.email },
    });
  } catch (err) {
    await release();
    if (err instanceof ProviderError && err.providerCode === OPENPAY_DUPLICATE_ORDER) {
      // Ya existía en Openpay (p. ej. se cayó la escritura anterior): no se crea otra.
      functions.logger.error(`order_id duplicado en Openpay para ${lotId}; revisar en el panel`);
      throw fail(
        "failed-precondition",
        ERROR_CODES.PROVIDER_ERROR,
        "Ya existe una referencia SPEI para este lote. Contacta a soporte para recuperarla."
      );
    }
    functions.logger.error(`Openpay falló al crear SPEI de ${lotId}`, err);
    throw fail(
      "unavailable",
      ERROR_CODES.PROVIDER_ERROR,
      "No pudimos generar tu referencia SPEI. Intenta de nuevo o paga con Mercado Pago."
    );
  }

  const batch = db.batch();
  // En el lote (público) solo queda la marca; la CLABE va en payments/ (privado).
  batch.update(lotRef, {
    spei_charge_id: charge.id,
    payment_method_chosen: "spei",
    spei_creating_until: FieldValue.delete(),
  });
  // Índice para que el webhook encuentre el lote a partir del cargo.
  batch.set(db.collection("payments").doc(`openpay_charge_${charge.id}`), {
    kind: "spei_reference",
    provider: "openpay",
    charge_id: charge.id,
    order_id: orderId,
    lot_id: lotId,
    uid,
    amount: plan.amount,
    clabe: charge.clabe,
    bank: charge.bank,
    reference: charge.reference,
    status: "waiting",
    created_time: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return speiResponse(charge, plan.amount, plan.dueMs);
}

exports.chooseWinnerPaymentMethod = functions
  .region(REGION)
  .https.onCall((data, context) => {
    assertAppCheck(context);
    return chooseWinnerPaymentMethodImpl(data, context.auth ? context.auth.uid : null);
  });

// ---------------------------------------------------------------------
// Webhook de Openpay
// ---------------------------------------------------------------------
function safeEqual(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

function checkBasicAuth(header, config) {
  const m = /^Basic\s+(.+)$/i.exec(String(header || ""));
  if (!m) return false;
  const [user, ...rest] = Buffer.from(m[1], "base64").toString("utf8").split(":");
  return safeEqual(user, config.webhookUser) && safeEqual(rest.join(":"), config.webhookPass);
}

/**
 * Procesa una notificación ya autenticada. Devuelve el código HTTP.
 * 200 = listo/ignorado (Openpay no reintenta); 500 = reintentar.
 */
async function handleOpenpayEvent(body) {
  const type = String((body && body.type) || "");
  if (type === "verification") {
    // Openpay manda un código para confirmar el webhook en su panel.
    functions.logger.info(`Código de verificación del webhook de Openpay: ${body.verification_code}`);
    return 200;
  }
  if (type !== "charge.succeeded") return 200;

  const chargeId = String((body.transaction && body.transaction.id) || "");
  if (!chargeId) return 200;

  const indexSnap = await db.collection("payments").doc(`openpay_charge_${chargeId}`).get();
  if (!indexSnap.exists) {
    functions.logger.warn(`Cargo de Openpay desconocido: ${chargeId}`);
    return 200;
  }
  const index = indexSnap.data();

  const { client } = getClient();
  const charge = await client.getCharge(chargeId); // la fuente de verdad
  if (charge.status !== "completed" || charge.orderId !== index.order_id) {
    functions.logger.warn(`Cargo ${chargeId} no completado o no coincide (${charge.status}, ${charge.orderId})`);
    return 200;
  }

  const result = await pay.applyProviderWinnerPayment({
    provider: "openpay",
    providerPaymentId: chargeId,
    lotId: index.lot_id,
    winnerUid: index.uid,
    amount: charge.amount,
    currency: charge.currency,
  });

  if (result.action === "refund") {
    // SPEI no se reembolsa por API: queda para transferencia manual del admin.
    const batch = db.batch();
    batch.set(db.collection("payments").doc(`refund_openpay_${chargeId}`), {
      kind: "refund",
      provider: "openpay",
      charge_id: chargeId,
      uid: index.uid,
      lot_id: index.lot_id,
      amount: pay.round2(charge.amount),
      reason: result.reason,
      status: "manual_required",
      created_time: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection("users").doc(index.uid).collection("notifications").doc(), {
      type: "payment_refund_pending",
      title: "Recibimos un pago que no correspondía",
      body: "Tu transferencia llegó tarde o duplicada. Te la devolveremos por transferencia; un asesor te contactará.",
      lot_id: index.lot_id,
      read: false,
      created_time: FieldValue.serverTimestamp(),
    });
    await batch.commit();
  } else if (!result.duplicate) {
    await db.collection("payments").doc(`openpay_charge_${chargeId}`).update({ status: "paid" });
  }
  return 200;
}

exports.openpayWebhook = functions.region(REGION).https.onRequest(async (req, res) => {
  let config;
  try {
    config = readOpenpayConfig();
  } catch (err) {
    functions.logger.error("Webhook de Openpay sin configuración", err.message);
    res.status(503).send("not configured");
    return;
  }
  if (req.method !== "POST" || !checkBasicAuth(req.headers.authorization, config)) {
    res.status(401).send("unauthorized");
    return;
  }
  try {
    res.status(await handleOpenpayEvent(req.body || {})).send("ok");
  } catch (err) {
    functions.logger.error("Error procesando webhook de Openpay", err);
    res.status(500).send("retry"); // seguro: el procesamiento es idempotente
  }
});

module.exports = {
  ...module.exports,
  ERROR_CODES,
  chooseWinnerPaymentMethodImpl,
  handleOpenpayEvent,
  checkBasicAuth,
  __setClientFactory,
};
