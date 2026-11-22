// Continue with Google and Sign in with Apple.
//
// Browser flow: /api/auth/{google|apple}/start -> provider -> callback ->
// one-time login code on the `return` URL -> POST /api/auth/exchange.
// Native Apple: POST /api/auth/apple/native with the identity token.

import {
  createRemoteJWKSet,
  importPKCS8,
  type JWTPayload,
  jwtVerify,
  SignJWT,
} from "jose";
import {
  addQueryParam,
  createLoginCode,
  createSession,
  findOrCreateUser,
  isAllowedReturn,
  type User,
} from "./auth";
import type { Env } from "./env";
import { ApiError, json, readJson } from "./http";
import {
  addMs,
  iso,
  isObject,
  MINUTE,
  pkceChallenge,
  randomToken,
  sha256Hex,
} from "./util";

type Provider = "google" | "apple";

const GOOGLE_AUTH = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN = "https://oauth2.googleapis.com/token";
const GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"];
const APPLE = "https://appleid.apple.com";

// Cached in module scope; jose refetches when it sees an unknown key id.
const googleJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);
const appleJwks = createRemoteJWKSet(new URL(`${APPLE}/auth/keys`));

const STATE_MS = 10 * MINUTE;

/**
 * Values added to `return` as `login_error`:
 *   cancelled       the runner backed out on Google's or Apple's page
 *   not_configured  this sign-in method has no secrets on the server
 *   failed          anything else (bad code, token didn't verify, ...)
 */
export type LoginError = "cancelled" | "not_configured" | "failed";

function googleConfigured(env: Env): boolean {
  return !!(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET && env.SESSION_SECRET);
}

function appleConfigured(env: Env): boolean {
  return !!(
    env.APPLE_TEAM_ID && env.APPLE_KEY_ID && env.APPLE_PRIVATE_KEY &&
    env.SESSION_SECRET
  );
}

function notConfigured(what: string): ApiError {
  return new ApiError(
    "not_configured",
    `${what} isn't set up on this server yet.`,
  );
}

function redirect(location: string): Response {
  return new Response(null, {
    status: 303,
    headers: { Location: location, "Cache-Control": "no-store" },
  });
}

// ---- Start ----

