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

function isPlain(v) {
  return v && typeof v === "object" && !Array.isArray(v) && !(v instanceof Timestamp) && !v.__op;
}

function resolveValue(cur, v) {
  if (v && v.__op === "inc") return (cur || 0) + v.n;
  if (v && v.__op === "ts") return Timestamp.now();
  return v;
}

function deepMerge(target, src) {
  const out = { ...(target || {}) };
  for (const [k, v] of Object.entries(src)) {
    if (v && v.__op === "del") delete out[k];
    else if (isPlain(v)) out[k] = deepMerge(out[k], v);
    else out[k] = resolveValue(out[k], v);
  }
  return out;
}

function deepResolve(src) {
  const out = {};
  for (const [k, v] of Object.entries(src)) {
    if (v && v.__op === "del") continue;
    out[k] = isPlain(v) ? deepResolve(v) : resolveValue(undefined, v);
  }
  return out;
}

function applyWrite(path, data, { merge = false, update = false, create = false } = {}) {
  const prev = store.get(path);
  if (update && !prev) throw new Error(`NOT_FOUND: ${path}`);
  if (create && prev) {
    const e = new Error(`ALREADY_EXISTS: ${path}`);
    e.code = 6;
    throw e;
  }
  let base;
  if (update) {
    base = { ...prev.data };
    for (const [k, v] of Object.entries(data)) {
      // Rutas con punto: "deposit.status"
      const parts = k.split(".");
      let obj = base;
      for (let i = 0; i < parts.length - 1; i++) {
        obj[parts[i]] = { ...(obj[parts[i]] || {}) };
        obj = obj[parts[i]];
      }
      const last = parts[parts.length - 1];
      if (v && v.__op === "del") delete obj[last];
      else obj[last] = resolveValue(obj[last], v);
    }
  } else if (merge) {
    base = deepMerge(prev ? prev.data : {}, data);
  } else {
    base = deepResolve(data);
  }
  store.set(path, { data: base, version: (prev ? prev.version : 0) + 1 });
}

function snap(ref) {
  const e = store.get(ref.path);
  return { id: ref.id, ref, exists: !!e, data: () => (e ? { ...e.data } : undefined) };
}

const S_version = (p) => (store.get(p) ? store.get(p).version : 0);
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
    create: async (data) => { await tick(); applyWrite(path, data, { create: true }); },
    delete: async () => { await tick(); store.delete(path); },
  };
}

function colRef(path) {
  const filters = [];
  const q = {
    path,
    doc: (id) => docRef(`${path}/${id || `auto${++autoId}`}`),
    add: async (data) => { const r = docRef(`${path}/auto${++autoId}`); await r.set(data); return r; },
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
          if (op === ">=") return val(x) >= val(v);
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
      delete: (ref) => ops.push(() => store.delete(ref.path)),
      commit: async () => { await tick(); ops.forEach((f) => f()); },
    };
  },
  runTransaction: async (fn) => {
    if (db.beforeTx) {
      const hook = db.beforeTx;
      db.beforeTx = null; // una sola vez
      await hook();
    }
    for (let attempt = 0; attempt < 25; attempt++) {
      const reads = new Map();
      const writes = [];
      const tx = {
        get: async (ref) => {
          if (writes.length) {
            throw new Error("Firestore transactions require all reads to be executed before all writes.");
          }
          if (typeof ref.where === "function" && typeof ref.doc === "function" && !ref.collection) {
            // Consulta dentro de la transacción.
            const res = await ref.get();
            res.docs.forEach((d) => reads.set(d.ref.path, S_version(d.ref.path)));
            return res;
          }
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
      // Commit atómico: si alguna escritura falla, no se aplica ninguna.
      if (db.failWrites && writes.some(([p]) => db.failWrites.test(p))) {
        throw new Error("UNAVAILABLE: escritura fallida (simulada)");
      }
      writes.forEach(([p, d, o]) => applyWrite(p, d, o));
      return result;
    }
    throw new Error("ABORTED: demasiados reintentos");
  },
  retries: 0,
  beforeTx: null,
  failWrites: null,
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
  __reset() { store.clear(); db.retries = 0; db.beforeTx = null; db.failWrites = null; },
};
