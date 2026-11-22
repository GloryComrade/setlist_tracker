import { env } from "cloudflare:workers";
import {
  decodeJwt,
  decodeProtectedHeader,
  exportJWK,
  generateKeyPair,
  importJWK,
  importPKCS8,
  jwtVerify,
  SignJWT,
} from "jose";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  addQueryParam,
  createLoginCode,
  createSession,
  exchangeLoginCode,
  findOrCreateUser,
  isAllowedReturn,
  issueAccessToken,
  refreshSession,
  verifyAccessToken,
} from "../src/auth";
import type { Env } from "../src/env";
import { ApiError } from "../src/http";
import { appleClientSecret, appleFormName } from "../src/oauth";
import { sha256Base64url, sha256Hex } from "../src/util";
import {
  call,
  callJson,
  count,
  jsonResponse,
  mockFetch,
  newRunner,
  ORIGIN,
} from "./helpers";
import { vi } from "vitest";

afterEach(() => {
  vi.unstubAllGlobals();
});

const NATIVE = "com.glorycomrade.setlisttracker://login-callback";

describe("access tokens", () => {
  it("issues an HS256 JWT with sub, iat and exp = iat + 3600", async () => {
    const { token, expiresAt } = await issueAccessToken(env, "user-1");
    expect(decodeProtectedHeader(token).alg).toBe("HS256");
    const claims = decodeJwt(token);
    expect(claims.sub).toBe("user-1");
    expect(claims.exp! - claims.iat!).toBe(3600);
    expect(expiresAt.getTime()).toBe(claims.exp! * 1000);
    expect(await verifyAccessToken(env, token)).toBe("user-1");
  });

  it("rejects expired tokens, other secrets and other algorithms", async () => {
    const old = await issueAccessToken(env, "user-1", new Date(Date.now() - 2 * 3600_000));
    expect(await verifyAccessToken(env, old.token)).toBeNull();

    const other = { ...env, SESSION_SECRET: "another-secret" } as Env;
    const forged = await issueAccessToken(other, "user-1");
    expect(await verifyAccessToken(env, forged.token)).toBeNull();

    const unsigned = `${btoa('{"alg":"none"}')}.${btoa('{"sub":"user-1"}')}.`;
    expect(await verifyAccessToken(env, unsigned)).toBeNull();
    expect(await verifyAccessToken(env, "garbage")).toBeNull();
  });

  it("GET /api/me needs a valid token", async () => {
    const r = await newRunner("Maya");
    const me = await callJson("GET", "/api/me", { token: r.token });
    expect(me.status).toBe(200);
    expect(me.body).toEqual({ id: r.user.id, name: "Maya", email: "maya@example.com" });

    const none = await callJson("GET", "/api/me");
    expect(none.status).toBe(401);
    expect(none.body.error).toBe("not_signed_in");
    expect(typeof none.body.message).toBe("string");

    const bad = await callJson("GET", "/api/me", { token: "nope" });
    expect(bad.status).toBe(401);
  });

  it("says not_configured without SESSION_SECRET", async () => {
    const noSecret = { ...env, SESSION_SECRET: undefined } as Env;
    const res = await callJson("GET", "/api/me", { token: "x", env: noSecret });
    expect(res.status).toBe(503);
    expect(res.body.error).toBe("not_configured");
  });
});

describe("users", () => {
  it("matches on (provider, subject), keeps the first name, refreshes email", async () => {
    const sub = crypto.randomUUID();
    const a = await findOrCreateUser(env.DB, "apple", sub, { name: "Ryan Cheng", email: "a@x.com" });
    const b = await findOrCreateUser(env.DB, "apple", sub, { name: null, email: "b@x.com" });
    expect(b.id).toBe(a.id);
    expect(b.name).toBe("Ryan Cheng");
    expect(b.email).toBe("b@x.com");
    const c = await findOrCreateUser(env.DB, "apple", sub, { name: "Someone Else" });
    expect(c.name).toBe("Ryan Cheng");
    expect(c.email).toBe("b@x.com");
    // Same subject on another provider is another user.
    const g = await findOrCreateUser(env.DB, "google", sub, { email: "a@x.com" });
    expect(g.id).not.toBe(a.id);
  });
});