export async function startSignIn(
  request: Request,
  env: Env,
  provider: Provider,
): Promise<Response> {
  const url = new URL(request.url);
  const returnUrl = url.searchParams.get("return") ?? "";
  if (!isAllowedReturn(returnUrl, url.origin, env.NATIVE_REDIRECT)) {
    throw new ApiError(
      "bad_request",
      "That sign-in link isn't one this app uses.",
    );
  }
  const configured = provider === "google"
    ? googleConfigured(env)
    : appleConfigured(env);
  if (!configured) {
    // A browser is waiting: send it back to the app with the reason.
    return redirect(addQueryParam(returnUrl, "login_error", "not_configured"));
  }

  const now = new Date();
  const state = randomToken(32);
  const verifier = randomToken(32);
  const nonce = randomToken(16);
  await env.DB.batch([
    env.DB.prepare("DELETE FROM oauth_states WHERE expires_at <= ?").bind(iso(now)),
    env.DB.prepare(
      `INSERT INTO oauth_states
         (state, provider, verifier, nonce, return_url, expires_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
    ).bind(state, provider, verifier, nonce, returnUrl, iso(addMs(now, STATE_MS))),
  ]);

  const callback = `${url.origin}/api/auth/${provider}/callback`;
  let target: URL;
  if (provider === "google") {
    target = new URL(GOOGLE_AUTH);
    target.search = new URLSearchParams({
      client_id: env.GOOGLE_CLIENT_ID!,
      redirect_uri: callback,
      response_type: "code",
      scope: "openid email profile",
      state,
      nonce,
      code_challenge: await pkceChallenge(verifier),
      code_challenge_method: "S256",
      prompt: "select_account",
    }).toString();
  } else {
    // Apple's web flow has no PKCE; the state row and the nonce in the ID
    // token tie the callback to this start.
    target = new URL(`${APPLE}/auth/authorize`);
    target.search = new URLSearchParams({
      client_id: env.APPLE_SERVICES_ID,
      redirect_uri: callback,
      response_type: "code",
      response_mode: "form_post",
      scope: "name email",
      state,
      nonce,
    }).toString();
  }
  return redirect(target.toString());
}

interface StateRow {
  provider: string;
  verifier: string;
  nonce: string;
  return_url: string;
}

/** Spends a state (once). Null when it's unknown, expired or for another provider. */
async function takeState(
  db: D1Database,
  state: string,
  provider: Provider,
): Promise<StateRow | null> {
  if (!state) return null;
  const row = await db
    .prepare(
      `DELETE FROM oauth_states WHERE state = ? AND expires_at > ?
       RETURNING provider, verifier, nonce, return_url`,
    )
    .bind(state, iso())
    .first<StateRow>();
  return row && row.provider === provider ? row : null;
}

function expiredState(): ApiError {
  return new ApiError(
    "bad_request",
    "That sign-in took too long. Go back to the app and try again.",
  );
}

async function finishBrowserSignIn(
  env: Env,
  returnUrl: string,
  signIn: () => Promise<User>,
): Promise<Response> {
  try {
    const user = await signIn();
    const code = await createLoginCode(env.DB, user.id);
    return redirect(addQueryParam(returnUrl, "login_code", code));
  } catch (e) {
    console.error("sign-in failed", e);
    const reason: LoginError = e instanceof ApiError && e.code === "not_configured"
      ? "not_configured"
      : "failed";
    return redirect(addQueryParam(returnUrl, "login_error", reason));
  }
}

// ---- Google ----

export async function googleCallback(
  request: Request,
  env: Env,
): Promise<Response> {
  const url = new URL(request.url);
  const row = await takeState(env.DB, url.searchParams.get("state") ?? "", "google");
  if (!row) throw expiredState();
  if (url.searchParams.get("error")) {
    return redirect(addQueryParam(row.return_url, "login_error", "cancelled"));
  }
  const code = url.searchParams.get("code") ?? "";
  return finishBrowserSignIn(env, row.return_url, async () => {
    if (!googleConfigured(env)) throw notConfigured("Continue with Google");
    if (!code) throw new Error("no code from Google");
    const res = await fetch(GOOGLE_TOKEN, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code,
        client_id: env.GOOGLE_CLIENT_ID!,
        client_secret: env.GOOGLE_CLIENT_SECRET!,
        redirect_uri: `${url.origin}/api/auth/google/callback`,
        grant_type: "authorization_code",
        code_verifier: row.verifier,
      }),
    });
    if (!res.ok) throw new Error(`Google token exchange failed (${res.status})`);
    const body = (await res.json()) as { id_token?: unknown };
    if (typeof body.id_token !== "string") throw new Error("no id_token");
    const claims = await verifyGoogleIdToken(env, body.id_token, row.nonce);
    return findOrCreateUser(env.DB, "google", claims.sub!, {
      name: typeof claims.name === "string" ? claims.name : null,
      email: typeof claims.email === "string" && claims.email_verified !== false
        ? claims.email
        : null,
    });
  });
}

export async function verifyGoogleIdToken(
  env: Env,
  idToken: string,
  nonce: string,
): Promise<JWTPayload> {
  const { payload } = await jwtVerify(idToken, googleJwks, {
    issuer: GOOGLE_ISSUERS,
    audience: env.GOOGLE_CLIENT_ID,
    algorithms: ["RS256"],
  });
  if (payload.nonce !== nonce) throw new Error("Google nonce mismatch");
  if (!payload.sub) throw new Error("Google token has no subject");
  return payload;
}

// ---- Apple ----

/**
 * Apple's client secret: an ES256 JWT signed with the .p8 key, made fresh
 * for each call and valid for 5 minutes. [clientId] is the bundle ID
 * (native) or the Services ID (web).
 */
export async function appleClientSecret(
  env: Env,
  clientId: string,
  now: Date = new Date(),
): Promise<string> {
  if (!appleConfigured(env)) throw notConfigured("Sign in with Apple");
  const key = await importPKCS8(normalizePem(env.APPLE_PRIVATE_KEY!), "ES256");
  const iat = Math.floor(now.getTime() / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APPLE_KEY_ID! })
    .setIssuer(env.APPLE_TEAM_ID!)
    .setSubject(clientId)
    .setAudience(APPLE)
    .setIssuedAt(iat)
    .setExpirationTime(iat + 300)
    .sign(key);
}

/** Accepts the .p8 text as pasted, with real or escaped newlines. */
function normalizePem(pem: string): string {
  let p = pem.trim().replace(/\\n/g, "\n");
  if (!p.includes("BEGIN")) {
    const body = p.replace(/\s+/g, "");
    p = `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----`;
  }
  return p;
}

export async function verifyAppleIdToken(
  idToken: string,
  audience: string,
  nonce: string,
): Promise<JWTPayload> {
  const { payload } = await jwtVerify(idToken, appleJwks, {
    issuer: APPLE,
    audience,
    algorithms: ["RS256"],
  });
  if (payload.nonce !== nonce) throw new Error("Apple nonce mismatch");
  if (!payload.sub) throw new Error("Apple token has no subject");
  return payload;
}

interface AppleTokens {
  id_token?: string;
  refresh_token?: string;
}

async function appleTokenExchange(
  env: Env,
  clientId: string,
  code: string,
  redirectUri?: string,
): Promise<AppleTokens> {
  const form = new URLSearchParams({
    client_id: clientId,
    client_secret: await appleClientSecret(env, clientId),
    code,
    grant_type: "authorization_code",
  });
  if (redirectUri) form.set("redirect_uri", redirectUri);
  const res = await fetch(`${APPLE}/auth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form,
  });
  if (!res.ok) throw new Error(`Apple token exchange failed (${res.status})`);
  return (await res.json()) as AppleTokens;
}

async function saveAppleToken(
  db: D1Database,
  userId: string,
  clientId: string,
  refreshToken: string | undefined,
): Promise<void> {
  if (!refreshToken) return;
  await db
    .prepare(
      `INSERT INTO apple_tokens (user_id, client_id, refresh_token, created_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT (user_id, client_id) DO UPDATE SET
         refresh_token = excluded.refresh_token, created_at = excluded.created_at`,
    )
    .bind(userId, clientId, refreshToken, iso())
    .run();
}

function appleEmail(claims: JWTPayload): string | null {
  return typeof claims.email === "string" ? claims.email : null;
}

/** Apple's web callback: a form POST from appleid.apple.com. */
export async function appleCallback(
  request: Request,
  env: Env,
): Promise<Response> {
  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    throw expiredState();
  }
  const field = (name: string) => {
    const v = form.get(name);
    return typeof v === "string" ? v : "";
  };
  const row = await takeState(env.DB, field("state"), "apple");
  if (!row) throw expiredState();
  if (field("error")) {
    return redirect(addQueryParam(row.return_url, "login_error", "cancelled"));
  }
  const origin = new URL(request.url).origin;
  return finishBrowserSignIn(env, row.return_url, async () => {
    const code = field("code");
    if (!code) throw new Error("no code from Apple");
    const tokens = await appleTokenExchange(
      env,
      env.APPLE_SERVICES_ID,
      code,
      `${origin}/api/auth/apple/callback`,
    );
    if (typeof tokens.id_token !== "string") throw new Error("no id_token");
    const claims = await verifyAppleIdToken(
      tokens.id_token,
      env.APPLE_SERVICES_ID,
      row.nonce,
    );
    // The `user` field (with the name) arrives only the first time.
    const user = await findOrCreateUser(env.DB, "apple", claims.sub!, {
      name: appleFormName(field("user")),
      email: appleEmail(claims),
    });
    await saveAppleToken(env.DB, user.id, env.APPLE_SERVICES_ID, tokens.refresh_token);
    return user;
  });
}

