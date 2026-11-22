import { env } from "cloudflare:workers";
import { decodeJwt, decodeProtectedHeader, importSPKI, jwtVerify } from "jose";
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import {
  APNS_PRODUCTION,
  APNS_SANDBOX,
  apnsJwt,
  clearApnsJwt,
  justPlayed,
  showBody,
} from "../src/push";
import { call, callJson, count, mockFetch, newRunner, type Runner } from "./helpers";

let pushEnv: Env;
let publicPem: string;

function pem(label: string, der: ArrayBuffer): string {
  const b64 = btoa(String.fromCharCode(...new Uint8Array(der)));
  return `-----BEGIN ${label}-----\n${b64.match(/.{1,64}/g)!.join("\n")}\n-----END ${label}-----`;
}

beforeAll(async () => {
  const pair = (await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true,
    ["sign", "verify"],
  )) as CryptoKeyPair;
  const priv = (await crypto.subtle.exportKey("pkcs8", pair.privateKey)) as ArrayBuffer;
  const pub = (await crypto.subtle.exportKey("spki", pair.publicKey)) as ArrayBuffer;
  publicPem = pem("PUBLIC KEY", pub);
  pushEnv = {
    ...(env as Env),
    APNS_KEY: pem("PRIVATE KEY", priv),
    APNS_KEY_ID: "APNSKEY123",
    APNS_TEAM_ID: "TEAMPUSH12",
  };
});

beforeEach(() => clearApnsJwt());
afterEach(() => vi.unstubAllGlobals());

/** Records every APNs call; answers [status] (and [reason]) per token. */
function apple(answers: Record<string, [number, string?]> = {}) {
  return mockFetch((url) => {
    const token = url.pathname.split("/").pop()!;
    const [status, reason] = answers[token] ?? [200];
    return new Response(reason ? JSON.stringify({ reason }) : null, { status });
  });
}

let tokenCounter = 0;
function newToken(): string {
  const hex = [...crypto.getRandomValues(new Uint8Array(32))]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return hex.slice(0, 56) + (++tokenCounter).toString(16).padStart(8, "0");
}

async function profile(r: Runner, stageName: string, extra: Record<string, unknown> = {}) {
  const res = await callJson("PUT", "/api/crew/profile", {
    token: r.token,
    body: { stageName, color: 1, ...extra },
  });
  expect(res.status).toBe(200);
  return res.body;
}

async function device(r: Runner, environment = "production"): Promise<string> {
  const token = newToken();
  const res = await call("PUT", "/api/push/device", {
    token: r.token,
    body: { token, environment },
  });
  expect(res.status).toBe(204);
  return token;
}

async function link(a: Runner, b: Runner) {
  const code = (await callJson("POST", "/api/crew/invite", { token: a.token })).body.code;
  const res = await call("POST", "/api/crew/join", { token: b.token, body: { code } });
  expect(res.status).toBe(200);
}

/** Wall-clock time [hoursAgo] before now, without an offset (like the app). */
function wallClock(hoursAgo = 0): string {
  return new Date(Date.now() - hoursAgo * 3600_000).toISOString().slice(0, 23);
}

function show(id: string, extra: Record<string, unknown> = {}) {
  return {
    schemaVersion: 1,
    id,
    date: wallClock(1),
    venue: "live",
    workoutType: "tempo",
    distanceMiles: 6.24,
    durationSeconds: 2900,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    deletedAt: null,
    ...extra,
  };
}

function rid(name: string): string {
  return `${name}-${crypto.randomUUID().slice(0, 8)}`;
}

async function syncShow(
  r: Runner,
  data: Record<string, unknown>,
  opts: { env?: Env; deletedAt?: string | null; updatedAt?: string } = {},
) {
  const res = await call("POST", "/api/sync/shows", {
    token: r.token,
    env: opts.env ?? pushEnv,
    body: {
      rows: [{
        id: data.id,
        data,
        updatedAt: opts.updatedAt ?? new Date().toISOString(),
        deletedAt: opts.deletedAt ?? null,
      }],
    },
  });
  expect(res.status).toBe(200);
}

