// The Crew: running friends who see each other's Shows.
//
// Being in someone's Crew means you see all their activity: every Show they
// sync with Backstage Pass (the `records` table), except deleted ones and
// ones they marked "Keep off the Crew" (`crewPrivate: true`), plus their
// active Tour. Nothing is shared by hand anymore.
//
// Same rules as the old Supabase version
// (supabase/migrations/20261123000000_the_crew.sql):
// - You see your own Shows and profile, plus your Crew's. Anyone you
//   blocked, or who blocked you, is never in your Crew.
// - Invite codes: 8 characters from ABCDEFGHJKMNPQRSTUVWXYZ23456789, crypto
//   random, valid 7 days, reused while more than a day is left.
// - Ten wrong codes in an hour gets too_many_tries (codes from a blocked
//   runner count as wrong).
// - Encores only on Shows you can see, never your own. The feed shows how
//   many and whether one is yours, never who.
// - A post is named "<ownerId>:<showId>". The server copies the Show into a
//   report.

import type { Env } from "./env";
import { ApiError, json, noContent, readJson } from "./http";
import { addMs, DAY, HOUR, iso, isObject, randomBytes } from "./util";

export const INVITE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const INVITE_LENGTH = 8;
export const INVITE_MS = 7 * DAY;
export const MAX_MISSES_PER_HOUR = 10;
export const FEED_LIMIT = 60;
export const MATE_SHOWS_LIMIT = 500;

// ---- Shared SQL ----

/** SQL true when ?1 (me) and the user in [col] are in each other's Crew. */
const IS_CREW = (col: string) => `(
  EXISTS (SELECT 1 FROM crew_links l
          WHERE (l.user_a = ?1 AND l.user_b = ${col})
             OR (l.user_b = ?1 AND l.user_a = ${col}))
  AND NOT EXISTS (SELECT 1 FROM crew_blocks b
          WHERE (b.blocker = ?1 AND b.blocked = ${col})
             OR (b.blocker = ${col} AND b.blocked = ?1)))`;

function pair(a: string, b: string): [string, string] {
  return a < b ? [a, b] : [b, a];
}

export async function blockedEitherWay(
  db: D1Database,
  one: string,
  other: string,
): Promise<boolean> {
  const row = await db
    .prepare(
      `SELECT 1 AS x FROM crew_blocks
       WHERE (blocker = ?1 AND blocked = ?2) OR (blocker = ?2 AND blocked = ?1)
       LIMIT 1`,
    )
    .bind(one, other)
    .first();
  return row != null;
}

export async function isCrew(
  db: D1Database,
  me: string,
  other: string,
): Promise<boolean> {
  const row = await db
    .prepare(`SELECT ${IS_CREW("?2")} AS crew`)
    .bind(me, other)
    .first<{ crew: number }>();
  return row?.crew === 1;
}

// ---- Profiles ----

export interface Profile {
  userId: string;
  stageName: string;
  color: number;
  /** In The Crew from before it showed everything, and not yet OK'd. */
  allActivityPending: boolean;
}

interface ProfileRow {
  user_id: string;
  stage_name: string;
  color: number;
  all_activity_since: string | null;
}

/**
 * Runners who joined The Crew before it showed everything start with this
 * date (migration 0002): only the Shows they shared are visible until they
 * say OK in the app, which sets it to that moment.
 */
export const ALL_ACTIVITY_PENDING = "9999-12-31T00:00:00.000Z";

function toProfile(r: ProfileRow): Profile {
  return {
    userId: r.user_id,
    stageName: r.stage_name,
    color: r.color,
    allActivityPending: r.all_activity_since === ALL_ACTIVITY_PENDING,
  };
}

export async function getProfile(
  db: D1Database,
  userId: string,
): Promise<Profile | null> {
  const row = await db
    .prepare(
      "SELECT user_id, stage_name, color, all_activity_since FROM crew_profiles WHERE user_id = ?",
    )
    .bind(userId)
    .first<ProfileRow>();
  return row ? toProfile(row) : null;
}

