// Sessions: access tokens (HS256 JWTs), refresh tokens, one-time login
// codes, users, and the return-URL allowlist for browser sign-in.

import { jwtVerify, SignJWT } from "jose";
import type { Env } from "./env";
import { ApiError } from "./http";
import { addMs, DAY, iso, MINUTE, randomToken, sha256Base64url } from "./util";

export const ACCESS_TOKEN_SECONDS = 3600;
export const REFRESH_TOKEN_MS = 60 * DAY;
export const LOGIN_CODE_MS = MINUTE;

export interface User {
  id: string;
  name: string | null;
  email: string | null;
}

export interface Session {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  user: User;
}

function sessionKey(env: Env): Uint8Array {
  if (!env.SESSION_SECRET) {
    throw new ApiError(
      "not_configured",
      "Backstage Pass isn't set up on this server yet.",
    );
  }
  return new TextEncoder().encode(env.SESSION_SECRET);
}

// ---- Access tokens ----

export async function issueAccessToken(
  env: Env,
  userId: string,
  now: Date = new Date(),
): Promise<{ token: string; expiresAt: Date }> {
  const iat = Math.floor(now.getTime() / 1000);
  const exp = iat + ACCESS_TOKEN_SECONDS;
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setSubject(userId)
    .setIssuedAt(iat)
    .setExpirationTime(exp)
    .sign(sessionKey(env));
  return { token, expiresAt: new Date(exp * 1000) };
}