function tokensOf(calls: { url: URL }[]): string[] {
  return calls.map((c) => c.url.pathname.split("/").pop()!).sort();
}

describe("devices", () => {
  it("saves, moves and deletes tokens", async () => {
    const a = await newRunner("A");
    const b = await newRunner("B");
    const token = newToken();
    const put = (r: Runner, body: unknown) =>
      call("PUT", "/api/push/device", { token: r.token, body });

    expect((await put(a, { token, environment: "sandbox" })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ? AND user_id = ? AND environment = 'sandbox'", token, a.user.id)).toBe(1);
    // Upper case is the same token; it moves to B with B's environment.
    expect((await put(b, { token: token.toUpperCase(), environment: "production" })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ?", token)).toBe(1);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ? AND user_id = ? AND environment = 'production'", token, b.user.id)).toBe(1);

    // A can't delete B's token; B can.
    expect((await call("DELETE", `/api/push/device/${token}`, { token: a.token })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ?", token)).toBe(1);
    expect((await call("DELETE", `/api/push/device/${token}`, { token: b.token })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM push_devices WHERE token = ?", token)).toBe(0);
  });

  it("refuses bad tokens and environments, and needs sign-in", async () => {
    const a = await newRunner("A");
    for (const body of [
      { token: "abc", environment: "production" },
      { token: "z".repeat(64), environment: "production" },
      { token: "a".repeat(201), environment: "production" },
      { token: newToken(), environment: "web" },
      { token: newToken() },
      { token: 12345, environment: "sandbox" },
    ]) {
      const res = await callJson("PUT", "/api/push/device", { token: a.token, body });
      expect(res.status, JSON.stringify(body)).toBe(400);
      expect(res.body.error).toBe("bad_request");
    }
    const anon = await call("PUT", "/api/push/device", { body: { token: newToken(), environment: "sandbox" } });
    expect(anon.status).toBe(401);
  });
});

describe("profile switches", () => {
  it("start on, and each changes only when given", async () => {
    const a = await newRunner("A");
    const p = await profile(a, "A");
    expect(p.pushShows).toBe(true);
    expect(p.pushShoutouts).toBe(true);
    const off = await profile(a, "A", { pushShows: false });
    expect(off.pushShows).toBe(false);
    expect(off.pushShoutouts).toBe(true);
    const both = await profile(a, "A", { pushShoutouts: false });
    expect(both.pushShows).toBe(false);
    expect(both.pushShoutouts).toBe(false);
    const kept = await profile(a, "A2", { pushShows: "yes" });
    expect(kept.pushShows).toBe(false);
    const got = (await callJson("GET", "/api/crew/profile", { token: a.token })).body;
    expect(got.pushShows).toBe(false);
    expect(got.pushShoutouts).toBe(false);
  });
});

describe("APNs", () => {
  it("signs an ES256 provider token and reuses it for about 50 minutes", async () => {
    const now = new Date("2026-11-22T12:00:00.000Z");
    const jwt = await apnsJwt(pushEnv, now);
    expect(decodeProtectedHeader(jwt)).toEqual({ alg: "ES256", kid: "APNSKEY123" });
    const claims = decodeJwt(jwt);
    expect(claims).toEqual({ iss: "TEAMPUSH12", iat: Math.floor(now.getTime() / 1000) });
    await jwtVerify(jwt, await importSPKI(publicPem, "ES256"), {
      currentDate: now,
    });
    expect(await apnsJwt(pushEnv, new Date(now.getTime() + 49 * 60_000))).toBe(jwt);
    const later = await apnsJwt(pushEnv, new Date(now.getTime() + 51 * 60_000));
    expect(later).not.toBe(jwt);
  });

  it("sends a Show push with the right headers, host and payload", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");
    await profile(ryan, "Ryan");
    await link(maya, ryan);
    const prodToken = await device(ryan, "production");
    const sandboxToken = await device(ryan, "sandbox");
    await device(maya); // The owner isn't told about their own Show.
    const calls = apple();
    const s = show(rid("show"));
    await syncShow(maya, s);

    expect(tokensOf(calls)).toEqual([prodToken, sandboxToken].sort());
    const prod = calls.find((c) => c.url.pathname.endsWith(prodToken))!;
    const sandbox = calls.find((c) => c.url.pathname.endsWith(sandboxToken))!;
    expect(prod.url.origin).toBe(APNS_PRODUCTION);
    expect(sandbox.url.origin).toBe(APNS_SANDBOX);
    expect(prod.url.pathname).toBe(`/3/device/${prodToken}`);
    expect(prod.method).toBe("POST");
    expect(JSON.parse(prod.body!)).toEqual({
      aps: {
        alert: { title: "Maya just played a Show", body: "Tempo · 6.2 mi" },
        sound: "default",
        "thread-id": "crew",
      },
      type: "show",
      postId: `${maya.user.id}:${s.id}`,
    });
  });

  it("sends nothing without the APNs secrets", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");
    await profile(ryan, "Ryan");
    await link(maya, ryan);
    await device(ryan);
    const calls = apple();
    await syncShow(maya, show(rid("show")), { env: env as Env });
    const post = `${maya.user.id}:${(await callJson("GET", "/api/crew/feed", { token: ryan.token })).body.posts[0].showId}`;
    await call("POST", `/api/crew/posts/${post}/shoutouts`, { token: ryan.token, body: { body: "Nice" } });
    expect(calls).toHaveLength(0);
  });
});

describe("who gets a Show push", () => {
  it("only Crew mates with the switch on, not blocked, once an hour", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    const off = await newRunner("Off");
    const blocked = await newRunner("Blocked");
    const stranger = await newRunner("Stranger");
    for (const [r, n] of [[maya, "Maya"], [ryan, "Ryan"], [off, "Off"], [blocked, "Blocked"], [stranger, "Stranger"]] as const) {
      await profile(r, n);
    }
    await link(maya, ryan);
    await link(maya, off);
    await link(maya, blocked);
    await profile(off, "Off", { pushShows: false });
    const ryanToken = await device(ryan);
    await device(off);
    await device(blocked);
    await device(stranger);
    // A block made after the link (the link row is removed, but either way).
    await call("POST", "/api/crew/blocks", { token: blocked.token, body: { userId: maya.user.id } });

    const calls = apple();
    // Private, deleted and old Shows send nothing.
    await syncShow(maya, show(rid("private"), { crewPrivate: true }));
    await syncShow(maya, show(rid("deleted")), { deletedAt: new Date().toISOString() });
    await syncShow(maya, show(rid("old"), { date: wallClock(30) }));
    await syncShow(maya, show(rid("future"), { date: wallClock(-16) }));
    expect(calls).toHaveLength(0);

    // A new Show reaches Ryan only.
    const first = show(rid("first"));
    await syncShow(maya, first);
    expect(tokensOf(calls)).toEqual([ryanToken]);

    // Syncing the same Show again (an edit) sends nothing.
    await syncShow(maya, { ...first, notes: "edited" });
    expect(calls).toHaveLength(1);

    // A second new Show within the hour: still only one push.
    await syncShow(maya, show(rid("second")));
    expect(calls).toHaveLength(1);

    // An hour later the next one goes out.
    await env.DB.prepare(
      "UPDATE push_sent SET sent_at = ? WHERE from_user = ?",
    ).bind(new Date(Date.now() - 61 * 60_000).toISOString(), maya.user.id).run();
    await syncShow(maya, show(rid("third")));
    expect(calls).toHaveLength(2);
  });

  it("a runner without a stage name sends nothing", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(ryan, "Ryan");
    await device(ryan);
    const calls = apple();
    await syncShow(maya, show(rid("show")));
    expect(calls).toHaveLength(0);
  });
});

describe("Shout-out pushes", () => {
  async function setup() {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");
    await profile(ryan, "Ryan");
    await link(maya, ryan);
    const s = show(rid("show"), { date: wallClock(48) }); // No Show push.
    await syncShow(maya, s);
    return { maya, ryan, post: `${maya.user.id}:${s.id}` };
  }
  const shout = (r: Runner, post: string, body: string) =>
    call("POST", `/api/crew/posts/${post}/shoutouts`, { token: r.token, env: pushEnv, body: { body } });

  it("tells the Show's owner, with the text cut to 120 characters", async () => {
    const { maya, ryan, post } = await setup();
    const mayaToken = await device(maya);
    await device(ryan);
    const calls = apple();
    expect((await shout(ryan, post, "Huge negative split!")).status).toBe(201);
    expect(tokensOf(calls)).toEqual([mayaToken]);
    expect(JSON.parse(calls[0].body!)).toEqual({
      aps: {
        alert: { title: "Ryan gave you a Shout-out", body: "Huge negative split!" },
        sound: "default",
        "thread-id": "crew",
      },
      type: "shoutout",
      postId: post,
    });

    const long = "x".repeat(200);
    await shout(ryan, post, long);
    const cut = JSON.parse(calls[1].body!).aps.alert.body as string;
    expect([...cut]).toHaveLength(120);
    expect(cut.endsWith("…")).toBe(true);
  });

  it("not on your own Show, nor with the switch off", async () => {
    const { maya, ryan, post } = await setup();
    await device(maya);
    const calls = apple();
    await shout(maya, post, "Thanks all");
    expect(calls).toHaveLength(0);
    await profile(maya, "Maya", { pushShoutouts: false });
    await shout(ryan, post, "Nice");
    expect(calls).toHaveLength(0);
  });
});

describe("dead tokens", () => {
  it("410 and 400 BadDeviceToken delete the token; other errors keep it", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");
    await profile(ryan, "Ryan");
    await link(maya, ryan);
    const gone = await device(ryan);
    const bad = await device(ryan);
    const busy = await device(ryan);
    const fine = await device(ryan);
    const errors = vi.spyOn(console, "error").mockImplementation(() => {});
    const calls = apple({
      [gone]: [410, "Unregistered"],
      [bad]: [400, "BadDeviceToken"],
      [busy]: [500, "InternalServerError"],
    });
    await syncShow(maya, show(rid("show")));
    expect(calls).toHaveLength(4);
    const left = await env.DB.prepare(
      "SELECT token FROM push_devices WHERE user_id = ? ORDER BY token",
    ).bind(ryan.user.id).all<{ token: string }>();
    expect(left.results.map((r) => r.token)).toEqual([busy, fine].sort());
    // Each refusal is logged with its status and reason, never the whole token.
    const logged = errors.mock.calls.map((c) => c.join(" "));
    expect(logged.some((l) => l.includes("410 Unregistered"))).toBe(true);
    expect(logged.some((l) => l.includes("500 InternalServerError"))).toBe(true);
    expect(logged.some((l) => l.includes(busy))).toBe(false);
    expect(logged.some((l) => l.includes(busy.slice(-6)))).toBe(true);
    errors.mockRestore();
  });
});

describe("helpers", () => {
  it("justPlayed allows the runner's time zone when no offset is given", () => {
    const now = new Date("2026-11-22T12:00:00.000Z");
    expect(justPlayed("2026-11-22T11:00:00.000", now)).toBe(true);
    expect(justPlayed("2026-11-21T13:00:00.000", now)).toBe(true); // UTC-11, 1 h ago
    expect(justPlayed("2026-11-21T11:00:00.000", now)).toBe(false);
    expect(justPlayed("2026-11-23T03:00:00.000", now)).toBe(true); // UTC+14, 1 h ago
    expect(justPlayed("2026-11-23T04:30:00.000", now)).toBe(false);
    expect(justPlayed("2026-11-22T11:00:00.000Z", now)).toBe(true);
    expect(justPlayed("2026-11-21T23:00:00.000Z", now)).toBe(false);
    expect(justPlayed("2026-11-22T13:30:00.000Z", now)).toBe(false);
    expect(justPlayed(null, now)).toBe(false);
    expect(justPlayed("soon", now)).toBe(false);
  });

  it("showBody names the workout and miles", () => {
    expect(showBody({ workoutType: "long", distanceMiles: 10.25 })).toBe("Headliner · 10.3 mi");
    expect(showBody({ workoutType: "race", distanceMiles: 3 })).toBe("Opening Night · 3.0 mi");
    expect(showBody({ workoutType: "mystery" })).toBe("Easy");
  });
});
