/** Mercado Pago falso: registra llamadas y permite fijar respuestas. */
const calls = { preferences: [], refunds: [], gets: [] };
const payments = new Map(); // id -> objeto de pago
let failPreference = false;
const refundKeys = new Set();

class MercadoPagoConfig {
  constructor(o) { this.o = o; }
}
class Preference {
  async create({ body }) {
    if (failPreference) throw new Error("MP caído");
    calls.preferences.push(body);
    const id = `pref_${calls.preferences.length}`;
    return { id, init_point: `https://mp.test/checkout/${id}` };
  }
}
class Payment {
  async get({ id }) {
    calls.gets.push(id);
    const p = payments.get(String(id));
    if (!p) throw new Error("no existe");
    return p;
  }
}
class PaymentRefund {
  async create({ payment_id, body, requestOptions }) {
    const key = requestOptions && requestOptions.idempotencyKey;
    if (key && refundKeys.has(key)) return { id: "dup", idempotent: true };
    if (key) refundKeys.add(key);
    calls.refunds.push({ payment_id: String(payment_id), amount: body && body.amount });
    return { id: `ref_${calls.refunds.length}` };
  }
}

module.exports = {
  MercadoPagoConfig,
  Preference,
  Payment,
  PaymentRefund,
  __calls: calls,
  __payments: payments,
  __setFailPreference(v) { failPreference = v; },
  __reset() {
    calls.preferences.length = 0;
    calls.refunds.length = 0;
    calls.gets.length = 0;
    payments.clear();
    refundKeys.clear();
    failPreference = false;
  },
};