/** The user id in a valid access token, or null. */
export async function verifyAccessToken(
  env: Env,
  token: string,
): Promise<string | null> {
  const key = sessionKey(env);
  try {
    const { payload } = await jwtVerify(token, key, { algorithms: ["HS256"] });
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}

const SIGN_IN_AGAIN = "Your Backstage Pass expired. Sign in again.";

/** The signed-in user, or a 401. */
export async function requireUser(request: Request, env: Env): Promise<User> {
  const header = request.headers.get("Authorization") ?? "";
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  if (!match) throw new ApiError("not_signed_in", "Sign in to Backstage first.");
  const userId = await verifyAccessToken(env, match[1]);
  if (!userId) throw new ApiError("not_signed_in", SIGN_IN_AGAIN);
  const user = await getUser(env.DB, userId);
  // A deleted account's token stops working at once.
  if (!user) throw new ApiError("not_signed_in", SIGN_IN_AGAIN);
  return user;
}

// ---- Users ----

export async function getUser(db: D1Database, id: string): Promise<User | null> {
  return db
    .prepare("SELECT id, name, email FROM users WHERE id = ?")
    .bind(id)
    .first<User>();
}

/**
 * Finds the user for (provider, subject), or makes one. Users are matched
 * on the provider's subject only: the same email on Google and Apple gives
 * two users. A known email is refreshed; a name is only filled in when the
 * user has none yet (Apple sends the name only on the first sign-in).
 */
export async function findOrCreateUser(
  db: D1Database,
  provider: "google" | "apple",
  sub: string,
  profile: { name?: string | null; email?: string | null },
  now: Date = new Date(),
): Promise<User> {
  const name = cleanName(profile.name);
  const email = profile.email?.trim() || null;
  const user = await db
    .prepare(
      `INSERT INTO users (id, provider, provider_sub, name, email, created_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT (provider, provider_sub) DO UPDATE SET
         email = coalesce(excluded.email, users.email),
         name = coalesce(users.name, excluded.name)
       RETURNING id, name, email`,
    )
    .bind(crypto.randomUUID(), provider, sub, name, email, iso(now))
    .first<User>();
  if (!user) throw new Error("user upsert returned nothing");
  return user;
}

function cleanName(name: string | null | undefined): string | null {
  const n = name?.replace(/\s+/g, " ").trim();
  return n ? n.slice(0, 100) : null;
}

// ---- Refresh tokens and sessions ----

/** Makes a new refresh token for [user] and returns the whole session. */
export async function createSession(
  env: Env,
  user: User,
  now: Date = new Date(),
): Promise<Session> {
  const refreshToken = randomToken(32);
  await env.DB.batch([
    // Opportunistic cleanup of expired sessions (anyone's).
    env.DB.prepare("DELETE FROM sessions WHERE expires_at <= ?").bind(iso(now)),
    env.DB.prepare(
      `INSERT INTO sessions (token_hash, user_id, created_at, expires_at)
       VALUES (?, ?, ?, ?)`,
    ).bind(
      await sha256Base64url(refreshToken),
      user.id,
      iso(now),
      iso(addMs(now, REFRESH_TOKEN_MS)),
    ),
  ]);
  const access = await issueAccessToken(env, user.id, now);
  return {
    accessToken: access.token,
    refreshToken,
    expiresAt: iso(access.expiresAt),
    user,
  };
}

/**
 * Swaps [refreshToken] for a new session. The old token is deleted in the
 * same statement that reads it, so it can be used only once.
 */
export async function refreshSession(
  env: Env,
  refreshToken: string,
  now: Date = new Date(),
): Promise<Session> {
  sessionKey(env); // not_configured before the token is spent
  const row = await env.DB.prepare(
    `DELETE FROM sessions WHERE token_hash = ? AND expires_at > ?
     RETURNING user_id`,
  )
    .bind(await sha256Base64url(refreshToken), iso(now))
    .first<{ user_id: string }>();
  const user = row ? await getUser(env.DB, row.user_id) : null;
  if (!user) throw new ApiError("not_signed_in", SIGN_IN_AGAIN);
  return createSession(env, user, now);
}

export async function signOut(env: Env, refreshToken: string): Promise<void> {
  await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?")
    .bind(await sha256Base64url(refreshToken))
    .run();
}

// ---- One-time login codes ----

export async function createLoginCode(
  db: D1Database,
  userId: string,
  now: Date = new Date(),
): Promise<string> {
  const code = randomToken(32);
  await db.batch([
    db.prepare("DELETE FROM login_codes WHERE expires_at <= ?").bind(iso(now)),
    db
      .prepare(
        "INSERT INTO login_codes (code_hash, user_id, expires_at) VALUES (?, ?, ?)",
      )
      .bind(
        await sha256Base64url(code),
        userId,
        iso(addMs(now, LOGIN_CODE_MS)),
      ),
  ]);
  return code;
}

/** Spends a login code (once) and returns the session. */
export async function exchangeLoginCode(
  env: Env,
  code: string,
  now: Date = new Date(),
): Promise<Session> {
  sessionKey(env);
  const row = await env.DB.prepare(
    `DELETE FROM login_codes WHERE code_hash = ? AND expires_at > ?
     RETURNING user_id`,
  )
    .bind(await sha256Base64url(code), iso(now))
    .first<{ user_id: string }>();
  const user = row ? await getUser(env.DB, row.user_id) : null;
  if (!user) {
    throw new ApiError(
      "not_signed_in",
      "That sign-in took too long. Try signing in again.",
    );
  }
  return createSession(env, user, now);
}

// ---- Browser sign-in: where to send the runner back ----

/**
 * True when [returnUrl] is one of: this Worker's own origin (any path),
 * http://localhost:<port>/... or http://127.0.0.1:<port>/..., or exactly
 * NATIVE_REDIRECT.
 */
export function isAllowedReturn(
  returnUrl: string,
  ownOrigin: string,
  nativeRedirect: string,
): boolean {
  if (returnUrl === nativeRedirect) return true;
  let url: URL;
  try {
    url = new URL(returnUrl);
  } catch {
    return false;
  }
  if (url.username || url.password) return false;
  if (url.origin === ownOrigin) return true;
  return (
    url.protocol === "http:" &&
    (url.hostname === "localhost" || url.hostname === "127.0.0.1") &&
    url.port !== ""
  );
}

/**
 * [returnUrl] with `name=value` added to its query string, before any '#'.
 */
export function addQueryParam(
  returnUrl: string,
  name: string,
  value: string,
): string {
  const hashAt = returnUrl.indexOf("#");
  const base = hashAt === -1 ? returnUrl : returnUrl.slice(0, hashAt);
  const hash = hashAt === -1 ? "" : returnUrl.slice(hashAt);
  const sep = !base.includes("?") ? "?" : /[?&]$/.test(base) ? "" : "&";
  return `${base}${sep}${encodeURIComponent(name)}=${encodeURIComponent(value)}${hash}`;
}