async function requireProfile(db: D1Database, userId: string): Promise<Profile> {
  const p = await getProfile(db, userId);
  if (!p) {
    throw new ApiError(
      "need_stage_name",
      "Pick a stage name first, so your Crew knows who you are.",
    );
  }
  return p;
}

function badProfile(message: string): ApiError {
  return new ApiError("bad_request", message);
}

/**
 * Saves the stage name and color. Fields from the first Crew release
 * (alwaysShare, showOpeningNight, openingNight, tourName) are ignored, so
 * older app builds keep working.
 */
export async function saveProfile(
  db: D1Database,
  userId: string,
  body: Record<string, unknown>,
  now: Date = new Date(),
): Promise<Profile> {
  if (typeof body.stageName !== "string") {
    throw badProfile("Your stage name needs 1 to 30 characters.");
  }
  const stageName = body.stageName.replace(/\s+/g, " ").trim();
  // Count characters, not UTF-16 units, so emoji count once.
  if ([...stageName].length < 1 || [...stageName].length > 30) {
    throw badProfile("Your stage name needs 1 to 30 characters.");
  }
  const color = body.color ?? 0;
  if (typeof color !== "number" || !Number.isInteger(color) || color < 0 || color > 7) {
    throw badProfile("Pick one of the avatar colors.");
  }
  const row = await db
    .prepare(
      `INSERT INTO crew_profiles (user_id, stage_name, color, updated_at)
       VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT (user_id) DO UPDATE SET
         stage_name = excluded.stage_name, color = excluded.color,
         updated_at = excluded.updated_at,
         all_activity_since = CASE
           WHEN ?5 = 1 AND all_activity_since = ?6 THEN excluded.updated_at
           ELSE all_activity_since END
       RETURNING user_id, stage_name, color, all_activity_since`,
    )
    .bind(
      userId,
      stageName,
      color,
      iso(now),
      body.allActivity === true ? 1 : 0,
      ALL_ACTIVITY_PENDING,
    )
    .first<ProfileRow>();
  return toProfile(row!);
}

// ---- Invites ----

/** 8 characters from INVITE_ALPHABET, crypto random, without modulo bias. */
export function newInviteCode(): string {
  let out = "";
  const limit = 256 - (256 % INVITE_ALPHABET.length); // 248
  while (out.length < INVITE_LENGTH) {
    for (const b of randomBytes(16)) {
      if (b < limit && out.length < INVITE_LENGTH) {
        out += INVITE_ALPHABET[b % INVITE_ALPHABET.length];
      }
    }
  }
  return out;
}

/** "abcd-efgh " -> "ABCDEFGH". */
export function normalizeCode(code: string): string {
  return code.replace(/[^A-Za-z0-9]/g, "").toUpperCase();
}

/** Your invite code: reused while it has more than a day left. */
export async function inviteCode(
  db: D1Database,
  me: string,
  now: Date = new Date(),
): Promise<string> {
  await requireProfile(db, me);
  const found = await db
    .prepare(
      `SELECT code FROM crew_invites WHERE owner = ? AND expires_at > ?
       ORDER BY expires_at DESC LIMIT 1`,
    )
    .bind(me, iso(addMs(now, DAY)))
    .first<{ code: string }>();
  if (found) return found.code;
  await db.prepare("DELETE FROM crew_invites WHERE owner = ?").bind(me).run();
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newInviteCode();
    const res = await db
      .prepare(
        `INSERT INTO crew_invites (code, owner, created_at, expires_at)
         VALUES (?, ?, ?, ?) ON CONFLICT (code) DO NOTHING`,
      )
      .bind(code, me, iso(now), iso(addMs(now, INVITE_MS)))
      .run();
    if (res.meta.changes === 1) return code;
  }
  throw new Error("could not make a unique invite code");
}

