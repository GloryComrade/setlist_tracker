// Shout-outs: short comments on a Show from its owner and their Crew.
//
// - GET /api/crew/posts/{postId}/shoutouts -> {shoutouts: [Shoutout]},
//   oldest first, on a Show you can see. Shout-outs show while their writer
//   is the owner or in the owner's Crew, and isn't blocked either way with
//   you. Ones you reported are left out.
// - POST /api/crew/posts/{postId}/shoutouts {body} -> 201 Shoutout. 1 to 280
//   characters after trimming; at most MAX_PER_HOUR per runner.
// - DELETE /api/crew/shoutouts/{id}: its writer or the Show's owner.
// - POST /api/crew/shoutouts/{id}/report {reason}: copies the text into
//   crew_reports (post_id 'shoutout:<id>'), hides it from you and alerts
//   the developer (src/reports.ts).
// - Feed posts carry `shoutouts`, the count you would see.
//
// A writer's photo address is only given to you when they are you or in
// your Crew (GET /api/crew/avatar wouldn't serve it otherwise).

import { avatarFields } from "./avatars";
import { IS_CREW, visibleShow } from "./crew";
import { ApiError, json, noContent, readJson } from "./http";
import { addMs, HOUR, iso } from "./util";

export const MAX_SHOUTOUT_CHARS = 280;
export const MAX_PER_HOUR = 30;

export interface Shoutout {
  id: string;
  userId: string;
  stageName: string;
  color: number;
  avatarBadge: string | null;
  avatarUrl: string | null;
  body: string;
  createdAt: string;
  mine: boolean;
  /** You wrote it, or it's on your Show. */
  canDelete: boolean;
}

/** SQL true when two runners in [a] and [b] are linked and not blocked. */
const LINKED = (a: string, b: string) => `(
  EXISTS (SELECT 1 FROM crew_links l
          WHERE (l.user_a = ${a} AND l.user_b = ${b})
             OR (l.user_b = ${a} AND l.user_a = ${b}))
  AND NOT EXISTS (SELECT 1 FROM crew_blocks bl
          WHERE (bl.blocker = ${a} AND bl.blocked = ${b})
             OR (bl.blocker = ${b} AND bl.blocked = ${a})))`;

/**
 * SQL true when Shout-out [so] shows to ?1 (me): its writer is the owner or
 * in the owner's Crew, isn't blocked either way with me, and I didn't
 * report it.
 */
export const VISIBLE_SHOUTOUT = (so: string) => `(
  (${so}.user_id = ${so}.owner OR ${LINKED(`${so}.user_id`, `${so}.owner`)})
  AND NOT EXISTS (SELECT 1 FROM crew_blocks bl2
          WHERE (bl2.blocker = ?1 AND bl2.blocked = ${so}.user_id)
             OR (bl2.blocker = ${so}.user_id AND bl2.blocked = ?1))
  AND NOT EXISTS (SELECT 1 FROM crew_reports rr
          WHERE rr.reporter = ?1 AND rr.post_id = 'shoutout:' || ${so}.id))`;

function bad(message: string): ApiError {
  return new ApiError("bad_request", message);
}

function notFound(): ApiError {
  return new ApiError("not_found", "That Shout-out isn't there anymore.");
}

function showNotFound(): ApiError {
  return new ApiError("not_found", "That Show isn't in your Crew's feed anymore.");
}

type Row = {
  id: string;
  owner: string;
  show_id: string;
  user_id: string;
  body: string;
  created_at: string;
  stage_name: string;
  color: number;
  avatar_badge: string | null;
  avatar_at: string | null;
  my_crew: number;
};

function toShoutout(me: string, r: Row): Shoutout {
  const pic = avatarFields(r.user_id, r.avatar_badge, r.avatar_at);
  return {
    id: r.id,
    userId: r.user_id,
    stageName: r.stage_name,
    color: r.color,
    avatarBadge: pic.avatarBadge,
    avatarUrl: r.my_crew === 1 ? pic.avatarUrl : null,
    body: r.body,
    createdAt: r.created_at,
    mine: r.user_id === me,
    canDelete: r.user_id === me || r.owner === me,
  };
}

const SELECT = () => `SELECT so.id, so.owner, so.show_id, so.user_id, so.body, so.created_at,
    pr.stage_name, pr.color, pr.avatar_badge,
    (SELECT av.updated_at FROM crew_avatars av WHERE av.user_id = so.user_id) AS avatar_at,
    (so.user_id = ?1 OR ${IS_CREW("so.user_id")}) AS my_crew
  FROM crew_shoutouts so
  JOIN crew_profiles pr ON pr.user_id = so.user_id`;

