// Crew profile pictures: a drawn tour-art badge, or your own photo.
//
// - The badge is one of AVATAR_BADGES, drawn by the app in your avatar
//   color. It is saved with PUT /api/crew/profile {avatarBadge}.
// - A photo is a square JPEG the app makes on the device (256 px), at most
//   64 KB, stored in D1 (crew_avatars, migration 0004). PUT and DELETE
//   /api/crew/avatar.
// - GET /api/crew/avatar/{userId} returns the photo only to its owner and
//   their Crew. Anyone blocked either way gets not_found, like a stranger.
// - Profile, mates, mate and feed JSON carry avatarBadge and avatarUrl
//   (null when there is none). avatarUrl is a path with ?v=<updated ms>, so
//   a new photo is a new address and caches never show an old one.
// - POST /api/crew/report-avatar {userId, reason} reports a Crew mate's
//   photo; the server copies the photo into the report (crew_reports with
//   post_id 'avatar').

import { getProfile, isCrew } from "./crew";
import { ApiError, json, noContent, readJson } from "./http";
import { iso } from "./util";

/** Keep in step with kAvatarBadges in lib/models/avatar_badge.dart. */
export const AVATAR_BADGES = [
  "mic",
  "vinyl",
  "guitar-pick",
  "sneaker",
  "headphones",
  "drumsticks",
  "lightning",
  "star",
  "ticket",
  "amp",
  "cassette",
  "setlist",
  "laurel",
  "medal",
  "stopwatch",
  "mountain",
  "flame",
  "wave",
  "moon",
  "sun",
  "heart",
  "crown",
  "music-note",
  "spotlight",
] as const;

export const MAX_AVATAR_BYTES = 64 * 1024;

/** SQL for the photo time of the runner in [col], or NULL without one. */
export const AVATAR_AT = (col: string) =>
  `(SELECT av.updated_at FROM crew_avatars av WHERE av.user_id = ${col})`;

export interface AvatarFields {
  avatarBadge: string | null;
  avatarUrl: string | null;
}

/** What the JSON carries for [userId]'s picture. */
export function avatarFields(
  userId: string,
  badge: string | null | undefined,
  photoAt: string | null | undefined,
): AvatarFields {
  const v = photoAt ? Date.parse(photoAt) : NaN;
  return {
    avatarBadge: badge && isBadge(badge) ? badge : null,
    avatarUrl: Number.isFinite(v)
      ? `/api/crew/avatar/${encodeURIComponent(userId)}?v=${v}`
      : null,
  };
}

/** No picture: for runners you blocked. */
export const NO_AVATAR: AvatarFields = { avatarBadge: null, avatarUrl: null };

export function isBadge(v: unknown): v is (typeof AVATAR_BADGES)[number] {
  return (AVATAR_BADGES as readonly unknown[]).includes(v);
}

/**
 * The avatarBadge in a profile body: undefined when it isn't there (keep the
 * saved one, so older app builds don't clear it), null to clear it.
 */
export function badgeField(body: Record<string, unknown>): string | null | undefined {
  if (!("avatarBadge" in body)) return undefined;
  const v = body.avatarBadge;
  if (v === null) return null;
  if (!isBadge(v)) {
    throw new ApiError("bad_request", "Pick one of the badges.");
  }
  return v;
}

function badPhoto(message: string, status = 400): ApiError {
  return new ApiError("bad_request", message, status);
}

/** JPEG files start FF D8 FF. */
export function looksLikeJpeg(bytes: Uint8Array): boolean {
  return bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
}

async function readPhoto(request: Request): Promise<Uint8Array> {
  const type = (request.headers.get("Content-Type") ?? "").split(";")[0].trim();
  if (type.toLowerCase() !== "image/jpeg") {
    throw badPhoto("Send the photo as a JPEG.", 415);
  }
  const declared = Number(request.headers.get("Content-Length") ?? "0");
  if (declared > MAX_AVATAR_BYTES) {
    throw badPhoto("That photo is too big. It needs to be 64 KB or less.", 413);
  }
  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.length > MAX_AVATAR_BYTES) {
    throw badPhoto("That photo is too big. It needs to be 64 KB or less.", 413);
  }
  if (!looksLikeJpeg(bytes)) {
    throw badPhoto("That isn't a JPEG photo.");
  }
  return bytes;
}