/** Throws too_many_tries after ten wrong codes in the last hour. */
async function checkMisses(db: D1Database, me: string, now: Date): Promise<void> {
  const [, count] = await db.batch<{ n: number }>([
    // Opportunistic cleanup: nobody's misses matter after a day.
    db.prepare("DELETE FROM crew_invite_misses WHERE at < ?")
      .bind(iso(addMs(now, -DAY))),
    db.prepare(
      "SELECT count(*) AS n FROM crew_invite_misses WHERE user_id = ? AND at > ?",
    ).bind(me, iso(addMs(now, -HOUR))),
  ]);
  if ((count.results[0]?.n ?? 0) >= MAX_MISSES_PER_HOUR) {
    throw new ApiError(
      "too_many_tries",
      "That's a lot of wrong codes. Take a breather and try again in an hour.",
    );
  }
}

/**
 * The owner of the live invite [code], unless either of you blocked the
 * other. Counts a miss otherwise.
 */
async function findInvite(
  db: D1Database,
  me: string,
  code: string,
  now: Date,
): Promise<string | null> {
  await checkMisses(db, me, now);
  const row = await db
    .prepare("SELECT owner FROM crew_invites WHERE code = ? AND expires_at > ?")
    .bind(normalizeCode(code), iso(now))
    .first<{ owner: string }>();
  if (!row || (await blockedEitherWay(db, me, row.owner))) {
    await db
      .prepare("INSERT INTO crew_invite_misses (user_id, at) VALUES (?, ?)")
      .bind(me, iso(now))
      .run();
    return null;
  }
  return row.owner;
}

function inviteInvalid(): ApiError {
  return new ApiError(
    "invite_invalid",
    "That invite code doesn't work. It may have expired, so ask for a fresh one.",
  );
}

export async function previewInvite(
  db: D1Database,
  me: string,
  code: string,
  now: Date = new Date(),
) {
  const them = await findInvite(db, me, code, now);
  const profile = them ? await getProfile(db, them) : null;
  if (!them || !profile) throw inviteInvalid();
  return {
    stageName: profile.stageName,
    color: profile.color,
    alreadyCrew: them !== me && (await isCrew(db, me, them)),
    ownInvite: them === me,
  };
}

export async function joinCrew(
  db: D1Database,
  me: string,
  code: string,
  now: Date = new Date(),
): Promise<string> {
  await requireProfile(db, me);
  const them = await findInvite(db, me, code, now);
  if (!them) throw inviteInvalid();
  if (them === me) {
    throw new ApiError(
      "own_invite",
      "That's your own invite. Send it to a friend to bring them into your Crew.",
    );
  }
  const [a, b] = pair(me, them);
  await db
    .prepare(
      `INSERT INTO crew_links (user_a, user_b, created_at) VALUES (?, ?, ?)
       ON CONFLICT DO NOTHING`,
    )
    .bind(a, b, iso(now))
    .run();
  return them;
}

// ---- Tours ----

export const RACE_DISTANCES = ["fiveK", "tenK", "half", "marathon"] as const;

/** "YYYY-MM-DD" in UTC. */
export function utcDate(now: Date): string {
  return iso(now).slice(0, 10);
}

/**
 * SQL for the active Tour of the runner in [col]: their non-deleted Tour
 * with the latest setup.raceDate on or after ?2 (today, UTC). Selects
 * [what] from it (the Tour row is `t`).
 */
const ACTIVE_TOUR = (col: string, what: string) => `(
  SELECT ${what} FROM records t
  WHERE t.user_id = ${col} AND t.kind = 'tours' AND t.deleted_at IS NULL
    AND json_extract(t.data, '$.setup.raceDate') >= ?2
  ORDER BY json_extract(t.data, '$.setup.raceDate') DESC, t.id DESC
  LIMIT 1)`;

