const test = require("node:test");
const assert = require("node:assert");
const {
  resolveProxyBid,
  applyAntiSniping,
  legacyState,
  minimumNextBid,
  publicName,
} = require("../auction_logic");

const NOW = 1_700_000_000_000;
const HOUR = 3600_000;

function newLot(over = {}) {
  return {
    status: "active",
    seller_uid: "vendedor",
    starting_price: 1000,
    current_bid: 1000,
    minimum_increment: 100,
    bid_count: 0,
    start_time_ms: NOW - HOUR,
    end_time_ms: NOW + HOUR,
    highest_bidder_uid: null,
    ...over,
  };
}

/** Simula el servidor: aplica cada oferta como lo hace placeBid. */
function simulate(bids, lotOver = {}) {
  let lot = newLot(lotOver);
  let state = null;
  const results = [];
  for (const [uid, max, now = NOW] of bids) {
    const r = resolveProxyBid(lot, state, uid, max, now);
    results.push(r);
    if (!r.ok) continue;
    state = { leader_uid: r.newLeaderUid, leader_max: r.newLeaderMax };
    if (r.publicEvent) {
      lot = {
        ...lot,
        current_bid: r.newCurrentBid,
        bid_count: lot.bid_count + (r.outcome === "outbid" ? 2 : 1),
        highest_bidder_uid: r.newLeaderUid,
        end_time_ms: r.newEndTimeMs,
      };
    }
  }
  return { lot, state, results };
}

// ------------------------------------------------------------------
// Puja proxy
// ------------------------------------------------------------------

test("primera oferta: precio visible = precio inicial, no el máximo", () => {
  const { lot, state, results } = simulate([["ana", 5000]]);
  assert.strictEqual(results[0].outcome, "first");
  assert.strictEqual(lot.current_bid, 1000);
  assert.strictEqual(state.leader_uid, "ana");
  assert.strictEqual(state.leader_max, 5000);
});

test("primera oferta menor al precio inicial se rechaza", () => {
  const r = resolveProxyBid(newLot(), null, "ana", 999, NOW);
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.minimum, 1000);
});

test("el proxy responde por el líder superando al retador por un incremento", () => {
  // Ana máx 5000. Beto ofrece 2000 → el sistema puja 2100 por Ana.
  const { lot, state, results } = simulate([["ana", 5000], ["beto", 2000]]);
  const r = results[1];
  assert.strictEqual(r.outcome, "outbid");
  assert.strictEqual(r.bidderEffective, 2000);
  assert.strictEqual(lot.current_bid, 2100);
  assert.strictEqual(state.leader_uid, "ana");
  assert.strictEqual(r.previousLeaderEffective, 2100);
});

test("el proxy nunca rebasa el máximo secreto del líder", () => {
  // Ana máx 5000. Beto ofrece 4950 → 4950+100 = 5050 > 5000 → queda en 5000.
  const { lot, state } = simulate([["ana", 5000], ["beto", 4950]]);
  assert.strictEqual(lot.current_bid, 5000);
  assert.strictEqual(state.leader_uid, "ana");
});

test("empate de máximos: gana quien ofertó primero", () => {
  const { lot, state, results } = simulate([["ana", 5000], ["beto", 5000]]);
  assert.strictEqual(results[1].outcome, "outbid");
  assert.strictEqual(lot.current_bid, 5000);
  assert.strictEqual(state.leader_uid, "ana");
});

test("un retador con máximo mayor pasa a ganar pagando solo lo necesario", () => {
  // Ana máx 5000. Beto máx 9000 → precio 5100 (5000 + incremento).
  const { lot, state, results } = simulate([["ana", 5000], ["beto", 9000]]);
  const r = results[1];
  assert.strictEqual(r.outcome, "leading");
  assert.strictEqual(lot.current_bid, 5100);
  assert.strictEqual(state.leader_uid, "beto");
  assert.strictEqual(r.previousLeaderUid, "ana");
  assert.strictEqual(r.previousLeaderEffective, 5000);
});

test("si el nuevo máximo supera al del líder por menos de un incremento, el precio es su máximo", () => {
  // Ana máx 5000. Beto máx 5050 → min(5050, 5100) = 5050.
  const { lot, state } = simulate([["ana", 5000], ["beto", 5050]]);
  assert.strictEqual(lot.current_bid, 5050);
  assert.strictEqual(state.leader_uid, "beto");
});

test("el retador debe ofrecer al menos puja actual + incremento", () => {
  const { results } = simulate([["ana", 5000], ["beto", 2000], ["caro", 2150]]);
  // Tras Beto la puja va en 2100; Caro necesita 2200.
  const r = results[2];
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.minimum, 2200);
  // Exactamente puja actual + incremento sí se acepta.
  const { results: r2 } = simulate([["ana", 5000], ["beto", 2000], ["caro", 2200]]);
  assert.strictEqual(r2[2].ok, true);
});

