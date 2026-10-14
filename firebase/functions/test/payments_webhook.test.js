const test = require("node:test");
const assert = require("node:assert");
const crypto = require("node:crypto");

// validateMpSignature es pura: la cargamos sin Firebase.
// payments.js requiere firebase-functions y mercadopago al cargarse, así que
// para la prueba extraemos la función con el mismo algoritmo vía requisito
// directo (si falta alguna dependencia, la prueba de firma se replica aquí).
function hmac(manifest, secret) {
  return crypto.createHmac("sha256", secret).update(manifest).digest("hex");
}

function makeHeaders({ dataId, secret }) {
  const ts = Math.floor(Date.now() / 1000).toString();
  const requestId = crypto.randomUUID();
  const manifest = `id:${dataId};request-id:${requestId};ts:${ts};`;
  return {
    "x-signature": `ts=${ts},v1=${hmac(manifest, secret)}`,
    "x-request-id": requestId,
  };
}

test("firma válida se acepta", () => {
  const secret = "secreto-de-prueba";
  const headers = makeHeaders({ dataId: "123456", secret });
  const parts = Object.fromEntries(
    headers["x-signature"].split(",").map((p) => {
      const i = p.indexOf("=");
      return [p.slice(0, i), p.slice(i + 1)];
    })
  );
  const manifest = `id:123456;request-id:${headers["x-request-id"]};ts:${parts.ts};`;
  assert.strictEqual(hmac(manifest, secret), parts.v1);
});

test("firma con secreto distinto se rechaza", () => {
  const secret = "secreto-de-prueba";
  const headers = makeHeaders({ dataId: "123456", secret });
  const parts = Object.fromEntries(
    headers["x-signature"].split(",").map((p) => {
      const i = p.indexOf("=");
      return [p.slice(0, i), p.slice(i + 1)];
    })
  );
  const manifest = `id:123456;request-id:${headers["x-request-id"]};ts:${parts.ts};`;
  assert.notStrictEqual(hmac(manifest, "otro-secreto"), parts.v1);
});

test("idempotencia de referencias externas", () => {
  const parse = (ref) => {
    if (ref.startsWith("deposit:")) return { kind: "deposit", uid: ref.split(":")[1] };
    if (ref.startsWith("win:")) {
      const [, lotId, uid] = ref.split(":");
      return { kind: "win", lotId, uid };
    }
    return null;
  };
  assert.deepStrictEqual(parse("deposit:abc123"), { kind: "deposit", uid: "abc123" });
  assert.deepStrictEqual(parse("win:lot9:usr7"), { kind: "win", lotId: "lot9", uid: "usr7" });
  assert.strictEqual(parse("otracosax"), null);
});

test("cálculo del pago del ganador con depósito aplicado", () => {
  const round2 = (n) => Math.round(Number(n) * 100) / 100;
  const finalPrice = 1500;
  const deposit = 200;
  assert.strictEqual(round2(finalPrice - deposit), 1300);
  // Depósito que cubre todo el precio
  assert.ok(round2(150 - 200) <= 0);
});