const TOUR_SUMMARY_JSON = `json_object(
    'id', t.id,
    'name', json_extract(t.data, '$.name'),
    'raceDate', json_extract(t.data, '$.setup.raceDate'),
    'raceDistance', json_extract(t.data, '$.setup.raceDistance'),
    'featuring', json(json_extract(t.data, '$.featuring')))`;

export interface Featuring {
  userId: string;
  stageName: string;
}

export interface TourSummary {
  id: string;
  name: string;
  raceDate: string;
  raceDistance: (typeof RACE_DISTANCES)[number];
  featuring: Featuring | null;
}

function toFeaturing(v: unknown): Featuring | null {
  if (!isObject(v)) return null;
  if (typeof v.userId !== "string" || typeof v.stageName !== "string") return null;
  return { userId: v.userId, stageName: v.stageName };
}

function toTourSummary(raw: string | null): TourSummary | null {
  if (!raw) return null;
  const t = JSON.parse(raw) as Record<string, unknown>;
  const distance = (RACE_DISTANCES as readonly unknown[]).includes(t.raceDistance)
    ? (t.raceDistance as TourSummary["raceDistance"])
    : "marathon";
  return {
    id: String(t.id),
    name: typeof t.name === "string" ? t.name : "Tour",
    raceDate: String(t.raceDate),
    raceDistance: distance,
    featuring: toFeaturing(t.featuring),
  };
}

// ---- Mates and blocks ----

export async function listMates(
  db: D1Database,
  me: string,
  now: Date = new Date(),
) {
  const { results } = await db
    .prepare(
      `SELECT user_id, stage_name, color, since, blocked,
              CASE WHEN blocked = 0
                THEN ${ACTIVE_TOUR("m.user_id", TOUR_SUMMARY_JSON)} END AS tour
       FROM (
         SELECT o.other AS user_id,
                coalesce(p.stage_name, 'Runner') AS stage_name,
                coalesce(p.color, 0) AS color,
                o.created_at AS since,
                0 AS blocked
         FROM (SELECT CASE WHEN user_a = ?1 THEN user_b ELSE user_a END AS other,
                      user_a, user_b, created_at
               FROM crew_links WHERE ?1 IN (user_a, user_b)) o
         LEFT JOIN crew_profiles p ON p.user_id = o.other
         WHERE NOT EXISTS (SELECT 1 FROM crew_blocks b
             WHERE (b.blocker = o.user_a AND b.blocked = o.user_b)
                OR (b.blocker = o.user_b AND b.blocked = o.user_a))
         UNION ALL
         SELECT b.blocked, coalesce(p.stage_name, 'Runner'), coalesce(p.color, 0),
                b.created_at, 1
         FROM crew_blocks b
         LEFT JOIN crew_profiles p ON p.user_id = b.blocked
         WHERE b.blocker = ?1
       ) m
       ORDER BY blocked, stage_name COLLATE NOCASE, user_id`,
    )
    .bind(me, utcDate(now))
    .all<{
      user_id: string;
      stage_name: string;
      color: number;
      since: string;
      blocked: number;
      tour: string | null;
    }>();
  return results.map((r) => ({
    userId: r.user_id,
    stageName: r.stage_name,
    color: r.color,
    since: r.since,
    tour: toTourSummary(r.tour),
    blocked: r.blocked === 1,
  }));
}

function mateNotFound(): ApiError {
  return new ApiError("not_found", "That runner isn't in your Crew.");
}

/**
 * One Crew mate (or yourself): who they are, their active Tour (the whole
 * Tour JSON) and their Shows, newest first. 404 unless they're in your Crew.
 */