test("el líder puede subir su máximo sin mover precio ni cierre", () => {
  const end = NOW + 10_000; // dentro de la ventana anti-sniping
  const { lot, state, results } = simulate([["ana", 5000, NOW], ["ana", 8000, NOW + 1]], {
    end_time_ms: end,
  });
  const r = results[1];
  assert.strictEqual(r.outcome, "max_raised");
  assert.strictEqual(r.publicEvent, false);
  assert.strictEqual(r.extended, false);
  assert.strictEqual(state.leader_max, 8000);
  assert.strictEqual(lot.current_bid, 1000);
});

test("el líder no puede bajar ni repetir su máximo", () => {
  const { results } = simulate([["ana", 5000], ["ana", 4000]]);
  assert.strictEqual(results[1].ok, false);
  assert.strictEqual(results[1].code, "already-exists");
});

test("guerra de pujas: el resultado es el segundo máximo + incremento", () => {
  const { lot, state } = simulate([
    ["ana", 3000],
    ["beto", 2500], // proxy de Ana responde 2600
    ["caro", 7000], // Caro gana a 3100
    ["ana", 6000], // proxy de Caro responde 6100
    ["beto", 6500], // proxy de Caro responde 6600
  ]);
  assert.strictEqual(state.leader_uid, "caro");
  assert.strictEqual(lot.current_bid, 6600);
});

test("centavos sin errores de punto flotante", () => {
  const { lot } = simulate([["ana", 10.3], ["beto", 10.2]], {
    starting_price: 10.1,
    current_bid: 10.1,
    minimum_increment: 0.1,
  });
  assert.strictEqual(lot.current_bid, 10.3);
});

test("validaciones generales", () => {
  assert.strictEqual(resolveProxyBid(newLot(), null, "vendedor", 2000, NOW).code, "permission-denied");
  assert.strictEqual(resolveProxyBid(newLot({ status: "ended" }), null, "a", 2000, NOW).ok, false);
  assert.strictEqual(resolveProxyBid(newLot({ end_time_ms: NOW }), null, "a", 2000, NOW).ok, false);
  assert.strictEqual(resolveProxyBid(newLot({ start_time_ms: NOW + 1 }), null, "a", 2000, NOW).ok, false);
  assert.strictEqual(resolveProxyBid(newLot(), null, "a", NaN, NOW).ok, false);
  assert.strictEqual(resolveProxyBid(newLot(), null, "a", -1, NOW).ok, false);
  assert.strictEqual(resolveProxyBid(newLot(), null, "a", 60_000_000, NOW).ok, false);
});

test("lotes antiguos sin estado privado se reconstruyen", () => {
  const lot = newLot({ bid_count: 3, current_bid: 1500, highest_bidder_uid: "ana" });
  const state = legacyState(lot);
  assert.deepStrictEqual(
    { uid: state.leader_uid, max: state.leader_max },
    { uid: "ana", max: 1500 }
  );
  const r = resolveProxyBid(lot, state, "beto", 1600, NOW);
  assert.strictEqual(r.outcome, "leading");
  assert.strictEqual(r.newCurrentBid, 1600);
  assert.strictEqual(legacyState(newLot()), null);
});

// ------------------------------------------------------------------
// Anti-sniping de 40 segundos
// ------------------------------------------------------------------

test("anti-sniping: con 40 s o menos, cierre = ahora + 40 s", () => {
  for (const left of [40_000, 30_000, 5_000, 1]) {
    assert.deepStrictEqual(applyAntiSniping(NOW + left, NOW), {
      newEndTimeMs: NOW + 40_000,
      extended: true,
    });
  }
});

test("anti-sniping: con más de 40 s o ya vencido, no cambia", () => {
  assert.strictEqual(applyAntiSniping(NOW + 40_001, NOW).extended, false);
  assert.strictEqual(applyAntiSniping(NOW, NOW).extended, false);
  assert.strictEqual(applyAntiSniping(NOW - 1, NOW).extended, false);
});

test("una oferta válida a 10 s del cierre extiende la subasta", () => {
  const { lot, results } = simulate([["ana", 5000, NOW], ["beto", 2000, NOW + 50_000]], {
    end_time_ms: NOW + 60_000,
  });
  assert.strictEqual(results[1].extended, true);
  assert.strictEqual(lot.end_time_ms, NOW + 50_000 + 40_000);
});

test("una oferta rechazada no extiende la subasta", () => {
  const { lot } = simulate([["ana", 5000, NOW], ["beto", 500, NOW + 290_000]], {
    end_time_ms: NOW + 300_000,
  });
  assert.strictEqual(lot.end_time_ms, NOW + 300_000);
});