describe("refresh tokens", () => {
  it("stores only the SHA-256, rotates on refresh, and works once", async () => {
    const r = await newRunner();
    expect(await count("SELECT count(*) AS n FROM sessions WHERE token_hash = ?", r.refreshToken)).toBe(0);
    expect(
      await count(
        "SELECT count(*) AS n FROM sessions WHERE token_hash = ?",
        await sha256Base64url(r.refreshToken),
      ),
    ).toBe(1);

    const res = await callJson("POST", "/api/auth/refresh", {
      body: { refreshToken: r.refreshToken },
    });
    expect(res.status).toBe(200);
    expect(res.body.user.id).toBe(r.user.id);
    expect(res.body.refreshToken).not.toBe(r.refreshToken);
    expect(res.body.refreshToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(res.body.expiresAt).toMatch(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/);
    expect(await verifyAccessToken(env, res.body.accessToken)).toBe(r.user.id);

    const again = await callJson("POST", "/api/auth/refresh", {
      body: { refreshToken: r.refreshToken },
    });
    expect(again.status).toBe(401);
    expect(again.body.error).toBe("not_signed_in");

    const next = await callJson("POST", "/api/auth/refresh", {
      body: { refreshToken: res.body.refreshToken },
    });
    expect(next.status).toBe(200);
  });

  it("expires after 60 days", async () => {
    const r = await newRunner();
    const user = r.user;
    const s = await createSession(env, user, new Date(Date.now() - 61 * 86400_000));
    await expect(refreshSession(env, s.refreshToken)).rejects.toMatchObject({
      code: "not_signed_in",
    });
    const fresh = await createSession(env, user, new Date(Date.now() - 59 * 86400_000));
    await expect(refreshSession(env, fresh.refreshToken)).resolves.toMatchObject({
      user: { id: user.id },
    });
  });

  it("sign out deletes the refresh token", async () => {
    const r = await newRunner();
    const out = await call("POST", "/api/auth/signout", { body: { refreshToken: r.refreshToken } });
    expect(out.status).toBe(204);
    const res = await callJson("POST", "/api/auth/refresh", { body: { refreshToken: r.refreshToken } });
    expect(res.status).toBe(401);
  });

  it("asks for the token", async () => {
    const res = await callJson("POST", "/api/auth/refresh", { body: {} });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe("bad_request");
  });
});

describe("login codes", () => {
  it("exchange gives a session, once", async () => {
    const r = await newRunner("Code");
    const code = await createLoginCode(env.DB, r.user.id);
    const res = await callJson("POST", "/api/auth/exchange", { body: { code } });
    expect(res.status).toBe(200);
    expect(Object.keys(res.body).sort()).toEqual(["accessToken", "expiresAt", "refreshToken", "user"]);
    expect(res.body.user).toEqual({ id: r.user.id, name: "Code", email: "code@example.com" });

    const again = await callJson("POST", "/api/auth/exchange", { body: { code } });
    expect(again.status).toBe(401);
    expect(again.body.error).toBe("not_signed_in");
  });

  it("expire after 60 seconds", async () => {
    const r = await newRunner();
    const code = await createLoginCode(env.DB, r.user.id, new Date(Date.now() - 61_000));
    await expect(exchangeLoginCode(env, code)).rejects.toBeInstanceOf(ApiError);
    const ok = await createLoginCode(env.DB, r.user.id, new Date(Date.now() - 50_000));
    await expect(exchangeLoginCode(env, ok)).resolves.toMatchObject({ user: { id: r.user.id } });
  });

  it("are stored only as hashes", async () => {
    const r = await newRunner();
    const code = await createLoginCode(env.DB, r.user.id);
    expect(await count("SELECT count(*) AS n FROM login_codes WHERE code_hash = ?", code)).toBe(0);
    expect(
      await count("SELECT count(*) AS n FROM login_codes WHERE code_hash = ?", await sha256Base64url(code)),
    ).toBe(1);
  });

  it("unknown codes are refused", async () => {
    const res = await callJson("POST", "/api/auth/exchange", { body: { code: "made-up" } });
    expect(res.status).toBe(401);
  });
});

describe("return URL allowlist", () => {
  const own = "https://setlist.example.workers.dev";
  it.each([
    [`${own}/`, true],
    [`${own}/crew?x=1#top`, true],
    ["http://localhost:5173/", true],
    ["http://localhost:8080/some/path?a=b", true],
    ["http://127.0.0.1:3000/", true],
    [NATIVE, true],
    [`${NATIVE}?x=1`, false],
    ["com.glorycomrade.setlisttracker://other", false],
    ["https://evil.example.com/", false],
    ["https://setlist.example.workers.dev.evil.com/", false],
    ["http://setlist.example.workers.dev/", false],
    ["http://localhost/", false],
    ["https://localhost:5173/", false],
    ["http://localhost:5173@evil.com/", false],
    ["http://user:pw@localhost:5173/", false],
    ["javascript:alert(1)", false],
    ["", false],
    ["/relative", false],
  ])("%s -> %s", (url, ok) => {
    expect(isAllowedReturn(url, own, NATIVE)).toBe(ok);
  });

  it("start refuses anything else with a 400", async () => {
    const res = await callJson(
      "GET",
      `/api/auth/google/start?return=${encodeURIComponent("https://evil.example.com/")}`,
    );
    expect(res.status).toBe(400);
    expect(res.body.error).toBe("bad_request");
  });

  it("adds the code to the query, before any #", () => {
    expect(addQueryParam("https://a.test/", "login_code", "abc")).toBe("https://a.test/?login_code=abc");
    expect(addQueryParam("https://a.test/?x=1", "login_code", "abc")).toBe("https://a.test/?x=1&login_code=abc");
    expect(addQueryParam("https://a.test/p#/crew?y=2", "login_code", "abc")).toBe(
      "https://a.test/p?login_code=abc#/crew?y=2",
    );
    expect(addQueryParam("https://a.test/?#h", "login_error", "failed")).toBe(
      "https://a.test/?login_error=failed#h",
    );
    expect(addQueryParam(NATIVE, "login_code", "a-b_c")).toBe(`${NATIVE}?login_code=a-b_c`);
  });
});

// ---- Provider flows, with Google and Apple mocked ----

let providerKey: CryptoKey;
let providerJwk: Record<string, unknown>;

beforeAll(async () => {
  const pair = await generateKeyPair("RS256", { extractable: true });
  providerKey = pair.privateKey;
  providerJwk = { ...(await exportJWK(pair.publicKey)), kid: "test-key-1", alg: "RS256", use: "sig" };
});

function idToken(claims: Record<string, unknown>, opts: { iss: string; aud: string }) {
  return new SignJWT(claims)
    .setProtectedHeader({ alg: "RS256", kid: "test-key-1" })
    .setIssuer(opts.iss)
    .setAudience(opts.aud)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(providerKey);
}

function queryOf(location: string): URLSearchParams {
  const u = new URL(location);
  return u.searchParams;
}

describe("Continue with Google", () => {
  it("start stores state + PKCE and redirects to Google", async () => {
    const ret = "http://localhost:5173/";
    const res = await call("GET", `/api/auth/google/start?return=${encodeURIComponent(ret)}`);
    expect(res.status).toBe(303);
    const loc = new URL(res.headers.get("Location")!);
    expect(loc.origin + loc.pathname).toBe("https://accounts.google.com/o/oauth2/v2/auth");
    const q = loc.searchParams;
    expect(q.get("client_id")).toBe(env.GOOGLE_CLIENT_ID);
    expect(q.get("redirect_uri")).toBe(`${ORIGIN}/api/auth/google/callback`);
    expect(q.get("scope")).toBe("openid email profile");
    expect(q.get("code_challenge_method")).toBe("S256");
    const row = await env.DB.prepare("SELECT * FROM oauth_states WHERE state = ?")
      .bind(q.get("state"))
      .first<{ verifier: string; return_url: string; provider: string; expires_at: string }>();
    expect(row!.provider).toBe("google");
    expect(row!.return_url).toBe(ret);
    expect(q.get("code_challenge")).toBe(await sha256Base64url(row!.verifier));
    const ttl = Date.parse(row!.expires_at) - Date.now();
    expect(ttl).toBeGreaterThan(9 * 60_000);
    expect(ttl).toBeLessThanOrEqual(10 * 60_000);
  });

  it("without secrets, sends the browser back with login_error=not_configured", async () => {
    const noGoogle = { ...env, GOOGLE_CLIENT_ID: undefined } as Env;
    const res = await call("GET", `/api/auth/google/start?return=${encodeURIComponent(NATIVE)}`, {
      env: noGoogle,
    });
    expect(res.status).toBe(303);
    expect(res.headers.get("Location")).toBe(`${NATIVE}?login_error=not_configured`);
  });

  it("callback exchanges the code, verifies the ID token and hands back a login code", async () => {
    const ret = `${ORIGIN}/#/backstage`;
    const start = await call("GET", `/api/auth/google/start?return=${encodeURIComponent(ret)}`);
    const q = queryOf(start.headers.get("Location")!);
    const state = q.get("state")!;
    const nonce = q.get("nonce")!;
    const sub = `google-${crypto.randomUUID()}`;

    const calls = mockFetch(async (url) => {
      if (url.href === "https://www.googleapis.com/oauth2/v3/certs") {
        return jsonResponse({ keys: [providerJwk] });
      }
      if (url.href === "https://oauth2.googleapis.com/token") {
        return jsonResponse({
          id_token: await idToken(
            { sub, nonce, email: "ryan@gmail.com", email_verified: true, name: "Ryan Cheng" },
            { iss: "https://accounts.google.com", aud: env.GOOGLE_CLIENT_ID! },
          ),
        });
      }
      return new Response("unexpected", { status: 500 });
    });

    const cb = await call("GET", `/api/auth/google/callback?state=${state}&code=good-code`);
    expect(cb.status).toBe(303);
    const loc = cb.headers.get("Location")!;
    expect(loc.startsWith(`${ORIGIN}/?login_code=`)).toBe(true);
    expect(loc.endsWith("#/backstage")).toBe(true);

    const tokenCall = calls.find((c) => c.url.href === "https://oauth2.googleapis.com/token")!;
    const form = new URLSearchParams(tokenCall.body!);
    expect(form.get("code")).toBe("good-code");
    expect(form.get("code_verifier")).toBeTruthy();
    expect(await sha256Base64url(form.get("code_verifier")!)).toBe(q.get("code_challenge"));

    const code = new URL(loc.split("#")[0]).searchParams.get("login_code")!;
    const session = await callJson("POST", "/api/auth/exchange", { body: { code } });
    expect(session.status).toBe(200);
    expect(session.body.user).toMatchObject({ name: "Ryan Cheng", email: "ryan@gmail.com" });

    // The state was spent.
    const replay = await callJson("GET", `/api/auth/google/callback?state=${state}&code=good-code`);
    expect(replay.status).toBe(400);
  });

  it("a token for another audience or nonce fails with login_error=failed", async () => {
    for (const bad of [{ aud: "someone-else" }, { nonce: "wrong" }]) {
      const start = await call("GET", `/api/auth/google/start?return=${encodeURIComponent(NATIVE)}`);
      const q = queryOf(start.headers.get("Location")!);
      mockFetch(async (url) => {
        if (url.hostname === "www.googleapis.com") return jsonResponse({ keys: [providerJwk] });
        return jsonResponse({
          id_token: await idToken(
            { sub: "x", nonce: bad.nonce ?? q.get("nonce") },
            { iss: "https://accounts.google.com", aud: bad.aud ?? env.GOOGLE_CLIENT_ID! },
          ),
        });
      });
      const cb = await call("GET", `/api/auth/google/callback?state=${q.get("state")}&code=c`);
      expect(cb.headers.get("Location")).toBe(`${NATIVE}?login_error=failed`);
    }
  });

  it("the runner backing out gives login_error=cancelled", async () => {
    const start = await call("GET", `/api/auth/google/start?return=${encodeURIComponent(NATIVE)}`);
    const state = queryOf(start.headers.get("Location")!).get("state");
    const cb = await call("GET", `/api/auth/google/callback?state=${state}&error=access_denied`);
    expect(cb.headers.get("Location")).toBe(`${NATIVE}?login_error=cancelled`);
  });
});

describe("Sign in with Apple", () => {
  it("signs a 5-minute ES256 client secret", async () => {
    const secret = await appleClientSecret(env, "com.glorycomrade.setlisttracker");
    const header = decodeProtectedHeader(secret);
    expect(header).toMatchObject({ alg: "ES256", kid: env.APPLE_KEY_ID });
    const priv = await importPKCS8(env.APPLE_PRIVATE_KEY!, "ES256", { extractable: true });
    const { d: _d, ...pub } = await exportJWK(priv);
    const { payload } = await jwtVerify(secret, await importJWK(pub, "ES256"), {
      issuer: env.APPLE_TEAM_ID,
      audience: "https://appleid.apple.com",
      subject: "com.glorycomrade.setlisttracker",
    });
    expect(payload.exp! - payload.iat!).toBeLessThanOrEqual(300);
  });

  it("start redirects with form_post and name email", async () => {
    const res = await call("GET", `/api/auth/apple/start?return=${encodeURIComponent(`${ORIGIN}/`)}`);
    const loc = new URL(res.headers.get("Location")!);
    expect(loc.origin + loc.pathname).toBe("https://appleid.apple.com/auth/authorize");
    expect(loc.searchParams.get("response_mode")).toBe("form_post");
    expect(loc.searchParams.get("scope")).toBe("name email");
    expect(loc.searchParams.get("client_id")).toBe(env.APPLE_SERVICES_ID);
    expect(loc.searchParams.get("redirect_uri")).toBe(`${ORIGIN}/api/auth/apple/callback`);
  });

  async function appleWebSignIn(sub: string, userField?: string) {
    const start = await call("GET", `/api/auth/apple/start?return=${encodeURIComponent(`${ORIGIN}/`)}`);
    const q = queryOf(start.headers.get("Location")!);
    const calls = mockFetch(async (url) => {
      if (url.href === "https://appleid.apple.com/auth/keys") return jsonResponse({ keys: [providerJwk] });
      if (url.href === "https://appleid.apple.com/auth/token") {
        return jsonResponse({
          refresh_token: "apple-refresh-web",
          id_token: await idToken(
            { sub, nonce: q.get("nonce"), email: "ryan@privaterelay.appleid.com" },
            { iss: "https://appleid.apple.com", aud: env.APPLE_SERVICES_ID },
          ),
        });
      }
      return new Response("unexpected", { status: 500 });
    });
    const form = new FormData();
    form.set("state", q.get("state")!);
    form.set("code", "apple-code");
    if (userField) form.set("user", userField);
    const cb = await call("POST", "/api/auth/apple/callback", { body: form });
    expect(cb.status).toBe(303);
    const code = queryOf(cb.headers.get("Location")!).get("login_code")!;
    expect(code).toBeTruthy();
    const session = await callJson("POST", "/api/auth/exchange", { body: { code } });
    return { session: session.body, calls };
  }

  it("web callback saves the name the first time and the refresh token", async () => {
    const sub = `apple-${crypto.randomUUID()}`;
    const first = await appleWebSignIn(
      sub,
      JSON.stringify({ name: { firstName: "Ryan", lastName: "Cheng" }, email: "x@y.z" }),
    );
    expect(first.session.user.name).toBe("Ryan Cheng");
    expect(first.session.user.email).toBe("ryan@privaterelay.appleid.com");
    const tokenCall = first.calls.find((c) => c.url.pathname === "/auth/token")!;
    const form = new URLSearchParams(tokenCall.body!);
    expect(form.get("client_id")).toBe(env.APPLE_SERVICES_ID);
    expect(form.get("redirect_uri")).toBe(`${ORIGIN}/api/auth/apple/callback`);
    expect(decodeJwt(form.get("client_secret")!).sub).toBe(env.APPLE_SERVICES_ID);

    const stored = await env.DB.prepare("SELECT * FROM apple_tokens WHERE user_id = ?")
      .bind(first.session.user.id)
      .first<{ refresh_token: string; client_id: string }>();
    expect(stored).toMatchObject({ refresh_token: "apple-refresh-web", client_id: env.APPLE_SERVICES_ID });

    // Later sign-ins have no `user` field; the name stays.
    const second = await appleWebSignIn(sub);
    expect(second.session.user.id).toBe(first.session.user.id);
    expect(second.session.user.name).toBe("Ryan Cheng");
  });

  it("parses Apple's user field", () => {
    expect(appleFormName('{"name":{"firstName":"Ryan","lastName":"Cheng"}}')).toBe("Ryan Cheng");
    expect(appleFormName('{"name":{"firstName":"Cher"}}')).toBe("Cher");
    expect(appleFormName("not json")).toBeNull();
    expect(appleFormName("")).toBeNull();
  });

  it("native: checks the nonce, saves the refresh token, answers a session", async () => {
    const rawNonce = "raw-nonce-123";
    const sub = `apple-native-${crypto.randomUUID()}`;
    const calls = mockFetch(async (url) => {
      if (url.pathname === "/auth/keys") return jsonResponse({ keys: [providerJwk] });
      if (url.pathname === "/auth/token") return jsonResponse({ refresh_token: "apple-refresh-native" });
      return new Response("unexpected", { status: 500 });
    });
    const identityToken = await idToken(
      { sub, nonce: await sha256Hex(rawNonce), email: "n@privaterelay.appleid.com" },
      { iss: "https://appleid.apple.com", aud: env.APPLE_BUNDLE_ID },
    );

    const wrong = await callJson("POST", "/api/auth/apple/native", {
      body: { identityToken, authorizationCode: "c", rawNonce: "other" },
    });
    expect(wrong.status).toBe(401);

    const res = await callJson("POST", "/api/auth/apple/native", {
      body: { identityToken, authorizationCode: "c", rawNonce, givenName: "Ryan", familyName: "Cheng" },
    });
    expect(res.status).toBe(200);
    expect(res.body.user).toMatchObject({ name: "Ryan Cheng", email: "n@privaterelay.appleid.com" });
    const tokenCall = calls.find((c) => c.url.pathname === "/auth/token")!;
    const form = new URLSearchParams(tokenCall.body!);
    expect(form.get("client_id")).toBe(env.APPLE_BUNDLE_ID);
    expect(form.get("code")).toBe("c");
    const stored = await env.DB.prepare("SELECT refresh_token FROM apple_tokens WHERE user_id = ?")
      .bind(res.body.user.id)
      .first<{ refresh_token: string }>();
    expect(stored?.refresh_token).toBe("apple-refresh-native");

    // A token for the web Services ID isn't accepted natively.
    const webToken = await idToken(
      { sub, nonce: await sha256Hex(rawNonce) },
      { iss: "https://appleid.apple.com", aud: env.APPLE_SERVICES_ID },
    );
    const aud = await callJson("POST", "/api/auth/apple/native", {
      body: { identityToken: webToken, authorizationCode: "c", rawNonce },
    });
    expect(aud.status).toBe(401);
  });
});

describe("CORS", () => {
  it("only for localhost and 127.0.0.1", async () => {
    const pre = await call("OPTIONS", "/api/me", { headers: { Origin: "http://localhost:5173" } });
    expect(pre.status).toBe(204);
    expect(pre.headers.get("Access-Control-Allow-Origin")).toBe("http://localhost:5173");
    expect(pre.headers.get("Access-Control-Allow-Headers")).toMatch(/Authorization/);

    const res = await call("GET", "/api/me", { headers: { Origin: "http://127.0.0.1:8080" } });
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("http://127.0.0.1:8080");

    const evil = await call("GET", "/api/me", { headers: { Origin: "https://evil.example.com" } });
    expect(evil.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });
});
