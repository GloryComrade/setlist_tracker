// Small helpers built on Web Crypto.

const encoder = new TextEncoder();

export function base64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function randomBytes(n: number): Uint8Array {
  const out = new Uint8Array(n);
  crypto.getRandomValues(out);
  return out;
}

/** 32 random bytes, base64url: refresh tokens, login codes, states. */
export function randomToken(bytes = 32): string {
  return base64url(randomBytes(bytes));
}

export async function sha256(text: string): Promise<Uint8Array> {
  return new Uint8Array(
    await crypto.subtle.digest("SHA-256", encoder.encode(text)),
  );
}

export async function sha256Base64url(text: string): Promise<string> {
  return base64url(await sha256(text));
}

export async function sha256Hex(text: string): Promise<string> {
  return [...(await sha256(text))]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** PKCE S256 challenge for [verifier]. */
export function pkceChallenge(verifier: string): Promise<string> {
  return sha256Base64url(verifier);
}

/** ISO 8601 UTC with milliseconds. */
export function iso(d: Date = new Date()): string {
  return d.toISOString();
}

export function addMs(d: Date, ms: number): Date {
  return new Date(d.getTime() + ms);
}

export const MINUTE = 60_000;
export const HOUR = 60 * MINUTE;
export const DAY = 24 * HOUR;

/**
 * Parses an ISO 8601 time from the app and returns it in the one format the
 * database stores (UTC, milliseconds), or null when it isn't a time.
 * Extra precision (Dart sends microseconds) is dropped.
 */
export function normalizeIso(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 40) return null;
  // Require a date and a time so "2026" or "12" don't count.
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value)) return null;
  // Date.parse treats a time without an offset as local; the Worker runs in
  // UTC, and the contract says times are UTC.
  const ms = Date.parse(value);
  if (!Number.isFinite(ms)) return null;
  return new Date(ms).toISOString();
}

export function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

export function byteLength(text: string): number {
  return encoder.encode(text).length;
}