export async function mateDetail(
  db: D1Database,
  me: string,
  other: string,
  now: Date = new Date(),
) {
  const row = await db
    .prepare(
      `SELECT coalesce(p.stage_name, 'Runner') AS stage_name,
              coalesce(p.color, 0) AS color,
              CASE WHEN u.id = ?1 THEN u.created_at
                ELSE (SELECT l.created_at FROM crew_links l
                      WHERE (l.user_a = ?1 AND l.user_b = u.id)
                         OR (l.user_b = ?1 AND l.user_a = u.id)) END AS since,
              ${ACTIVE_TOUR("u.id", "t.data")} AS tour
       FROM users u
       LEFT JOIN crew_profiles p ON p.user_id = u.id
       WHERE u.id = ?3 AND (u.id = ?1 OR ${IS_CREW("u.id")})`,
    )
    .bind(me, utcDate(now), other)
    .first<{ stage_name: string; color: number; since: string; tour: string | null }>();
  if (!row) throw mateNotFound();
  return {
    mate: {
      userId: other,
      stageName: row.stage_name,
      color: row.color,
      since: row.since,
    },
    tour: row.tour ? JSON.parse(row.tour) : null,
    shows: await crewShows(db, me, { owner: other, limit: MATE_SHOWS_LIMIT }),
  };
}

export async function leaveCrew(db: D1Database, me: string, other: string) {
  const [a, b] = pair(me, other);
  await db
    .prepare("DELETE FROM crew_links WHERE user_a = ? AND user_b = ?")
    .bind(a, b)
    .run();
}

export async function block(
  db: D1Database,
  me: string,
  other: unknown,
  now: Date = new Date(),
) {
  const exists = typeof other === "string" && other !== me &&
    (await db.prepare("SELECT 1 AS x FROM users WHERE id = ?").bind(other).first());
  if (!exists) {
    throw new ApiError("cant_block", "We couldn't block that runner.");
  }
  const [a, b] = pair(me, other as string);
  await db.batch([
    db.prepare("DELETE FROM crew_links WHERE user_a = ? AND user_b = ?").bind(a, b),
    db.prepare(
      `INSERT INTO crew_blocks (blocker, blocked, created_at) VALUES (?, ?, ?)
       ON CONFLICT DO NOTHING`,
    ).bind(me, other, iso(now)),
  ]);
}

/** Removes your own block only. A block the other runner made stays. */
export async function unblock(db: D1Database, me: string, other: string) {
  await db
    .prepare("DELETE FROM crew_blocks WHERE blocker = ? AND blocked = ?")
    .bind(me, other)
    .run();
}

// ---- Shows the Crew sees ----

/**
 * SQL true when the synced Show `s` can be seen by its owner's Crew: not
 * deleted, not marked "Keep off the Crew", and, for runners who joined The
 * Crew before it showed everything, logged after that change or shared
 * before it (migration 0002).
 */
const CREW_SHOW = `(s.kind = 'shows' AND s.deleted_at IS NULL
  AND coalesce(json_extract(s.data, '$.crewPrivate'), 0) = 0
  AND NOT EXISTS (
    SELECT 1 FROM crew_profiles op
    WHERE op.user_id = s.user_id
      AND op.all_activity_since IS NOT NULL
      AND coalesce(json_extract(s.data, '$.createdAt'), '') < op.all_activity_since
      AND NOT EXISTS (SELECT 1 FROM crew_posts old
                      WHERE old.owner = s.user_id AND old.show_id = s.id)))`;

/** The ids of ?1 (me) and everyone in my Crew. */
const ME_AND_CREW = `(
  SELECT ?1
  UNION
  SELECT CASE WHEN l.user_a = ?1 THEN l.user_b ELSE l.user_a END
  FROM crew_links l WHERE ?1 IN (l.user_a, l.user_b))`;

/** "<ownerId>:<showId>" -> its parts, or null. */
export function parsePostId(postId: string): { owner: string; showId: string } | null {
  const i = postId.indexOf(":");
  if (i < 1 || i === postId.length - 1) return null;
  return { owner: postId.slice(0, i), showId: postId.slice(i + 1) };
}

