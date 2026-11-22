// Push notifications through Apple's APNs, for "Maya played a Show".
//
// - PUT /api/push/device {token, sandbox?} -> 204. Registers this phone
//   for the signed-in runner (moving the token from any other account).
// - DELETE /api/push/device/{token} -> 204. Forgets it (sign-out).
//
// When a runner syncs a Show that is new to the server, recent, and visible
// to their Crew, every Crew mate who hasn't turned off "Tell me when my Crew
// plays a Show" (crew_profiles.notify_shows) gets one notification. Blocks
// work both ways. Old Shows (an Apple Health import, a new phone syncing
// everything) never notify.
//
// Secrets: APNS_KEY (the .p8 key with APNs enabled) and APNS_KEY_ID; the
// team is APPLE_TEAM_ID and the topic APPLE_BUNDLE_ID. Without them nothing
// is sent and everything else works.

import { importPKCS8, SignJWT } from "jose";
import { CREW_SHOW, IS_CREW } from "./crew";
import type { Env } from "./env";
import { ApiError, noContent, readJson } from "./http";
import { normalizePem } from "./oauth";
import { addMs, DAY, HOUR, iso } from "./util";

/** A Show notifies only if it was made, and happened, this recently. */
export const NOTIFY_WINDOW_MS = 36 * HOUR;

/** APNs device tokens are 64 hex characters today; allow some growth. */
const TOKEN_RE = /^[0-9a-f]{64,200}$/;

export type FetchLike = (input: string, init: RequestInit) => Promise<Response>;

function badToken(): ApiError {
  return new ApiError("bad_request", "That notification address didn't make sense.");
}

export async function registerDevice(
  db: D1Database,
  me: string,
  body: Record<string, unknown>,
  now: Date = new Date(),
): Promise<void> {
  const token = typeof body.token === "string" ? body.token.toLowerCase() : "";
  if (!TOKEN_RE.test(token)) throw badToken();
  await db
    .prepare(
      `INSERT INTO push_devices (token, user_id, sandbox, updated_at)
       VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT (token) DO UPDATE SET
         user_id = excluded.user_id, sandbox = excluded.sandbox,
         updated_at = excluded.updated_at`,
    )
    .bind(token, me, body.sandbox === true ? 1 : 0, iso(now))
    .run();
}

export async function forgetDevice(db: D1Database, me: string, token: string) {
  await db
    .prepare("DELETE FROM push_devices WHERE token = ?1 AND user_id = ?2")
    .bind(token.toLowerCase(), me)
    .run();
}

/** /api/push/... ; [parts] is the path after "push". */
export async function pushDeviceRoute(
  request: Request,
  env: Env,
  me: string,
  parts: string[],
): Promise<Response | null> {
  const [a, b] = parts;
  if (a !== "device") return null;
  if (parts.length === 1 && request.method === "PUT") {
    await registerDevice(env.DB, me, await readJson(request));
    return noContent();
  }
  if (parts.length === 2 && request.method === "DELETE") {
    await forgetDevice(env.DB, me, b);
    return noContent();
  }
  return null;
}

// ---- Which Shows notify, and whom ----

export interface ShowNotice {
  title: string;
  body: string;
  ownerId: string;
  showId: string;
}

/** Ids among [ids] that [userId] already has on the server. */
export async function existingShowIds(
  db: D1Database,
  userId: string,
  ids: string[],
): Promise<Set<string>> {
  if (ids.length === 0) return new Set();
  const { results } = await db
    .prepare(
      `SELECT id FROM records WHERE kind = 'shows' AND user_id = ?1
         AND id IN (SELECT value FROM json_each(?2))`,
    )
    .bind(userId, JSON.stringify(ids))
    .all<{ id: string }>();
  return new Set(results.map((r) => r.id));
}

function miles(n: unknown): string | null {
  if (typeof n !== "number" || !Number.isFinite(n) || n <= 0) return null;
  const r = Math.round(n * 10) / 10;
  return `${Number.isInteger(r) ? r.toFixed(0) : r.toFixed(1)} mi`;
}

const WORKOUTS: Record<string, string> = {
  easy: "Easy",
  recovery: "Recovery",
  long: "Headliner",
  tempo: "Tempo",
  intervals: "Intervals",
  race: "Opening Night",
};

/** "Maya played a Show" / "6.2 mi Tempo · Studio Session". */
export function noticeText(stageName: string, show: Record<string, unknown>) {
  const venue = show.venue === "studio" ? "Studio Session" : "Live Show";
  const workout = typeof show.workoutType === "string" ? WORKOUTS[show.workoutType] : undefined;
  const dist = miles(show.distanceMiles);
  const first = [dist, workout].filter(Boolean).join(" ");
  return {
    title: `${stageName} played a Show`,
    body: first ? `${first} · ${venue}` : venue,
  };
}

/**
 * The newest of [showIds] (just created on the server by [owner]) that
 * should notify the Crew, or null. The Show must be visible to the Crew,
 * and both made and dated within NOTIFY_WINDOW_MS of [now].
 */