async function needProfile(db: D1Database, me: string) {
  const p = await getProfile(db, me);
  if (!p) {
    throw new ApiError(
      "need_stage_name",
      "Pick a stage name first, so your Crew knows who you are.",
    );
  }
  return p;
}

/** Saves [me]'s photo and returns the profile with its new avatarUrl. */
export async function putAvatar(
  db: D1Database,
  me: string,
  request: Request,
  now: Date = new Date(),
) {
  await needProfile(db, me);
  const bytes = await readPhoto(request);
  await db
    .prepare(
      `INSERT INTO crew_avatars (user_id, jpeg, updated_at) VALUES (?1, ?2, ?3)
       ON CONFLICT (user_id) DO UPDATE SET
         jpeg = excluded.jpeg, updated_at = excluded.updated_at`,
    )
    .bind(me, bytes, iso(now))
    .run();
  return (await getProfile(db, me))!;
}

export async function deleteAvatar(db: D1Database, me: string) {
  await db.prepare("DELETE FROM crew_avatars WHERE user_id = ?").bind(me).run();
  return getProfile(db, me);
}

function noPhoto(): ApiError {
  return new ApiError("not_found", "There's no photo there.");
}

async function photoOf(db: D1Database, userId: string) {
  const row = await db
    .prepare("SELECT jpeg, updated_at FROM crew_avatars WHERE user_id = ?")
    .bind(userId)
    .first<{ jpeg: ArrayBuffer | number[]; updated_at: string }>();
  if (!row) return null;
  return { bytes: new Uint8Array(row.jpeg), updatedAt: row.updated_at };
}

/** [userId]'s photo, for themselves or their Crew only. */
export async function getAvatar(db: D1Database, me: string, userId: string) {
  if (userId !== me && !(await isCrew(db, me, userId))) throw noPhoto();
  const photo = await photoOf(db, userId);
  if (!photo) throw noPhoto();
  return new Response(photo.bytes, {
    status: 200,
    headers: {
      "Content-Type": "image/jpeg",
      // Only this runner's device may keep it. A new photo has a new ?v=.
      "Cache-Control": "private, max-age=86400",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

function toBase64(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(s);
}

/** Reports a Crew mate's photo. The server copies the photo into the report. */
export async function reportAvatar(
  db: D1Database,
  me: string,
  body: Record<string, unknown>,
  now: Date = new Date(),
) {
  const text = typeof body.reason === "string" ? body.reason.trim() : "";
  if (text.length < 1 || text.length > 500) {
    throw new ApiError("bad_request", "Tell us what's wrong in 1 to 500 characters.");
  }
  const userId = body.userId;
  if (typeof userId !== "string" || userId === me) {
    throw new ApiError("bad_request", "You can't report your own photo.");
  }
  if (!(await isCrew(db, me, userId))) throw noPhoto();
  const photo = await photoOf(db, userId);
  if (!photo) throw noPhoto();
  await db
    .prepare(
      `INSERT INTO crew_reports
         (id, reporter, post_id, reported_user, post_data, reason, created_at)
       VALUES (?, ?, 'avatar', ?, ?, ?, ?)`,
    )
    .bind(
      crypto.randomUUID(),
      me,
      userId,
      JSON.stringify({
        kind: "avatar",
        updatedAt: photo.updatedAt,
        jpegBase64: toBase64(photo.bytes),
      }),
      text,
      iso(now),
    )
    .run();
}

/** /api/crew/avatar… and /api/crew/report-avatar. Null when no route matches. */
export async function avatarRoute(
  request: Request,
  db: D1Database,
  me: string,
  parts: string[],
): Promise<Response | null> {
  const m = request.method;
  const [a, b] = parts;
  const n = parts.length;
  if (a === "avatar" && n === 1 && m === "PUT") {
    return json(await putAvatar(db, me, request));
  }
  if (a === "avatar" && n === 1 && m === "DELETE") {
    return json(await deleteAvatar(db, me));
  }
  if (a === "avatar" && n === 2 && m === "GET") {
    return getAvatar(db, me, b);
  }
  if (a === "report-avatar" && n === 1 && m === "POST") {
    await reportAvatar(db, me, await readJson(request));
    return noContent();
  }
  return null;
}
