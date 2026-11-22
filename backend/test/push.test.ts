import { env } from "cloudflare:workers";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { noticeText } from "../src/push";
import { call, callJson, count, jsonResponse, mockFetch, newRunner, type Runner } from "./helpers";

// An APNs-style .p8 key, so the provider token can be signed.
const pair = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, [
  "sign",
  "verify",
])) as CryptoKeyPair;
const pkcs8 = (await crypto.subtle.exportKey("pkcs8", pair.privateKey)) as ArrayBuffer;
const apnsKey = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...new Uint8Array(pkcs8)))}\n-----END PRIVATE KEY-----`;
const withPush = { ...env, APNS_KEY: apnsKey, APNS_KEY_ID: "PUSHKEY123" } as Env;

const token = (n: number) => n.toString(16).padStart(2, "0").repeat(32);

afterEach(() => vi.unstubAllGlobals());

async function profile(r: Runner, stageName: string, extra: Record<string, unknown> = {}) {
  const res = await callJson("PUT", "/api/crew/profile", {
    token: r.token,
    body: { stageName, color: 1, ...extra },
  });
  expect(res.status).toBe(200);
  return res.body;
}

async function befriend(a: Runner, b: Runner) {
  const code = (await callJson("POST", "/api/crew/invite", { token: a.token })).body.code;
  expect((await call("POST", "/api/crew/join", { token: b.token, body: { code } })).status).toBe(200);
}

const device = (r: Runner, t: string, sandbox = false) =>
  call("PUT", "/api/push/device", { token: r.token, body: { token: t, sandbox } });

function localNow(offsetMs = 0): string {
  return new Date(Date.now() + offsetMs).toISOString().slice(0, 23);
}

function showRow(id: string, extra: Record<string, unknown> = {}, createdAt = new Date().toISOString()) {
  return {
    id,
    data: {
      id,
      date: localNow(-2 * 3600_000),
      venue: "studio",
      workoutType: "tempo",
      distanceMiles: 6.2,
      createdAt,
      ...extra,
    },
    updatedAt: new Date().toISOString(),
    deletedAt: null,
  };
}

const sync = (r: Runner, rows: unknown[], e: Env = withPush) =>
  call("POST", "/api/sync/shows", { token: r.token, body: { rows }, env: e });

function apns(status = 200, reason?: string) {
  return mockFetch((url) => {
    expect(url.hostname).toMatch(/push\.apple\.com$/);
    return reason ? jsonResponse({ reason }, status) : new Response(null, { status });
  });
}

/** Maya with a phone, in Ryan's Crew. */
async function stage() {
  const ryan = await newRunner("Ryan");
  const maya = await newRunner("Maya");
  await profile(ryan, "Ryan");
  await profile(maya, "Maya");
  await befriend(ryan, maya);
  expect((await device(maya, token(1))).status).toBe(204);
  return { ryan, maya };
}

describe("push devices", () => {
  it("registers, moves between accounts and forgets a phone", async () => {
    const a = await newRunner("A");
    const b = await newRunner("B");
    expect((await device(a, token(2))).status).toBe(204);
    expect((await device(b, token(2).toUpperCase())).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ?1 AND user_id = ?2", token(2), b.user.id)).toBe(1);
    // Someone else can't remove it.
    expect((await call("DELETE", `/api/push/device/${token(2)}`, { token: a.token })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ?1", token(2))).toBe(1);
    expect((await call("DELETE", `/api/push/device/${token(2)}`, { token: b.token })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ?1", token(2))).toBe(0);
  });

  it("refuses a malformed token and needs sign-in", async () => {
    const a = await newRunner("A");
    expect((await device(a, "not-a-token")).status).toBe(400);
    expect((await call("PUT", "/api/push/device", { body: { token: token(3) } })).status).toBe(401);
  });

  it("goes away with the account", async () => {
    const a = await newRunner("A");
    await device(a, token(4));
    expect((await call("DELETE", "/api/me", { token: a.token })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ?1", token(4))).toBe(0);
  });
});

describe("Crew Show notifications", () => {
  it("tells Crew mates about a new Show, and only once", async () => {
    const { ryan } = await stage();
    // Ryan's own phone isn't told about his own Show.
    await device(ryan, token(5));
    const calls = apns();
    expect((await sync(ryan, [showRow("s1")])).status).toBe(200);
    expect(calls).toHaveLength(1);
    expect(calls[0].url.toString()).toBe(`https://api.push.apple.com/3/device/${token(1)}`);
    const body = JSON.parse(calls[0].body!);
    expect(body.aps.alert).toEqual({ title: "Ryan played a Show", body: "6.2 mi Tempo · Studio Session" });
    expect(body.path).toBe(`/crew/mate/${ryan.user.id}`);

    // Editing it later says nothing more.
    expect((await sync(ryan, [showRow("s1", { distanceMiles: 6.3 })])).status).toBe(200);
    expect(calls).toHaveLength(1);
  });

  it("sends one notification for many new Shows, about the newest", async () => {
    const { ryan } = await stage();
    const calls = apns();
    await sync(ryan, [
      showRow("a", { date: localNow(-20 * 3600_000), distanceMiles: 3 }),
      showRow("b", { date: localNow(-3600_000), distanceMiles: 5, venue: "live", workoutType: "easy" }),
    ]);
    expect(calls).toHaveLength(1);
    expect(JSON.parse(calls[0].body!).aps.alert.body).toBe("5 mi Easy · Live Show");
  });

  it("stays quiet for old, private and deleted Shows", async () => {
    const { ryan } = await stage();
    const calls = apns();
    // An Apple Health import of last month's runs.
    await sync(ryan, [showRow("old", { date: "2026-10-01T07:00:00.000" }, "2026-10-01T15:00:00.000Z")]);
    await sync(ryan, [showRow("hidden", { crewPrivate: true })]);
    await sync(ryan, [{ ...showRow("gone"), deletedAt: new Date().toISOString() }]);
    expect(calls).toHaveLength(0);
  });

  it("respects the switch, blocks and people outside the Crew", async () => {
    const { ryan, maya } = await stage();
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");
    await device(stranger, token(6));
    const calls = apns();

    await profile(maya, "Maya", { notifyShows: false });
    expect((await callJson("GET", "/api/crew/profile", { token: maya.token })).body.notifyShows).toBe(false);
    await sync(ryan, [showRow("x1")]);
    expect(calls).toHaveLength(0);

    // Leaving the field out (older builds) keeps the switch as it was.
    await profile(maya, "Maya");
    expect((await callJson("GET", "/api/crew/profile", { token: maya.token })).body.notifyShows).toBe(false);

    await profile(maya, "Maya", { notifyShows: true });
    await call("POST", "/api/crew/blocks", { token: maya.token, body: { userId: ryan.user.id } });
    await sync(ryan, [showRow("x2")]);
    expect(calls).toHaveLength(0);
  });

  it("forgets phones APNs says are gone", async () => {
    const { ryan } = await stage();
    apns(410, "Unregistered");
    await sync(ryan, [showRow("y1")]);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ?1", token(1))).toBe(0);
  });

  it("uses the sandbox for development builds", async () => {
    const { ryan, maya } = await stage();
    await device(maya, token(1), true);
    const calls = apns();
    await sync(ryan, [showRow("z1")]);
    expect(calls[0].url.hostname).toBe("api.sandbox.push.apple.com");
  });

  it("sends nothing without the APNs key", async () => {
    const { ryan } = await stage();
    const calls = apns();
    expect((await sync(ryan, [showRow("n1")], env as Env)).status).toBe(200);
    expect(calls).toHaveLength(0);
  });
});

describe("notice text", () => {
  it("reads naturally without a distance", () => {
    expect(noticeText("Jo", { venue: "live", workoutType: "race" })).toEqual({
      title: "Jo played a Show",
      body: "Opening Night · Live Show",
    });
  });
});