export async function noticeFor(
  db: D1Database,
  owner: string,
  showIds: string[],
  now: Date = new Date(),
): Promise<ShowNotice | null> {
  if (showIds.length === 0) return null;
  const since = iso(addMs(now, -NOTIFY_WINDOW_MS));
  // Show dates are local times without a zone; a day of slack covers that.
  const sinceDate = iso(addMs(now, -NOTIFY_WINDOW_MS - DAY)).slice(0, 19);
  const row = await db
    .prepare(
      `SELECT s.id, s.data, pr.stage_name FROM records s
       JOIN crew_profiles pr ON pr.user_id = s.user_id
       WHERE s.user_id = ?1 AND s.id IN (SELECT value FROM json_each(?2))
         AND ${CREW_SHOW}
         AND coalesce(json_extract(s.data, '$.createdAt'), '') >= ?3
         AND substr(coalesce(json_extract(s.data, '$.date'), ''), 1, 19) >= ?4
       ORDER BY json_extract(s.data, '$.date') DESC LIMIT 1`,
    )
    .bind(owner, JSON.stringify(showIds), since, sinceDate)
    .first<{ id: string; data: string; stage_name: string }>();
  if (!row) return null;
  const text = noticeText(row.stage_name, JSON.parse(row.data));
  return { ...text, ownerId: owner, showId: row.id };
}

/** Phones of [owner]'s Crew mates who want Show notifications. */
export async function crewDevices(db: D1Database, owner: string) {
  const { results } = await db
    .prepare(
      `SELECT d.token, d.sandbox, d.user_id FROM push_devices d
       JOIN crew_profiles pr ON pr.user_id = d.user_id
       WHERE pr.notify_shows = 1 AND d.user_id <> ?1
         AND ${IS_CREW("d.user_id")}`,
    )
    .bind(owner)
    .all<{ token: string; sandbox: number; user_id: string }>();
  return results;
}

// ---- APNs ----

let cachedJwt: { kid: string; token: string; at: number } | null = null;

/** The provider token, reused for 50 minutes (Apple allows up to 60). */
async function providerToken(env: Env, now: number): Promise<string> {
  if (cachedJwt && cachedJwt.kid === env.APNS_KEY_ID && now - cachedJwt.at < 50 * 60_000) {
    return cachedJwt.token;
  }
  const key = await importPKCS8(normalizePem(env.APNS_KEY!), "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.APNS_KEY_ID! })
    .setIssuer(env.APPLE_TEAM_ID!)
    .setIssuedAt(Math.floor(now / 1000))
    .sign(key);
  cachedJwt = { kid: env.APNS_KEY_ID!, token, at: now };
  return token;
}

export function pushConfigured(env: Env): boolean {
  return Boolean(env.APNS_KEY && env.APNS_KEY_ID && env.APPLE_TEAM_ID);
}

/**
 * Sends [notice] to every phone in [devices]. Tokens APNs says are dead are
 * deleted. Returns how many APNs accepted.
 */
export async function sendNotice(
  env: Env,
  devices: { token: string; sandbox: number }[],
  notice: ShowNotice,
  f: FetchLike = fetch,
  now: number = Date.now(),
): Promise<number> {
  if (!pushConfigured(env) || devices.length === 0) return 0;
  const jwt = await providerToken(env, now);
  const payload = JSON.stringify({
    aps: {
      alert: { title: notice.title, body: notice.body },
      sound: "default",
      "thread-id": `crew-${notice.ownerId}`,
    },
    path: `/crew/mate/${notice.ownerId}`,
  });
  let sent = 0;
  const dead: string[] = [];
  await Promise.all(
    devices.map(async (d) => {
      const host = d.sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
      try {
        const res = await f(`https://${host}/3/device/${d.token}`, {
          method: "POST",
          headers: {
            authorization: `bearer ${jwt}`,
            "apns-topic": env.APPLE_BUNDLE_ID,
            "apns-push-type": "alert",
            "apns-priority": "10",
            "apns-collapse-id": `show-${notice.showId}`.slice(0, 64),
            "content-type": "application/json",
          },
          body: payload,
        });
        if (res.ok) {
          sent++;
          return;
        }
        const reason = await res
          .json<{ reason?: string }>()
          .then((j) => j.reason ?? "")
          .catch(() => "");
        if (res.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered") {
          dead.push(d.token);
        } else {
          console.error("APNs refused a notification", res.status, reason);
        }
      } catch (e) {
        console.error("APNs request failed", e);
      }
    }),
  );
  if (dead.length > 0) {
    await env.DB.prepare("DELETE FROM push_devices WHERE token IN (SELECT value FROM json_each(?1))")
      .bind(JSON.stringify(dead))
      .run();
  }
  return sent;
}

/** After [owner] synced [newIds]: tell their Crew about the newest one. */
export async function notifyCrewOfShows(
  env: Env,
  owner: string,
  newIds: string[],
  f: FetchLike = fetch,
  now: Date = new Date(),
): Promise<number> {
  if (!pushConfigured(env) || newIds.length === 0) return 0;
  const notice = await noticeFor(env.DB, owner, newIds, now);
  if (!notice) return 0;
  return sendNotice(env, await crewDevices(env.DB, owner), notice, f, now.getTime());
}
