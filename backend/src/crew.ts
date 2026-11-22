// The Crew: running friends who share Shows with each other.
//
// Same rules as the old Supabase version
// (supabase/migrations/20261123000000_the_crew.sql):
// - You see your own posts and profile, plus your Crew's. Anyone you
//   blocked, or who blocked you, is never in your Crew.
// - Invite codes: 8 characters from ABCDEFGHJKMNPQRSTUVWXYZ23456789, crypto
//   random, valid 7 days, reused while more than a day is left.
// - Ten wrong codes in an hour gets too_many_tries (codes from a blocked
//   runner count as wrong).
// - Encores only on posts you can see, never your own. The feed shows how
//   many and whether one is yours, never who.
// - The server sets sharedAt and copies the post into a report.

import type { Env } from "./env";
import { ApiError, json, noContent, readJson } from "./http";
import { addMs, byteLength, DAY, HOUR, iso, isObject, normalizeIso, randomBytes } from "./util";

export const INVITE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const INVITE_LENGTH = 8;
export const INVITE_MS = 7 * DAY;
export const MAX_MISSES_PER_HOUR = 10;
export const FEED_LIMIT = 60;
export const MAX_SHOW_BYTES = 8 * 1024;

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
  alwaysShare: boolean;
  showOpeningNight: boolean;
  openingNight: string | null;
  tourName: string | null;
}

interface ProfileRow {
  user_id: string;
  stage_name: string;
  color: number;
  always_share: number;
  show_opening_night: number;
  opening_night: string | null;
  tour_name: string | null;
}

function toProfile(r: ProfileRow): Profile {
  return {
    userId: r.user_id,
    stageName: r.stage_name,
    color: r.color,
    alwaysShare: r.always_share === 1,
    showOpeningNight: r.show_opening_night === 1,
    openingNight: r.opening_night,
    tourName: r.tour_name,
  };
}