export function postId(owner: string, showId: string): string {
  return `${owner}:${showId}`;
}

/**
 * Shows [me] can see, newest Show date first, as feed posts: from [owner]
 * only, or from me and my whole Crew. Leaves out Shows I reported.
 */
async function crewShows(
  db: D1Database,
  me: string,
  opts: { owner?: string; limit: number },
) {
  const owners = opts.owner ? "(?2)" : ME_AND_CREW;
  const { results } = await db
    .prepare(
      `SELECT s.user_id AS owner, s.id, s.data, s.updated_at,
              pr.stage_name, pr.color,
              json_extract(g.data, '$.name') AS gear_name,
              (SELECT count(*) FROM crew_encores_v2 e
               WHERE e.owner = s.user_id AND e.show_id = s.id) AS encores,
              EXISTS (SELECT 1 FROM crew_encores_v2 e
                      WHERE e.owner = s.user_id AND e.show_id = s.id
                        AND e.user_id = ?1) AS encored_by_me
       FROM records s
       JOIN crew_profiles pr ON pr.user_id = s.user_id
       LEFT JOIN records g ON g.kind = 'gear'
         AND g.id = json_extract(s.data, '$.gearId')
         AND g.user_id = s.user_id AND g.deleted_at IS NULL
       WHERE s.user_id IN ${owners}
         AND ${CREW_SHOW}
         AND (s.user_id = ?1 OR ${IS_CREW("s.user_id")})
         AND NOT EXISTS (SELECT 1 FROM crew_reports r
                         WHERE r.reporter = ?1 AND r.post_id = s.id
                           AND r.reported_user = s.user_id)
       ORDER BY json_extract(s.data, '$.date') DESC, s.id DESC
       LIMIT ${opts.limit}`,
    )
    .bind(me, ...(opts.owner ? [opts.owner] : []))
    .all<{
      owner: string;
      id: string;
      data: string;
      updated_at: string;
      stage_name: string;
      color: number;
      gear_name: unknown;
      encores: number;
      encored_by_me: number;
    }>();
  return results.map((r) => ({
    id: postId(r.owner, r.id),
    ownerId: r.owner,
    stageName: r.stage_name,
    color: r.color,
    showId: r.id,
    show: JSON.parse(r.data),
    gearName: typeof r.gear_name === "string" ? r.gear_name : null,
    sharedAt: r.updated_at,
    encores: r.encores,
    encoredByMe: r.encored_by_me === 1,
    mine: r.owner === me,
  }));
}

export async function feed(db: D1Database, me: string) {
  return crewShows(db, me, { limit: FEED_LIMIT });
}

/** A Show the signed-in runner [me] can see (their own, or their Crew's). */
async function visibleShow(db: D1Database, me: string, id: string) {
  const parsed = parsePostId(id);
  if (!parsed) return null;
  return db
    .prepare(
      `SELECT s.user_id AS owner, s.id, s.data FROM records s
       WHERE s.user_id = ?2 AND s.id = ?3 AND ${CREW_SHOW}
         AND (s.user_id = ?1 OR ${IS_CREW("s.user_id")})`,
    )
    .bind(me, parsed.owner, parsed.showId)
    .first<{ owner: string; id: string; data: string }>();
}

function postNotFound(): ApiError {
  return new ApiError("not_found", "That Show isn't in your Crew's feed anymore.");
}

export async function encore(
  db: D1Database,
  me: string,
  id: string,
  now: Date = new Date(),
) {
  const show = await visibleShow(db, me, id);
  if (!show) throw postNotFound();
  if (show.owner === me) {
    throw new ApiError("bad_request", "You can't give your own Show an Encore.");
  }
  await db
    .prepare(
      `INSERT INTO crew_encores_v2 (owner, show_id, user_id, created_at)
       VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING`,
    )
    .bind(show.owner, show.id, me, iso(now))
    .run();
}