/** The name from Apple's `user` form field: {"name": {firstName, lastName}}. */
export function appleFormName(userField: string): string | null {
  if (!userField) return null;
  try {
    const parsed: unknown = JSON.parse(userField);
    if (!isObject(parsed) || !isObject(parsed.name)) return null;
    return joinName(parsed.name.firstName, parsed.name.lastName);
  } catch {
    return null;
  }
}

function joinName(given: unknown, family: unknown): string | null {
  const parts = [given, family]
    .filter((p): p is string => typeof p === "string" && p.trim() !== "")
    .map((p) => p.trim());
  return parts.length ? parts.join(" ") : null;
}

/** Native Sign in with Apple on iPhone. Answers with the session. */
export async function appleNative(
  request: Request,
  env: Env,
): Promise<Response> {
  const body = await readJson(request);
  const { identityToken, authorizationCode, rawNonce } = body;
  if (
    typeof identityToken !== "string" || typeof rawNonce !== "string" ||
    !identityToken || !rawNonce ||
    (authorizationCode != null && typeof authorizationCode !== "string")
  ) {
    throw new ApiError("bad_request", "Sign in with Apple didn't send what we need.");
  }
  if (!appleConfigured(env)) throw notConfigured("Sign in with Apple");

  let claims: JWTPayload;
  try {
    claims = await verifyAppleIdToken(
      identityToken,
      env.APPLE_BUNDLE_ID,
      await sha256Hex(rawNonce),
    );
  } catch (e) {
    console.error("Apple identity token rejected", e);
    throw new ApiError(
      "not_signed_in",
      "Sign in with Apple didn't go through. Try again.",
    );
  }
  const user = await findOrCreateUser(env.DB, "apple", claims.sub!, {
    name: joinName(body.givenName, body.familyName),
    email: appleEmail(claims),
  });
  // Get a refresh token so Delete account can revoke Sign in with Apple.
  // Best effort: a failure here doesn't stop the runner signing in.
  if (authorizationCode) {
    try {
      const tokens = await appleTokenExchange(
        env,
        env.APPLE_BUNDLE_ID,
        authorizationCode as string,
      );
      await saveAppleToken(env.DB, user.id, env.APPLE_BUNDLE_ID, tokens.refresh_token);
    } catch (e) {
      console.error("Apple code exchange failed", e);
    }
  }
  return json(await createSession(env, user));
}

/** Revokes every stored Apple token of [userId]. Best effort. */
export async function revokeAppleTokens(env: Env, userId: string): Promise<void> {
  const { results } = await env.DB.prepare(
    "SELECT client_id, refresh_token FROM apple_tokens WHERE user_id = ?",
  )
    .bind(userId)
    .all<{ client_id: string; refresh_token: string }>();
  if (results.length === 0 || !appleConfigured(env)) return;
  await Promise.all(
    results.map(async (t) => {
      try {
        const res = await fetch(`${APPLE}/auth/revoke`, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            client_id: t.client_id,
            client_secret: await appleClientSecret(env, t.client_id),
            token: t.refresh_token,
            token_type_hint: "refresh_token",
          }),
        });
        if (!res.ok) console.error(`Apple revoke failed (${res.status})`);
      } catch (e) {
        console.error("Apple revoke failed", e);
      }
    }),
  );
}