export async function getProfile(
  db: D1Database,
  userId: string,
): Promise<Profile | null> {
  const row = await db
    .prepare("SELECT * FROM crew_profiles WHERE user_id = ?")
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

function optionalBool(v: unknown, name: string): boolean {
  if (v == null) return false;
  if (typeof v !== "boolean") throw badProfile(`${name} should be true or false.`);
  return v;
}

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
  const alwaysShare = optionalBool(body.alwaysShare, "alwaysShare");
  const showOpeningNight = optionalBool(body.showOpeningNight, "showOpeningNight");
  let openingNight: string | null = null;
  let tourName: string | null = null;
  if (showOpeningNight) {
    if (body.openingNight != null) {
      if (
        typeof body.openingNight !== "string" ||
        !/^\d{4}-\d{2}-\d{2}$/.test(body.openingNight) ||
        !Number.isFinite(Date.parse(`${body.openingNight}T00:00:00Z`))
      ) {
        throw badProfile("Opening Night should be a date (YYYY-MM-DD).");
      }
      openingNight = body.openingNight;
    }
    if (body.tourName != null) {
      if (typeof body.tourName !== "string") {
        throw badProfile("Your Tour's name should be text.");
      }
      tourName = body.tourName.trim() || null;
      if (tourName && tourName.length > 60) {
        throw badProfile("Your Tour's name can be up to 60 characters.");
      }
    }
  }
  const row = await db
    .prepare(
      `INSERT INTO crew_profiles (user_id, stage_name, color, always_share,
         show_opening_night, opening_night, tour_name, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT (user_id) DO UPDATE SET
         stage_name = excluded.stage_name, color = excluded.color,
         always_share = excluded.always_share,
         show_opening_night = excluded.show_opening_night,
         opening_night = excluded.opening_night,
         tour_name = excluded.tour_name, updated_at = excluded.updated_at
       RETURNING *`,
    )
    .bind(
      userId,
      stageName,
      color,
      alwaysShare ? 1 : 0,
      showOpeningNight ? 1 : 0,
      openingNight,
      tourName,
      iso(now),
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

// ---- Mates and blocks ----

export async function listMates(db: D1Database, me: string) {
  const { results } = await db
    .prepare(
      `SELECT user_id, stage_name, color, opening_night, tour_name, since, blocked
       FROM (
         SELECT o.other AS user_id,
                coalesce(p.stage_name, 'Runner') AS stage_name,
                coalesce(p.color, 0) AS color,
                p.opening_night, p.tour_name, o.created_at AS since,
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
                NULL, NULL, b.created_at, 1
         FROM crew_blocks b
         LEFT JOIN crew_profiles p ON p.user_id = b.blocked
         WHERE b.blocker = ?1
       )
       ORDER BY blocked, stage_name COLLATE NOCASE, user_id`,
    )
    .bind(me)
    .all<{
      user_id: string;
      stage_name: string;
      color: number;
      opening_night: string | null;
      tour_name: string | null;
      since: string;
      blocked: number;
    }>();
  return results.map((r) => ({
    userId: r.user_id,
    stageName: r.stage_name,
    color: r.color,
    since: r.since,
    openingNight: r.opening_night,
    tourName: r.tour_name,
    blocked: r.blocked === 1,
  }));
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

// ---- Shared Shows ----

/** A post the signed-in runner [me] can see (their own, or their Crew's). */
async function visiblePost(db: D1Database, me: string, postId: string) {
  return db
    .prepare(
      `SELECT p.id, p.owner, p.data FROM crew_posts p
       WHERE p.id = ?2 AND (p.owner = ?1 OR ${IS_CREW("p.owner")})`,
    )
    .bind(me, postId)
    .first<{ id: string; owner: string; data: string }>();
}

function postNotFound(): ApiError {
  return new ApiError("not_found", "That Show isn't shared with you anymore.");
}

export async function feed(db: D1Database, me: string) {
  const { results } = await db
    .prepare(
      `SELECT p.id, p.owner, p.show_id, p.data, p.created_at,
              pr.stage_name, pr.color,
              (SELECT count(*) FROM crew_encores e WHERE e.post_id = p.id) AS encores,
              EXISTS (SELECT 1 FROM crew_encores e
                      WHERE e.post_id = p.id AND e.user_id = ?1) AS encored_by_me
       FROM crew_posts p
       JOIN crew_profiles pr ON pr.user_id = p.owner
       WHERE (p.owner = ?1 OR ${IS_CREW("p.owner")})
         AND NOT EXISTS (SELECT 1 FROM crew_reports r
                         WHERE r.reporter = ?1 AND r.post_id = p.id)
       ORDER BY p.created_at DESC, p.id DESC
       LIMIT ${FEED_LIMIT}`,
    )
    .bind(me)
    .all<{
      id: string;
      owner: string;
      show_id: string;
      data: string;
      created_at: string;
      stage_name: string;
      color: number;
      encores: number;
      encored_by_me: number;
    }>();
  return results.map((r) => ({
    id: r.id,
    ownerId: r.owner,
    stageName: r.stage_name,
    color: r.color,
    showId: r.show_id,
    show: JSON.parse(r.data),
    sharedAt: r.created_at,
    encores: r.encores,
    encoredByMe: r.encored_by_me === 1,
    mine: r.owner === me,
  }));
}

export async function listShared(db: D1Database, me: string) {
  const { results } = await db
    .prepare(
      `SELECT show_id, show_updated_at,
              json_type(data, '$.notes') = 'text' AS includes_notes
       FROM crew_posts WHERE owner = ?`,
    )
    .bind(me)
    .all<{ show_id: string; show_updated_at: string; includes_notes: number }>();
  const shared: Record<string, { showUpdatedAt: string; includesNotes: boolean }> = {};
  for (const r of results) {
    shared[r.show_id] = {
      showUpdatedAt: r.show_updated_at,
      includesNotes: r.includes_notes === 1,
    };
  }
  return shared;
}

export async function share(
  db: D1Database,
  me: string,
  showId: string,
  body: Record<string, unknown>,
  now: Date = new Date(),
) {
  await requireProfile(db, me);
  if (!showId || showId.length > 100) {
    throw new ApiError("bad_request", "That Show can't be shared.");
  }
  if (!isObject(body.show)) {
    throw new ApiError("bad_request", "That Show can't be shared.");
  }
  const data = JSON.stringify(body.show);
  if (byteLength(data) > MAX_SHOW_BYTES) {
    throw new ApiError(
      "bad_request",
      "That Show is too big to share. Try leaving the notes out.",
    );
  }
  const showUpdatedAt = normalizeIso(body.showUpdatedAt);
  if (!showUpdatedAt) {
    throw new ApiError("bad_request", "That Show can't be shared.");
  }
  // sharedAt (created_at) is the server's clock and survives re-sharing, so
  // nobody can pin a post to the top of the feed.
  await db
    .prepare(
      `INSERT INTO crew_posts
         (id, owner, show_id, data, show_updated_at, created_at, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?6)
       ON CONFLICT (owner, show_id) DO UPDATE SET
         data = excluded.data, show_updated_at = excluded.show_updated_at,
         updated_at = excluded.updated_at`,
    )
    .bind(crypto.randomUUID(), me, showId, data, showUpdatedAt, iso(now))
    .run();
}

/** Stops sharing a Show. Its Encores go with it; reports stay. */
export async function unshare(db: D1Database, me: string, showId: string) {
  await db.batch([
    db.prepare(
      `DELETE FROM crew_encores WHERE post_id IN
         (SELECT id FROM crew_posts WHERE owner = ? AND show_id = ?)`,
    ).bind(me, showId),
    db.prepare("DELETE FROM crew_posts WHERE owner = ? AND show_id = ?")
      .bind(me, showId),
  ]);
}

export async function encore(
  db: D1Database,
  me: string,
  postId: string,
  now: Date = new Date(),
) {
  const post = await visiblePost(db, me, postId);
  if (!post) throw postNotFound();
  if (post.owner === me) {
    throw new ApiError("bad_request", "You can't give your own Show an Encore.");
  }
  await db
    .prepare(
      `INSERT INTO crew_encores (post_id, user_id, created_at) VALUES (?, ?, ?)
       ON CONFLICT DO NOTHING`,
    )
    .bind(postId, me, iso(now))
    .run();
}

export async function unencore(db: D1Database, me: string, postId: string) {
  await db
    .prepare("DELETE FROM crew_encores WHERE post_id = ? AND user_id = ?")
    .bind(postId, me)
    .run();
}

/** Reports a post. The server copies the post's data into the report. */
export async function report(
  db: D1Database,
  me: string,
  postId: string,
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
  const post = await visiblePost(db, me, postId);
  if (!post) throw postNotFound();
  if (post.owner === me) {
    throw new ApiError("bad_request", "You can't report your own Show.");
  }
  await db
    .prepare(
      `INSERT INTO crew_reports
         (id, reporter, post_id, reported_user, post_data, reason, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
    .bind(crypto.randomUUID(), me, post.id, post.owner, post.data, text, iso(now))
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
  if (a === "shared" && n === 1 && m === "GET") {
    return json({ shared: await listShared(db, me) });
  }
  if (a === "shared" && n === 2) {
    if (m === "PUT") {
      await share(db, me, b, await readJson(request));
      return noContent();
    }
    if (m === "DELETE") {
      await unshare(db, me, b);
      return noContent();
    }
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
