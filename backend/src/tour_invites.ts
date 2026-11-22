// Tour invites: ask Crew mates onto your Tour.
//
// - POST /api/crew/tour-invites {tourId, to: [userId]} invites Crew mates
//   onto one of your synced, non-deleted Tours whose Opening Night is still
//   to come. Anyone in `to` who isn't in your Crew (or is blocked either way)
//   is skipped without saying why. The race is copied from the Tour.
// - GET /api/crew/tour-invites lists invites to you that you haven't
//   dismissed, whose sender is still in your Crew and whose Tour still
//   exists and hasn't raced yet. The Tour's current name, date and distance
//   win over the copies.
// - DELETE /api/crew/tour-invites/{id} dismisses one ("Not this time").
//   Only its recipient can. Inviting again doesn't bring it back.

import { getProfile, IS_CREW, isCrew, RACE_DISTANCES, utcDate } from "./crew";
import { ApiError, json, noContent, readJson } from "./http";
import { iso, isObject } from "./util";

export const MAX_TOUR_INVITES = 50;
const TOUR_NAME_MAX = 60;

export interface TourInvite {
  id: string;
  from: { userId: string; stageName: string; color: number };
  tourId: string;
  tourName: string;
  raceDate: string;
  raceDistance: (typeof RACE_DISTANCES)[number];
  createdAt: string;
}

function bad(message = "That request didn't make sense."): ApiError {
  return new ApiError("bad_request", message);
}

function distanceOf(v: unknown): TourInvite["raceDistance"] {
  return (RACE_DISTANCES as readonly unknown[]).includes(v)
    ? (v as TourInvite["raceDistance"])
    : "marathon";
}

function nameOf(v: unknown): string {
  const name = typeof v === "string" ? v.replace(/\s+/g, " ").trim() : "";
  return name ? [...name].slice(0, TOUR_NAME_MAX).join("") : "The Tour";
}

/**
 * Invites [to] onto [me]'s Tour [tourId]. Returns the ids that are invited
 * now (Crew mates only; already-invited ones count, dismissed ones stay
 * dismissed).
 */
export async function inviteToTour(
  db: D1Database,
  me: string,
  body: Record<string, unknown>,
  now: Date = new Date(),
): Promise<string[]> {
  const { tourId, to } = body;
  if (typeof tourId !== "string" || !tourId || !Array.isArray(to)) throw bad();
  const ids = [...new Set(to)];
  if (ids.length < 1 || ids.length > MAX_TOUR_INVITES) {
    throw bad(`Invite 1 to ${MAX_TOUR_INVITES} Crew mates at a time.`);
  }
  if (!ids.every((id) => typeof id === "string" && id)) throw bad();

  if (!(await getProfile(db, me))) {
    throw new ApiError(
      "need_stage_name",
      "Pick a stage name first, so your Crew knows who you are.",
    );
  }
  const row = await db
    .prepare(
      `SELECT data FROM records
       WHERE kind = 'tours' AND id = ? AND user_id = ? AND deleted_at IS NULL`,
    )
    .bind(tourId, me)
    .first<{ data: string }>();
  if (!row) {
    throw new ApiError("not_found", "That Tour isn't backstage yet. Sync and try again.");
  }
  let tour: unknown;
  try {
    tour = JSON.parse(row.data);
  } catch {
    tour = null;
  }
  const setup = isObject(tour) && isObject(tour.setup) ? tour.setup : {};
  const raceDate = typeof setup.raceDate === "string" ? setup.raceDate.slice(0, 10) : "";
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raceDate)) throw bad("That Tour has no Opening Night.");
  if (raceDate < utcDate(now)) throw bad("That Tour's Opening Night has passed.");
  const distance = distanceOf(setup.raceDistance);
  const name = nameOf(isObject(tour) ? tour.name : null);

  const invited: string[] = [];
  for (const id of ids as string[]) {
    if (id !== me && (await isCrew(db, me, id))) invited.push(id);
  }
  if (invited.length > 0) {
    await db.batch(
      invited.map((id) =>
        db
          .prepare(
            `INSERT INTO crew_tour_invites
               (id, from_user, to_user, tour_id, race_date, race_distance,
                tour_name, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT (from_user, to_user, tour_id) DO UPDATE SET
               race_date = excluded.race_date,
               race_distance = excluded.race_distance,
               tour_name = excluded.tour_name`,
          )
          .bind(crypto.randomUUID(), me, id, tourId, raceDate, distance, name, iso(now)),
      ),
    );
  }
  return invited;
}

/** Invites to [me] still worth showing, soonest Opening Night first. */
export async function tourInvites(
  db: D1Database,
  me: string,
  now: Date = new Date(),
): Promise<TourInvite[]> {
  const live = (path: string, stored: string) =>
    `coalesce(json_extract(t.data, '${path}'), i.${stored})`;
  const { results } = await db
    .prepare(
      `SELECT i.id, i.from_user, i.tour_id, i.created_at,
              coalesce(p.stage_name, 'Runner') AS stage_name,
              coalesce(p.color, 0) AS color,
              ${live("$.name", "tour_name")} AS tour_name,
              substr(${live("$.setup.raceDate", "race_date")}, 1, 10) AS race_date,
              ${live("$.setup.raceDistance", "race_distance")} AS race_distance
       FROM crew_tour_invites i
       JOIN records t ON t.kind = 'tours' AND t.id = i.tour_id
         AND t.user_id = i.from_user AND t.deleted_at IS NULL
       LEFT JOIN crew_profiles p ON p.user_id = i.from_user
       WHERE i.to_user = ?1 AND i.dismissed_at IS NULL
         AND substr(${live("$.setup.raceDate", "race_date")}, 1, 10) >= ?2
         AND ${IS_CREW("i.from_user")}
       ORDER BY race_date, i.created_at DESC, i.id`,
    )
    .bind(me, utcDate(now))
    .all<{
      id: string;
      from_user: string;
      tour_id: string;
      created_at: string;
      stage_name: string;
      color: number;
      tour_name: unknown;
      race_date: string;
      race_distance: unknown;
    }>();
  return results.map((r) => ({
    id: r.id,
    from: { userId: r.from_user, stageName: r.stage_name, color: r.color },
    tourId: r.tour_id,
    tourName: nameOf(r.tour_name),
    raceDate: r.race_date,
    raceDistance: distanceOf(r.race_distance),
    createdAt: r.created_at,
  }));
}

/** "Not this time". 404 unless the invite was sent to [me]. */
export async function dismissTourInvite(
  db: D1Database,
  me: string,
  id: string,
  now: Date = new Date(),
): Promise<void> {
  const row = await db
    .prepare(
      `UPDATE crew_tour_invites SET dismissed_at = coalesce(dismissed_at, ?3)
       WHERE id = ?1 AND to_user = ?2 RETURNING id`,
    )
    .bind(id, me, iso(now))
    .first();
  if (!row) throw new ApiError("not_found", "That Tour invite isn't here anymore.");
}

/** Handles /api/crew/tour-invites[/id]. Null when no route matches. */
export async function tourInvitesRoute(
  request: Request,
  db: D1Database,
  me: string,
  parts: string[],
): Promise<Response | null> {
  const m = request.method;
  if (parts.length === 0) {
    if (m === "GET") return json({ invites: await tourInvites(db, me) });
    if (m === "POST") {
      return json({ invited: await inviteToTour(db, me, await readJson(request)) });
    }
  }
  if (parts.length === 1 && m === "DELETE") {
    await dismissTourInvite(db, me, parts[0]);
    return noContent();
  }
  return null;
}