// ------------------------------------------------------------------
// Utilidades
// ------------------------------------------------------------------

test("mínimo siguiente", () => {
  assert.strictEqual(minimumNextBid(newLot()), 1000);
  assert.strictEqual(minimumNextBid(newLot({ bid_count: 1, current_bid: 1200 })), 1300);
});

test("nombre público protege apellidos", () => {
  assert.strictEqual(publicName("Juan Pérez López"), "Juan P.");
  assert.strictEqual(publicName("Ana"), "Ana");
  assert.strictEqual(publicName(""), "Postor");
});

// ------------------------------------------------------------------
// Integridad del lote (hallazgo de auditoría: incremento negativo)
// ------------------------------------------------------------------

test("AUDITORÍA: incremento negativo ya no puede bajar el precio de 1000 a menos", () => {
  const lot = newLot({ bid_count: 1, highest_bidder_uid: "ana", minimum_increment: -200 });
  const state = { leader_uid: "ana", leader_max: 5000 };
  const r = resolveProxyBid(lot, state, "beto", 800, NOW);
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.integrity, true);
  // incremento 0 también se rechaza
  assert.strictEqual(resolveProxyBid(newLot({ minimum_increment: 0 }), null, "a", 1000, NOW).ok, false);
});

test("rechaza importes inválidos en el lote", () => {
  const bad = [
    { starting_price: -5, current_bid: -5 },
    { starting_price: NaN, current_bid: NaN },
    { starting_price: "1000", current_bid: "1000" },
    { current_bid: 900 }, // menor al precio inicial
    { current_bid: 1200, bid_count: 0 }, // sin pujas pero precio movido
    { minimum_increment: Infinity },
  ];
  for (const over of bad) {
    const r = resolveProxyBid(newLot(over), null, "a", 5000, NOW);
    assert.strictEqual(r.ok, false, JSON.stringify(over));
  }
});

test("rechaza estados inconsistentes", () => {
  // estado desconocido
  assert.strictEqual(resolveProxyBid(newLot({ status: "hacked" }), null, "a", 5000, NOW).ok, false);
  // con pujas pero sin líder
  assert.strictEqual(resolveProxyBid(newLot({ bid_count: 2 }), null, "a", 5000, NOW).ok, false);
  // estado privado no coincide con el líder del lote
  const lot = newLot({ bid_count: 1, highest_bidder_uid: "ana", current_bid: 1500 });
  assert.strictEqual(
    resolveProxyBid(lot, { leader_uid: "caro", leader_max: 9000 }, "beto", 5000, NOW).ok,
    false
  );
  // máximo del líder menor al precio visible
  assert.strictEqual(
    resolveProxyBid(lot, { leader_uid: "ana", leader_max: 1000 }, "beto", 5000, NOW).ok,
    false
  );
  // fechas invertidas
  assert.strictEqual(
    resolveProxyBid(newLot({ start_time_ms: NOW + 10, end_time_ms: NOW + 5 }), null, "a", 5000, NOW).ok,
    false
  );
  // conteo de pujas no entero
  assert.strictEqual(resolveProxyBid(newLot({ bid_count: 1.5 }), null, "a", 5000, NOW).ok, false);
});

test("propiedad: en 2000 ofertas aleatorias el precio nunca baja ni rebasa el máximo del líder", () => {
  let seed = 42;
  const rand = () => ((seed = (seed * 1103515245 + 12345) % 2 ** 31) / 2 ** 31);
  const users = ["a", "b", "c", "d"];
  for (let run = 0; run < 50; run++) {
    let lot = newLot({ starting_price: 100, current_bid: 100, minimum_increment: 1 + Math.floor(rand() * 50) });
    let state = null;
    for (let i = 0; i < 40; i++) {
      const uid = users[Math.floor(rand() * users.length)];
      const max = Math.round(lot.current_bid + rand() * 500 - 50);
      const before = lot.current_bid;
      const r = resolveProxyBid(lot, state, uid, max, NOW);
      if (!r.ok) continue;
      assert.ok(r.newCurrentBid >= before, "el precio bajó");
      assert.ok(r.newCurrentBid <= r.newLeaderMax, "rebasó el máximo del líder");
      state = { leader_uid: r.newLeaderUid, leader_max: r.newLeaderMax };
      if (r.publicEvent) {
        lot = {
          ...lot,
          current_bid: r.newCurrentBid,
          bid_count: lot.bid_count + (r.outcome === "outbid" ? 2 : 1),
          highest_bidder_uid: r.newLeaderUid,
        };
      }
    }
  }
});
