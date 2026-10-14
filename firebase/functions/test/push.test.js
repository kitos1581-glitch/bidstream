const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const fake = require("./helpers/fake_admin");
const sent = [];
fake.messaging = () => ({
  sendEachForMulticast: async (msg) => {
    sent.push(msg);
    return {
      successCount: msg.tokens.filter((t) => !t.startsWith("dead")).length,
      responses: msg.tokens.map((t) =>
        t.startsWith("dead")
          ? { success: false, error: { code: "messaging/registration-token-not-registered" } }
          : { success: true }
      ),
    };
  },
});
const resolved = require.resolve("firebase-admin");
require.cache[resolved] = { id: resolved, filename: resolved, loaded: true, exports: fake };
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-bidstream";
const push = require(path.join(__dirname, "..", "push.js"));

test("mensaje urgente con enlace al lote", () => {
  const m = push.buildPushMessage(
    { type: "outbid", title: "Te superaron", body: "Nueva puja", lot_id: "L1" },
    "n1"
  );
  assert.strictEqual(m.android.priority, "high");
  assert.strictEqual(m.data.link, "/lotDetailView?lotId=L1");
  assert.strictEqual(m.webpush.fcmOptions.link, "/lotDetailView?lotId=L1");
  const m2 = push.buildPushMessage({ type: "paid", title: "x" }, "n2");
  assert.strictEqual(m2.android.priority, "normal");
  assert.strictEqual(m2.data.link, "/auctionNotifications");
});

test("envía a todos los dispositivos y borra tokens muertos", async () => {
  fake.__reset();
  fake.__store.set("users/ana/fcm_tokens/tokA", { version: 1, data: { platform: "android" } });
  fake.__store.set("users/ana/fcm_tokens/dead1", { version: 1, data: { platform: "web" } });
  const r = await push.sendPushForNotification("ana", { type: "won", title: "Ganaste" }, "n1");
  assert.deepStrictEqual(r, { sent: 1, removed: 1 });
  assert.ok(!fake.__store.has("users/ana/fcm_tokens/dead1"));
  assert.ok(fake.__store.has("users/ana/fcm_tokens/tokA"));
});

test("sin dispositivos no manda nada", async () => {
  fake.__reset();
  const before = sent.length;
  const r = await push.sendPushForNotification("nadie", { title: "x" }, "n");
  assert.deepStrictEqual(r, { sent: 0, removed: 0 });
  assert.strictEqual(sent.length, before);
});