export async function unencore(db: D1Database, me: string, id: string) {
  const parsed = parsePostId(id);
  if (!parsed) return;
  await db
    .prepare(
      "DELETE FROM crew_encores_v2 WHERE owner = ? AND show_id = ? AND user_id = ?",
    )
    .bind(parsed.owner, parsed.showId, me)
    .run();
}

/** Reports a Show. The server copies the Show's data into the report. */
export async function report(
  db: D1Database,
  me: string,
  id: string,
  reason: unknown,
  now: Date = new Date(),
) {
  const text = typeof reason === "string" ? reason.trim() : "";
  if (text.length < 1 || text.length > 500) {
    throw new ApiError(
      "bad_request",
      "Tell us what's wrong in 1 to 500 characters.",
    );
  }
  const show = await visibleShow(db, me, id);
  if (!show) throw postNotFound();
  if (show.owner === me) {
    throw new ApiError("bad_request", "You can't report your own Show.");
  }
  await db
    .prepare(
      `INSERT INTO crew_reports
         (id, reporter, post_id, reported_user, post_data, reason, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
    .bind(crypto.randomUUID(), me, show.id, show.owner, show.data, text, iso(now))
    .run();
}

// ---- Routes ----

function stringField(body: Record<string, unknown>, name: string): string {
  const v = body[name];
  if (typeof v !== "string") {
    throw new ApiError("bad_request", "That request didn't make sense.");
  }
  return v;
}

/** Handles /api/crew/* for the signed-in [me]. Null when no route matches. */
export async function crewRoute(
  request: Request,
  env: Env,
  me: string,
  parts: string[],
): Promise<Response | null> {
  const db = env.DB;
  const m = request.method;
  const [a, b, c] = parts;
  const n = parts.length;

  if (a === "profile" && n === 1) {
    if (m === "GET") return json(await getProfile(db, me));
    if (m === "PUT") return json(await saveProfile(db, me, await readJson(request)));
  }
  if (a === "invite" && n === 1 && m === "POST") {
    return json({ code: await inviteCode(db, me) });
  }
  if (a === "invite" && n === 2 && m === "GET") {
    return json(await previewInvite(db, me, b));
  }
  if (a === "join" && n === 1 && m === "POST") {
    const code = stringField(await readJson(request), "code");
    return json({ userId: await joinCrew(db, me, code) });
  }
  if (a === "mates" && n === 1 && m === "GET") {
    return json({ mates: await listMates(db, me) });
  }
  if (a === "mates" && n === 2 && m === "GET") {
    return json(await mateDetail(db, me, b));
  }
  if (a === "mates" && n === 2 && m === "DELETE") {
    await leaveCrew(db, me, b);
    return noContent();
  }
  if (a === "blocks" && n === 1 && m === "POST") {
    await block(db, me, (await readJson(request)).userId);
    return noContent();
  }
  if (a === "blocks" && n === 2 && m === "DELETE") {
    await unblock(db, me, b);
    return noContent();
  }
  if (a === "feed" && n === 1 && m === "GET") {
    return json({ posts: await feed(db, me) });
  }
  // Hand-picked sharing is gone (your Crew sees every Show). These answer
  // as before and do nothing, so older app builds don't show errors.
  if (a === "shared" && n === 1 && m === "GET") {
    return json({ shared: {} });
  }
  if (a === "shared" && n === 2 && (m === "PUT" || m === "DELETE")) {
    return noContent();
  }
  if (a === "posts" && n === 3 && c === "encore") {
    if (m === "PUT") {
      await encore(db, me, b);
      return noContent();
    }
    if (m === "DELETE") {
      await unencore(db, me, b);
      return noContent();
    }
  }
  if (a === "posts" && n === 3 && c === "report" && m === "POST") {
    await report(db, me, b, (await readJson(request)).reason);
    return noContent();
  }
  return null;
}
