// "Seen by" and who gave Encores on a Show.
//
// - PUT /api/crew/posts/{postId}/seen records that you saw a Crew mate's
//   Show (opened it, or its feed card stayed on screen). Your own Shows,
//   Shows you can't see and runners who turned off "Let my Crew know when
//   I've seen their Shows" (crew_profiles.share_views) record nothing. The
//   first view is kept.
// - GET /api/crew/posts/{postId}/audience lists who gave the Show an Encore
//   and, for the Show's owner only, who saw it. Only you and your Crew are
//   named; anyone else (an Encore from someone outside your Crew, or a
//   runner who left or was blocked) is counted in `otherEncores` or left out.
// - Feed posts that are yours carry `seenBy: {count, names}` (the three
//   latest stage names); everyone else's carry null.

import { avatarFields } from "./avatars";
import { IS_CREW, visibleShow } from "./crew";
import { ApiError, json, noContent } from "./http";
import { iso } from "./util";

export const SEEN_NAMES = 3;

export interface Person {
  userId: string;
  stageName: string;
  color: number;
  avatarBadge: string | null;
  avatarUrl: string | null;
  at: string;
}

export interface SeenSummary {
  count: number;
  names: string[];
}

function notFound(): ApiError {
  return new ApiError("not_found", "That Show isn't in your Crew's feed anymore.");
}

export async function markSeen(
  db: D1Database,
  me: string,
  id: string,
  now: Date = new Date(),
) {
  const show = await visibleShow(db, me, id);
  if (!show) throw notFound();
  if (show.owner === me) return;
  await db
    .prepare(
      `INSERT INTO crew_show_views (owner, show_id, user_id, seen_at)
       SELECT ?1, ?2, ?3, ?4
       WHERE coalesce((SELECT share_views FROM crew_profiles
                       WHERE user_id = ?3), 1) = 1
       ON CONFLICT DO NOTHING`,
    )
    .bind(show.owner, show.id, me, iso(now))
    .run();
}

/** Deletes every view [me] left (the switch was turned off). */
export async function forgetMyViews(db: D1Database, me: string) {
  await db.prepare("DELETE FROM crew_show_views WHERE user_id = ?").bind(me).run();
}

type PersonRow = {
  user_id: string;
  stage_name: string;
  color: number;
  avatar_badge: string | null;
  avatar_at: string | null;
  at: string;
};

function toPerson(r: PersonRow): Person {
  return {
    userId: r.user_id,
    stageName: r.stage_name,
    color: r.color,
    ...avatarFields(r.user_id, r.avatar_badge, r.avatar_at),
    at: r.at,
  };
}

const PERSON = (col: string) => `${col} AS user_id, pr.stage_name, pr.color,
  pr.avatar_badge,
  (SELECT av.updated_at FROM crew_avatars av WHERE av.user_id = ${col}) AS avatar_at`;

export async function audience(db: D1Database, me: string, id: string) {
  const show = await visibleShow(db, me, id);
  if (!show) throw notFound();
  const { results: encoreRows } = await db
    .prepare(
      `SELECT ${PERSON("e.user_id")}, e.created_at AS at,
              (e.user_id = ?1 OR ${IS_CREW("e.user_id")}) AS named
       FROM crew_encores_v2 e
       JOIN crew_profiles pr ON pr.user_id = e.user_id
       WHERE e.owner = ?2 AND e.show_id = ?3
       ORDER BY e.created_at DESC`,
    )
    .bind(me, show.owner, show.id)
    .all<PersonRow & { named: number }>();
  const encores = encoreRows.filter((r) => r.named === 1).map(toPerson);
  let seenBy: Person[] | null = null;
  if (show.owner === me) {
    const { results } = await db
      .prepare(
        `SELECT ${PERSON("v.user_id")}, v.seen_at AS at
         FROM crew_show_views v
         JOIN crew_profiles pr ON pr.user_id = v.user_id
         WHERE v.owner = ?1 AND v.show_id = ?2 AND pr.share_views = 1
           AND ${IS_CREW("v.user_id")}
         ORDER BY v.seen_at DESC`,
      )
      .bind(me, show.id)
      .all<PersonRow>();
    seenBy = results.map(toPerson);
  }
  return {
    encores,
    otherEncores: encoreRows.length - encores.length,
    seenBy,
  };
}

/** For [me]'s own Shows: showId -> who saw it, latest first. */
export async function seenSummaries(
  db: D1Database,
  me: string,
  showIds: string[],
): Promise<Map<string, SeenSummary>> {
  const out = new Map<string, SeenSummary>();
  if (showIds.length === 0) return out;
  const { results } = await db
    .prepare(
      `SELECT v.show_id, pr.stage_name
       FROM crew_show_views v
       JOIN crew_profiles pr ON pr.user_id = v.user_id
       WHERE v.owner = ?1 AND pr.share_views = 1 AND ${IS_CREW("v.user_id")}
       ORDER BY v.seen_at DESC`,
    )
    .bind(me)
    .all<{ show_id: string; stage_name: string }>();
  const wanted = new Set(showIds);
  for (const r of results) {
    if (!wanted.has(r.show_id)) continue;
    const s = out.get(r.show_id) ?? { count: 0, names: [] };
    s.count++;
    if (s.names.length < SEEN_NAMES) s.names.push(r.stage_name);
    out.set(r.show_id, s);
  }
  return out;
}

/** /api/crew/posts/{postId}/(seen|audience). Null when no route matches. */
export async function showViewsRoute(
  request: Request,
  db: D1Database,
  me: string,
  postId: string,
  what: string,
): Promise<Response | null> {
  if (what === "seen" && request.method === "PUT") {
    await markSeen(db, me, postId);
    return noContent();
  }
  if (what === "audience" && request.method === "GET") {
    return json(await audience(db, me, postId));
  }
  return null;
}