export async function listShoutouts(db: D1Database, me: string, postId: string) {
  const show = await visibleShow(db, me, postId);
  if (!show) throw showNotFound();
  const { results } = await db
    .prepare(
      `${SELECT()}
       WHERE so.owner = ?2 AND so.show_id = ?3 AND ${VISIBLE_SHOUTOUT("so")}
       ORDER BY so.created_at, so.id`,
    )
    .bind(me, show.owner, show.id)
    .all<Row>();
  return results.map((r) => toShoutout(me, r));
}

export async function addShoutout(
  db: D1Database,
  me: string,
  postId: string,
  body: unknown,
  now: Date = new Date(),
): Promise<Shoutout> {
  const text = typeof body === "string" ? body.replace(/\s+\n/g, "\n").trim() : "";
  const chars = [...text].length;
  if (chars < 1 || chars > MAX_SHOUTOUT_CHARS) {
    throw bad(`A Shout-out needs 1 to ${MAX_SHOUTOUT_CHARS} characters.`);
  }
  const show = await visibleShow(db, me, postId);
  if (!show) throw showNotFound();
  const mine = await db
    .prepare("SELECT 1 FROM crew_profiles WHERE user_id = ?")
    .bind(me)
    .first();
  if (!mine) throw bad("Pick a stage name before giving a Shout-out.");
  const recent = await db
    .prepare(
      "SELECT count(*) AS n FROM crew_shoutouts WHERE user_id = ? AND created_at > ?",
    )
    .bind(me, iso(addMs(now, -HOUR)))
    .first<{ n: number }>();
  if ((recent?.n ?? 0) >= MAX_PER_HOUR) {
    throw new ApiError("too_many_tries", "That's a lot of Shout-outs. Try again in a bit.");
  }
  const id = crypto.randomUUID();
  await db
    .prepare(
      `INSERT INTO crew_shoutouts (id, owner, show_id, user_id, body, created_at)
       VALUES (?, ?, ?, ?, ?, ?)`,
    )
    .bind(id, show.owner, show.id, me, text, iso(now))
    .run();
  const row = await db
    .prepare(`${SELECT()} WHERE so.id = ?2`)
    .bind(me, id)
    .first<Row>();
  return toShoutout(me, row!);
}

async function findShoutout(db: D1Database, me: string, id: string) {
  return db
    .prepare(`${SELECT()} WHERE so.id = ?2 AND ${VISIBLE_SHOUTOUT("so")}`)
    .bind(me, id)
    .first<Row>();
}

export async function deleteShoutout(db: D1Database, me: string, id: string) {
  await db
    .prepare("DELETE FROM crew_shoutouts WHERE id = ?2 AND ?1 IN (user_id, owner)")
    .bind(me, id)
    .run();
}

export async function reportShoutout(
  db: D1Database,
  me: string,
  id: string,
  reason: unknown,
  now: Date = new Date(),
) {
  const text = typeof reason === "string" ? reason.trim() : "";
  if (text.length < 1 || text.length > 500) {
    throw bad("Tell us what's wrong in 1 to 500 characters.");
  }
  const row = await findShoutout(db, me, id);
  if (!row) throw notFound();
  // It must be on a Show you can still see.
  if (!(await visibleShow(db, me, `${row.owner}:${row.show_id}`))) throw notFound();
  if (row.user_id === me) throw bad("You can't report your own Shout-out.");
  await db
    .prepare(
      `INSERT INTO crew_reports
         (id, reporter, post_id, reported_user, post_data, reason, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
    .bind(
      crypto.randomUUID(),
      me,
      `shoutout:${id}`,
      row.user_id,
      JSON.stringify({ owner: row.owner, showId: row.show_id, body: row.body }),
      text,
      iso(now),
    )
    .run();
}

/** /api/crew/posts/{postId}/shoutouts. Null when no route matches. */
export async function postShoutoutsRoute(
  request: Request,
  db: D1Database,
  me: string,
  postId: string,
): Promise<Response | null> {
  if (request.method === "GET") {
    return json({ shoutouts: await listShoutouts(db, me, postId) });
  }
  if (request.method === "POST") {
    const body = await readJson(request);
    return json(await addShoutout(db, me, postId, body.body), 201);
  }
  return null;
}

/** /api/crew/shoutouts/{id}[/report]. Null when no route matches. */
export async function shoutoutRoute(
  request: Request,
  db: D1Database,
  me: string,
  parts: string[],
  notify: (reason: unknown) => Promise<unknown> = async () => {},
): Promise<Response | null> {
  const [id, what] = parts;
  if (parts.length === 1 && request.method === "DELETE") {
    await deleteShoutout(db, me, id);
    return noContent();
  }
  if (parts.length === 2 && what === "report" && request.method === "POST") {
    const reason = (await readJson(request)).reason;
    await reportShoutout(db, me, id, reason);
    await notify(reason);
    return noContent();
  }
  return null;
}
