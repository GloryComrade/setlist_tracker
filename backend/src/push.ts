// Push notifications on iPhone, sent straight to Apple (APNs). No Firebase.
//
// - PUT /api/push/device {token, environment} -> 204. Saves the phone's
//   APNs token for the signed-in runner; a token that was someone else's
//   (same phone, new account) moves to this runner.
// - DELETE /api/push/device/{token} -> 204. Your own token only.
//
// Two kinds of push, each with its own Settings switch (crew_profiles):
// - push_shows: a Crew mate synced a new Show (src/sync.ts calls
//   notifyNewShows). At most one per mate per hour (push_sent).
// - push_shoutouts: someone gave a Shout-out on your Show (src/crew.ts calls
//   notifyShoutout).
//
// Sending is optional: without APNS_KEY, APNS_KEY_ID and APNS_TEAM_ID
// nothing is sent and nothing fails. It runs after the answer is sent
// (ctx.waitUntil), and never throws.

import { importPKCS8, SignJWT } from "jose";
import { CREW_SHOW } from "./crew";
import type { Env } from "./env";
import { ApiError, noContent, readJson } from "./http";
import { normalizePem } from "./oauth";
import { addMs, DAY, HOUR, iso, MINUTE } from "./util";

/** Runs [p] after the answer is sent (ctx.waitUntil). */
export type Background = (p: Promise<unknown>) => void;

/** For callers without a ctx: runs [p] without waiting, logging failures. */
export const detached: Background = (p) => {
  p.catch((e) => console.error("background task failed", e));
};

export const APNS_PRODUCTION = "https://api.push.apple.com";
export const APNS_SANDBOX = "https://api.sandbox.push.apple.com";

/** A Show counts as "just played" for this long after its date. */
export const SHOW_FRESH_MS = 12 * HOUR;
/** ...and this long before it (clocks, a Show logged at the start line). */
export const SHOW_EARLY_MS = HOUR;
/**
 * A Show's date is the runner's wall-clock time without an offset
 * (lib/models/show.dart), so the window above is widened by the furthest
 * time zones from UTC (-12 h and +14 h) when no offset is given.
 */
const TZ_WEST_MS = 12 * HOUR;
const TZ_EAST_MS = 14 * HOUR;

export const SHOW_PUSH_EVERY_MS = HOUR;
export const SHOUTOUT_BODY_CHARS = 120;

/** lib/models/enums.dart WorkoutType labels, by name. */
const WORKOUT_LABELS: Record<string, string> = {
  easy: "Easy",
  long: "Headliner",
  tempo: "Tempo",
  intervals: "Intervals",
  recovery: "Recovery",
  race: "Opening Night",
};

export type PushEnvironment = "sandbox" | "production";

export function apnsConfigured(env: Env): boolean {
  return !!(env.APNS_KEY && env.APNS_KEY_ID && env.APNS_TEAM_ID);
}

// ---- Devices ----

function badDevice(): ApiError {
  return new ApiError("bad_request", "That device didn't look right.");
}

/** A hex APNs token, lowercased, or null. */
export function normalizeToken(v: unknown): string | null {
  if (typeof v !== "string" || !/^[0-9a-fA-F]{32,200}$/.test(v)) return null;
  return v.toLowerCase();
}

export async function saveDevice(
  db: D1Database,
  me: string,
  body: Record<string, unknown>,
  now: Date = new Date(),
): Promise<void> {
  const token = normalizeToken(body.token);
  const environment = body.environment;
  if (!token || (environment !== "sandbox" && environment !== "production")) {
    throw badDevice();
  }
  const at = iso(now);
  await db
    .prepare(
      `INSERT INTO push_devices
         (token, user_id, platform, environment, created_at, updated_at)
       VALUES (?1, ?2, 'ios', ?3, ?4, ?4)
       ON CONFLICT (token) DO UPDATE SET
         user_id = excluded.user_id, environment = excluded.environment,
         updated_at = excluded.updated_at`,
    )
    .bind(token, me, environment, at)
    .run();
}

export async function deleteDevice(db: D1Database, me: string, raw: string) {
  const token = normalizeToken(raw);
  if (!token) return;
  await db
    .prepare("DELETE FROM push_devices WHERE token = ? AND user_id = ?")
    .bind(token, me)
    .run();
}

/** /api/push/device[/{token}] for the signed-in [me]. Null when no route matches. */
export async function pushDeviceRoute(
  request: Request,
  db: D1Database,
  me: string,
  parts: string[],
): Promise<Response | null> {
  const [what, token] = parts;
  if (what !== "device") return null;
  if (parts.length === 1 && request.method === "PUT") {
    await saveDevice(db, me, await readJson(request));
    return noContent();
  }
  if (parts.length === 2 && request.method === "DELETE") {
    await deleteDevice(db, me, token);
    return noContent();
  }
  return null;
}

