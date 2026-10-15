/**
 * Cliente mínimo de Openpay (México) para cobros por SPEI.
 *
 * - Sin dependencias: usa fetch (Node 20). En pruebas se inyecta un fetch falso.
 * - Errores tipados: PaymentConfigError (configuración) y ProviderError (Openpay).
 * - Configuración estricta: si falta o es inválida, se lanza un error explícito;
 *   nunca se "adivina" un valor ni se cambia de ambiente en silencio.
 *
 * Variables (.env de functions):
 *   OPENPAY_MERCHANT_ID   id del comercio (dashboard de Openpay)
 *   OPENPAY_PRIVATE_KEY   llave privada (sk_...). NUNCA en la app.
 *   OPENPAY_SANDBOX       "true" (pruebas) | "false" (producción). Obligatoria.
 *   OPENPAY_WEBHOOK_USER  usuario y contraseña que se configuran en el webhook
 *   OPENPAY_WEBHOOK_PASS  de Openpay (autenticación básica).
 */
class PaymentConfigError extends Error {
  constructor(message) {
    super(message);
    this.name = "PaymentConfigError";
  }
}

class ProviderError extends Error {
  /**
   * @param {string} message
   * @param {{provider: string, httpStatus?: number, providerCode?: number|string,
   *          retryable?: boolean, requestId?: string}} info
   */
  constructor(message, info) {
    super(message);
    this.name = "ProviderError";
    this.provider = info.provider;
    this.httpStatus = info.httpStatus;
    this.providerCode = info.providerCode;
    this.retryable = Boolean(info.retryable);
    this.requestId = info.requestId;
  }
}

/** Códigos de Openpay que nos importan. */
const OPENPAY_DUPLICATE_ORDER = 1006;

function readOpenpayConfig(env = process.env) {
  const merchantId = String(env.OPENPAY_MERCHANT_ID || "").trim();
  const privateKey = String(env.OPENPAY_PRIVATE_KEY || "").trim();
  const sandboxRaw = String(env.OPENPAY_SANDBOX || "").trim().toLowerCase();
  const webhookUser = String(env.OPENPAY_WEBHOOK_USER || "").trim();
  const webhookPass = String(env.OPENPAY_WEBHOOK_PASS || "").trim();

  if (!merchantId && !privateKey) {
    throw new PaymentConfigError("SPEI no está configurado (faltan OPENPAY_MERCHANT_ID y OPENPAY_PRIVATE_KEY).");
  }
  if (!/^[a-z0-9]{10,40}$/i.test(merchantId)) {
    throw new PaymentConfigError("OPENPAY_MERCHANT_ID inválido.");
  }
  if (!/^sk_[a-z0-9]{10,}$/i.test(privateKey)) {
    throw new PaymentConfigError("OPENPAY_PRIVATE_KEY inválida (debe empezar con sk_).");
  }
  if (sandboxRaw !== "true" && sandboxRaw !== "false") {
    throw new PaymentConfigError('OPENPAY_SANDBOX debe ser "true" o "false".');
  }
  if (webhookUser.length < 6 || webhookPass.length < 16) {
    throw new PaymentConfigError(
      "OPENPAY_WEBHOOK_USER (≥6) y OPENPAY_WEBHOOK_PASS (≥16 caracteres) son obligatorios."
    );
  }
  const sandbox = sandboxRaw === "true";
  return {
    merchantId,
    privateKey,
    sandbox,
    webhookUser,
    webhookPass,
    baseUrl: `${sandbox ? "https://sandbox-api.openpay.mx" : "https://api.openpay.mx"}/v1/${merchantId}`,
  };
}

/** true si la configuración es válida (para ofrecer o no la opción SPEI). */
function openpayConfigured(env = process.env) {
  try {
    readOpenpayConfig(env);
    return true;
  } catch (_) {
    return false;
  }
}

function toAmount(n) {
  const v = Math.round(Number(n) * 100) / 100;
  if (!Number.isFinite(v) || v <= 0) throw new ProviderError("Monto inválido.", { provider: "openpay" });
  return v;
}

/**
 * @param {ReturnType<typeof readOpenpayConfig>} config
 * @param {{fetchImpl?: typeof fetch, timeoutMs?: number}} [opts]
 */
function createOpenpayClient(config, opts = {}) {
  const fetchImpl = opts.fetchImpl || globalThis.fetch;
  const timeoutMs = opts.timeoutMs || 15000;
  const auth = "Basic " + Buffer.from(`${config.privateKey}:`).toString("base64");

  async function call(method, path, body) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    let res;
    try {
      res = await fetchImpl(`${config.baseUrl}${path}`, {
        method,
        headers: { Authorization: auth, "Content-Type": "application/json" },
        body: body ? JSON.stringify(body) : undefined,
        signal: ctrl.signal,
      });
    } catch (err) {
      throw new ProviderError(`Openpay no respondió: ${err.message || err}`, {
        provider: "openpay",
        retryable: true,
      });
    } finally {
      clearTimeout(timer);
    }
    let json = null;
    try {
      json = await res.json();
    } catch (_) {
      json = null;
    }
    if (!res.ok) {
      throw new ProviderError((json && json.description) || `Openpay respondió ${res.status}`, {
        provider: "openpay",
        httpStatus: res.status,
        providerCode: json && json.error_code,
        requestId: json && json.request_id,
        retryable: res.status >= 500 || res.status === 429,
      });
    }
    return json;
  }

  return {
    /**
     * Crea una referencia SPEI (cargo "bank_account"). order_id es único en
     * Openpay: repetirlo devuelve error 1006, lo que evita cobros dobles.
     * @returns {Promise<{id: string, status: string, amount: number,
     *   clabe: string, bank: string, reference: string, dueDate: string|null}>}
     */
    async createSpeiCharge({ amount, description, orderId, dueDate, customer }) {
      const json = await call("POST", "/charges", {
        method: "bank_account",
        amount: toAmount(amount),
        description: String(description || "").slice(0, 250),
        order_id: orderId,
        due_date: dueDate ? new Date(dueDate).toISOString() : undefined,
        customer: {
          name: String((customer && customer.name) || "Comprador").slice(0, 100),
          email: (customer && customer.email) || undefined,
        },
      });
      const pm = (json && json.payment_method) || {};
      if (!json || !json.id || !pm.clabe) {
        throw new ProviderError("Openpay no devolvió la CLABE de pago.", { provider: "openpay" });
      }
      return {
        id: String(json.id),
        status: String(json.status || ""),
        amount: Number(json.amount),
        clabe: String(pm.clabe),
        bank: String(pm.bank || ""),
        reference: String(pm.name || ""),
        dueDate: json.due_date || null,
      };
    },

    /** Consulta un cargo (para no confiar en el cuerpo del webhook). */
    async getCharge(id) {
      const json = await call("GET", `/charges/${encodeURIComponent(id)}`);
      return {
        id: String(json.id),
        status: String(json.status || ""),
        method: String(json.method || ""),
        amount: Number(json.amount),
        currency: String(json.currency || "MXN").toUpperCase(),
        orderId: String(json.order_id || ""),
        // Comisión de Openpay por este cargo (con IVA), si la reporta.
        fee: json.fee && Number.isFinite(Number(json.fee.amount))
          ? Math.round((Number(json.fee.amount) + (Number(json.fee.tax) || 0)) * 100) / 100
          : null,
      };
    },
  };
}

module.exports = {
  PaymentConfigError,
  ProviderError,
  OPENPAY_DUPLICATE_ORDER,
  readOpenpayConfig,
  openpayConfigured,
  createOpenpayClient,
};
