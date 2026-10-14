const test = require("node:test");
const assert = require("node:assert");
const { validateBid, minimumNextBid } = require("../auction_logic");

const NOW = 1_700_000_000_000;
const HOUR = 3600_000;
const base = () => ({
  status: "active",
  seller_uid: "seller",
  starting_price: 1000,
  current_bid: 1000,
  minimum_increment: 100,
  bid_count: 0,
  start_time_ms: NOW - HOUR,
  end_time_ms: NOW + HOUR,
  highest_bidder_uid: null,
});

test("primera puja puede ser igual al precio inicial", () => {
  assert.strictEqual(minimumNextBid(base()), 1000);
  assert.ok(validateBid(base(), 1000, "a", NOW).ok);
});

test("después de una puja se exige el incremento", () => {
  const lot = { ...base(), bid_count: 1, current_bid: 1000, highest_bidder_uid: "a" };
  assert.strictEqual(minimumNextBid(lot), 1100);
  const r = validateBid(lot, 1050, "b", NOW);
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.minimum, 1100);
  assert.ok(validateBid(lot, 1100, "b", NOW).ok);
});

test("el vendedor no puede pujar", () => {
  assert.strictEqual(validateBid(base(), 2000, "seller", NOW).code, "permission-denied");
});

test("no se puede pujar si ya vas ganando", () => {
  const lot = { ...base(), bid_count: 1, highest_bidder_uid: "a" };
  assert.strictEqual(validateBid(lot, 5000, "a", NOW).code, "already-exists");
});

test("subasta terminada o no iniciada", () => {
  assert.strictEqual(validateBid({ ...base(), end_time_ms: NOW - 1 }, 2000, "a", NOW).ok, false);
  assert.strictEqual(validateBid({ ...base(), status: "ended" }, 2000, "a", NOW).ok, false);
  assert.strictEqual(validateBid({ ...base(), start_time_ms: NOW + 1000 }, 2000, "a", NOW).ok, false);
});

test("montos inválidos y errores de dedo", () => {
  assert.strictEqual(validateBid(base(), NaN, "a", NOW).ok, false);
  assert.strictEqual(validateBid(base(), -5, "a", NOW).ok, false);
  assert.strictEqual(validateBid(base(), 1000 * 50, "a", NOW).ok, false);
});

test("anti-francotirador extiende 2 minutos", () => {
  const lot = { ...base(), end_time_ms: NOW + 30_000 };
  const r = validateBid(lot, 1000, "a", NOW);
  assert.ok(r.ok && r.extended);
  assert.strictEqual(r.newEndTimeMs, NOW + 120_000);
  const r2 = validateBid(base(), 1000, "a", NOW);
  assert.strictEqual(r2.extended, false);
});

test("nombre público protege apellidos", () => {
  const { publicName } = require("../auction_logic");
  assert.strictEqual(publicName("Juan Pérez López"), "Juan P.");
  assert.strictEqual(publicName("Ana"), "Ana");
  assert.strictEqual(publicName(""), "Postor");
});