/** Saves the two Settings switches when the profile PUT has them. */
export async function savePushPrefs(
  db: D1Database,
  me: string,
  body: Record<string, unknown>,
): Promise<void> {
  const shows = typeof body.pushShows === "boolean" ? (body.pushShows ? 1 : 0) : null;
  const shoutouts =
    typeof body.pushShoutouts === "boolean" ? (body.pushShoutouts ? 1 : 0) : null;
  if (shows === null && shoutouts === null) return;
  await db
    .prepare(
      `UPDATE crew_profiles SET
         push_shows = coalesce(?2, push_shows),
         push_shoutouts = coalesce(?3, push_shoutouts)
       WHERE user_id = ?1`,
    )
    .bind(me, shows, shoutouts)
    .run();
}

// ---- APNs ----

let jwtCache: { key: string; token: string; at: number } | null = null;
/** Apple wants a new provider token at most every 20 min, at least every 60. */
const JWT_REUSE_MS = 50 * MINUTE;

/** The ES256 provider token, reused for about 50 minutes. */
export async function apnsJwt(env: Env, now: Date = new Date()): Promise<string> {
  const cacheKey = `${env.APNS_TEAM_ID}|${env.APNS_KEY_ID}|${env.APNS_KEY}`;
  const t = now.getTime();
  if (jwtCache && jwtCache.key === cacheKey && t - jwtCache.at < JWT_REUSE_MS && t >= jwtCache.at) {
    return jwtCache.token;
  }
  const key = await importPKCS8(normalizePem(env.APNS_KEY!), "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APNS_KEY_ID! })
    .setIssuer(env.APNS_TEAM_ID!)
    .setIssuedAt(Math.floor(t / 1000))
    .sign(key);
  jwtCache = { key: cacheKey, token, at: t };
  return token;
}

/** Forgets the cached provider token (tests; and when Apple refuses it). */
export function clearApnsJwt() {
  jwtCache = null;
}

export interface PushMessage {
  title: string;
  body: string;
  data: { type: "show" | "shoutout"; postId: string };
}

interface Device {
  token: string;
  environment: PushEnvironment;
}

export function apnsPayload(msg: PushMessage) {
  return {
    aps: {
      alert: { title: msg.title, body: msg.body },
      sound: "default",
      "thread-id": "crew",
    },
    ...msg.data,
  };
}

/**
 * Sends [msg] to each device. Tokens Apple says are gone are deleted.
 * Never throws.
 */
export async function sendToDevices(
  env: Env,
  devices: Device[],
  msg: PushMessage,
): Promise<void> {
  if (!apnsConfigured(env) || devices.length === 0) return;
  let jwt: string;
  try {
    jwt = await apnsJwt(env);
  } catch (e) {
    console.error("APNs key didn't load", e);
    return;
  }
  const payload = JSON.stringify(apnsPayload(msg));
  const dead: string[] = [];
  await Promise.all(
    devices.map(async (d) => {
      const host = d.environment === "sandbox" ? APNS_SANDBOX : APNS_PRODUCTION;
      try {
        const res = await fetch(`${host}/3/device/${d.token}`, {
          method: "POST",
          headers: {
            authorization: `bearer ${jwt}`,
            "apns-topic": env.APPLE_BUNDLE_ID,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "content-type": "application/json",
          },
          body: payload,
        });
        if (res.ok) return;
        let reason = "";
        try {
          reason = String(((await res.json()) as { reason?: unknown }).reason ?? "");
        } catch {
          // No JSON body.
        }
        // Only the token's end is logged, never the whole token.
        console.error(
          `APNs refused a push: ${res.status} ${reason || "(no reason)"}` +
            ` (device …${d.token.slice(-6)}, ${d.environment})`,
        );
        if (
          res.status === 410 ||
          (res.status === 400 && (reason === "BadDeviceToken" || reason === "Unregistered"))
        ) {
          dead.push(d.token);
        } else if (res.status === 403) {
          clearApnsJwt();
        }
      } catch (e) {
        console.error(`APNs push failed (device …${d.token.slice(-6)})`, e);
      }
    }),
  );
  if (dead.length > 0) {
    await env.DB.prepare(
      "DELETE FROM push_devices WHERE token IN (SELECT value FROM json_each(?))",
    )
      .bind(JSON.stringify(dead))
      .run();
  }
}

// ---- When to send ----

/** True when a Show dated [date] was played around now. */
export function justPlayed(date: unknown, now: Date): boolean {
  if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(date)) {
    return false;
  }
  const hasOffset = /(Z|[+-]\d{2}:?\d{2})$/i.test(date);
  // Without an offset Date.parse reads it as UTC in the Worker.
  const ms = Date.parse(date);
  if (!Number.isFinite(ms)) return false;
  const t = now.getTime();
  const earliest = t - SHOW_FRESH_MS - (hasOffset ? 0 : TZ_WEST_MS);
  const latest = t + SHOW_EARLY_MS + (hasOffset ? 0 : TZ_EAST_MS);
  return ms >= earliest && ms <= latest;
}

