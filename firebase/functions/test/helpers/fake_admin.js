/**
 * Firestore falso en memoria para probar index.js sin emulador.
 * Implementa transacciones optimistas: si un documento leído cambió antes
 * de confirmar, la transacción se reintenta (como Firestore real).
 */
class Timestamp {
  constructor(ms) { this.ms = ms; }
  toMillis() { return this.ms; }
  toDate() { return new Date(this.ms); }
  static fromMillis(ms) { return new Timestamp(ms); }
  static fromDate(d) { return new Timestamp(d.getTime()); }
  static now() { return new Timestamp(Date.now()); }
}
const FieldValue = {
  increment: (n) => ({ __op: "inc", n }),
  serverTimestamp: () => ({ __op: "ts" }),
  delete: () => ({ __op: "del" }),
};

let autoId = 0;
const store = new Map(); // path -> { data, version }

function applyWrite(path, data, { merge = false, update = false } = {}) {
  const prev = store.get(path);
  if (update && !prev) throw new Error(`NOT_FOUND: ${path}`);
  const base = merge || update ? { ...(prev ? prev.data : {}) } : {};
  for (const [k, v] of Object.entries(data)) {
    if (v && v.__op === "inc") base[k] = (base[k] || 0) + v.n;
    else if (v && v.__op === "ts") base[k] = Timestamp.now();
    else if (v && v.__op === "del") delete base[k];
    else base[k] = v;
  }
  store.set(path, { data: base, version: (prev ? prev.version : 0) + 1 });
}

function snap(ref) {
  const e = store.get(ref.path);
  return { id: ref.id, ref, exists: !!e, data: () => (e ? { ...e.data } : undefined) };
}

const tick = () => new Promise((r) => setImmediate(r));

function docRef(path) {
  const id = path.split("/").pop();
  return {
    id,
    path,
    collection: (name) => colRef(`${path}/${name}`),
    get: async () => { await tick(); return snap(docRef(path)); },
    set: async (data, opts) => { await tick(); applyWrite(path, data, opts); },
    update: async (data) => { await tick(); applyWrite(path, data, { update: true }); },
  };
}

function colRef(path) {
  const filters = [];
  const q = {
    path,
    doc: (id) => docRef(`${path}/${id || `auto${++autoId}`}`),
    where: (f, op, v) => { filters.push([f, op, v]); return q; },
    orderBy: () => q,
    limit: () => q,
    get: async () => {
      await tick();
      const docs = [];
      for (const [p, e] of store) {
        const rest = p.slice(path.length + 1);
        if (!p.startsWith(path + "/") || rest.includes("/")) continue;
        const ok = filters.every(([f, op, v]) => {
          const x = e.data[f];
          const val = (y) => (y instanceof Timestamp ? y.ms : y);
          if (op === "==") return val(x) === val(v);
          if (op === "<=") return val(x) <= val(v);
          return true;
        });
        if (ok) docs.push(snap(docRef(p)));
      }
      return { docs, size: docs.length, empty: docs.length === 0 };
    },
  };
  return q;
}

const db = {
  collection: (name) => colRef(name),
  batch: () => {
    const ops = [];
    return {
      set: (ref, data, opts) => ops.push(() => applyWrite(ref.path, data, opts)),
      update: (ref, data) => ops.push(() => applyWrite(ref.path, data, { update: true })),
      commit: async () => { await tick(); ops.forEach((f) => f()); },
    };
  },
  runTransaction: async (fn) => {
    for (let attempt = 0; attempt < 10; attempt++) {
      const reads = new Map();
      const writes = [];
      const tx = {
        get: async (ref) => {
          await tick();
          const e = store.get(ref.path);
          reads.set(ref.path, e ? e.version : 0);
          return snap(ref);
        },
        set: (ref, data, opts) => { writes.push([ref.path, data, opts || {}]); return tx; },
        update: (ref, data) => { writes.push([ref.path, data, { update: true }]); return tx; },
      };
      const result = await fn(tx);
      await tick();
      const conflict = [...reads].some(([p, v]) => (store.get(p) ? store.get(p).version : 0) !== v);
      if (conflict) { db.retries++; continue; }
      writes.forEach(([p, d, o]) => applyWrite(p, d, o));
      return result;
    }
    throw new Error("ABORTED: demasiados reintentos");
  },
  retries: 0,
};

const firestore = () => db;
firestore.FieldValue = FieldValue;
firestore.Timestamp = Timestamp;

module.exports = {
  apps: [],
  initializeApp() { this.apps.push({}); },
  firestore,
  // utilidades de prueba
  __store: store,
  __db: db,
  __reset() { store.clear(); db.retries = 0; },
};