export function showBody(show: Record<string, unknown>): string {
  const label =
    WORKOUT_LABELS[typeof show.workoutType === "string" ? show.workoutType : ""] ??
    "Easy";
  const miles = show.distanceMiles;
  if (typeof miles !== "number" || !Number.isFinite(miles) || miles <= 0) return label;
  return `${label} · ${(Math.round(miles * 10) / 10).toFixed(1)} mi`;
}

function cut(text: string, max: number): string {
  const chars = [...text];
  return chars.length <= max ? text : `${chars.slice(0, max - 1).join("")}…`;
}

/**
 * After [owner] synced Shows [newIds] that weren't on the server before:
 * tells each Crew mate who wants it about the newest one that was just
 * played and the Crew can see. Never throws.
 */
export async function notifyNewShows(
  env: Env,
  owner: string,
  newIds: string[],
  now: Date = new Date(),
): Promise<void> {
  if (!apnsConfigured(env) || newIds.length === 0) return;
  try {
    const db = env.DB;
    const { results } = await db
      .prepare(
        `SELECT s.id, s.data, pr.stage_name FROM records s
         JOIN crew_profiles pr ON pr.user_id = s.user_id
         WHERE s.user_id = ?1 AND s.kind = 'shows'
           AND s.id IN (SELECT value FROM json_each(?2))
           AND ${CREW_SHOW}`,
      )
      .bind(owner, JSON.stringify(newIds))
      .all<{ id: string; data: string; stage_name: string }>();
    const fresh = results
      .map((r) => ({ ...r, show: JSON.parse(r.data) as Record<string, unknown> }))
      .filter((r) => justPlayed(r.show.date, now))
      .sort((a, b) => String(b.show.date).localeCompare(String(a.show.date)));
    if (fresh.length === 0) return;
    const pick = fresh[0];

    const since = iso(addMs(now, -SHOW_PUSH_EVERY_MS));
    const { results: devices } = await db
      .prepare(
        `SELECT d.token, d.environment, d.user_id FROM push_devices d
         JOIN crew_profiles p ON p.user_id = d.user_id AND p.push_shows = 1
         WHERE d.user_id IN (
             SELECT CASE WHEN l.user_a = ?1 THEN l.user_b ELSE l.user_a END
             FROM crew_links l WHERE ?1 IN (l.user_a, l.user_b))
           AND NOT EXISTS (SELECT 1 FROM crew_blocks b
             WHERE (b.blocker = ?1 AND b.blocked = d.user_id)
                OR (b.blocker = d.user_id AND b.blocked = ?1))
           AND NOT EXISTS (SELECT 1 FROM push_sent ps
             WHERE ps.from_user = ?1 AND ps.to_user = d.user_id
               AND ps.kind = 'show' AND ps.sent_at > ?2)`,
      )
      .bind(owner, since)
      .all<Device & { user_id: string }>();
    if (devices.length === 0) return;

    // Record first, so a second sync right after doesn't send again.
    const mates = [...new Set(devices.map((d) => d.user_id))];
    const at = iso(now);
    await db.batch([
      db
        .prepare("DELETE FROM push_sent WHERE from_user = ? AND sent_at < ?")
        .bind(owner, iso(addMs(now, -DAY))),
      db
        .prepare(
          `INSERT INTO push_sent (from_user, to_user, kind, sent_at)
           SELECT ?1, value, 'show', ?2 FROM json_each(?3)`,
        )
        .bind(owner, at, JSON.stringify(mates)),
    ]);
    await sendToDevices(env, devices, {
      title: `${pick.stage_name} just played a Show`,
      body: showBody(pick.show),
      data: { type: "show", postId: `${owner}:${pick.id}` },
    });
  } catch (e) {
    console.error("Show push failed", e);
  }
}

/**
 * After [writer] gave a Shout-out [text] on Show [postId]
 * ("<ownerId>:<showId>"): tells the owner, unless they wrote it, turned the
 * switch off, or one blocked the other. Never throws.
 */
export async function notifyShoutout(
  env: Env,
  writer: string,
  postId: string,
  text: string,
): Promise<void> {
  if (!apnsConfigured(env)) return;
  const owner = postId.slice(0, Math.max(0, postId.indexOf(":")));
  if (!owner || owner === writer) return;
  try {
    const db = env.DB;
    const { results: devices } = await db
      .prepare(
        `SELECT d.token, d.environment, w.stage_name FROM push_devices d
         JOIN crew_profiles p ON p.user_id = d.user_id AND p.push_shoutouts = 1
         JOIN crew_profiles w ON w.user_id = ?2
         WHERE d.user_id = ?1
           AND NOT EXISTS (SELECT 1 FROM crew_blocks b
             WHERE (b.blocker = ?1 AND b.blocked = ?2)
                OR (b.blocker = ?2 AND b.blocked = ?1))`,
      )
      .bind(owner, writer)
      .all<Device & { stage_name: string }>();
    if (devices.length === 0) return;
    await sendToDevices(env, devices, {
      title: `${devices[0].stage_name} gave you a Shout-out`,
      body: cut(text, SHOUTOUT_BODY_CHARS),
      data: { type: "shoutout", postId },
    });
  } catch (e) {
    console.error("Shout-out push failed", e);
  }
}
