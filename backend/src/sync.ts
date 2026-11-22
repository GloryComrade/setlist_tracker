// Backstage Pass: syncing Shows, Gear, Saved Mixes and Tours.

import type { Env } from "./env";
import { existingShowIds, notifyCrewOfShows, pushConfigured } from "./push";
import { ApiError, json, readJson } from "./http";
import { byteLength, iso, isObject, normalizeIso } from "./util";

export const SYNC_TABLES = ["shows", "gear", "saved_mixes", "tours"] as const;
export type SyncTable = (typeof SYNC_TABLES)[number];
export const MAX_ROWS = 500;

// Rows go to D1 as one JSON array per statement (D1 allows only 100 bound
// parameters per statement). Chunks keep each array well under D1's 2 MB
// value limit; all chunks still run in one batch (one transaction).
const CHUNK_BYTES = 512 * 1024;

export function syncTable(name: string): SyncTable {
  if ((SYNC_TABLES as readonly string[]).includes(name)) return name as SyncTable;
  throw new ApiError("not_found", "Backstage Pass doesn't sync that.");
}

interface InRow {
  id: string;
  data: string;
  updatedAt: string;
  deletedAt: string | null;
}

function badRow(): ApiError {
  return new ApiError(
    "bad_request",
    "Some of your Setlist didn't look right, so nothing was synced.",
  );
}

function parseRows(body: Record<string, unknown>): InRow[] {
  const rows = body.rows;
  if (!Array.isArray(rows)) throw badRow();
  if (rows.length > MAX_ROWS) {
    throw new ApiError(
      "bad_request",
      `Backstage Pass syncs at most ${MAX_ROWS} at a time.`,
    );
  }
  return rows.map((r): InRow => {
    if (!isObject(r)) throw badRow();
    const { id, data } = r;
    if (typeof id !== "string" || id.length < 1 || id.length > 100) throw badRow();
    if (!isObject(data)) throw badRow();
    const updatedAt = normalizeIso(r.updatedAt);
    if (!updatedAt) throw badRow();
    let deletedAt: string | null = null;
    if (r.deletedAt != null) {
      deletedAt = normalizeIso(r.deletedAt);
      if (!deletedAt) throw badRow();
    }
    return { id, data: JSON.stringify(data), updatedAt, deletedAt };
  });
}

/**
 * Upserts [rows] for [userId]. For each row the stored copy wins when its
 * updatedAt is later; otherwise the row is written with the server's
 * syncedAt (one value for the whole call). Rows whose id already belongs to
 * another runner are skipped and returned.
 *
 * Everything runs in a single D1 batch: first the lookup of foreign ids,
 * then the upserts, whose ON CONFLICT clause also refuses to touch another
 * runner's row, so the result is the same even if the lookup races.
 */
export async function upsertRows(
  db: D1Database,
  userId: string,
  table: SyncTable,
  rows: InRow[],
  now: Date = new Date(),
): Promise<{ rejected: string[]; syncedAt: string }> {
  const syncedAt = iso(now);
  if (rows.length === 0) return { rejected: [], syncedAt };

  const chunks: InRow[][] = [];
  let current: InRow[] = [];
  let size = 0;
  for (const row of rows) {
    const rowSize = byteLength(row.data) + row.id.length + 100;
    if (current.length > 0 && size + rowSize > CHUNK_BYTES) {
      chunks.push(current);
      current = [];
      size = 0;
    }
    current.push(row);
    size += rowSize;
  }
  chunks.push(current);

  const ids = JSON.stringify(rows.map((r) => r.id));
  const statements = [
    db
      .prepare(
        `SELECT id FROM records
         WHERE kind = ?1 AND user_id <> ?2
           AND id IN (SELECT value FROM json_each(?3))`,
      )
      .bind(table, userId, ids),
    ...chunks.map((chunk) =>
      db
        .prepare(
          `INSERT INTO records
             (user_id, kind, id, data, updated_at, deleted_at, synced_at)
           SELECT ?1, ?2,
             json_extract(j.value, '$.id'),
             json_extract(j.value, '$.data'),
             json_extract(j.value, '$.updatedAt'),
             json_extract(j.value, '$.deletedAt'),
             ?3
           FROM json_each(?4) AS j WHERE true
           ON CONFLICT (kind, id) DO UPDATE SET
             data = excluded.data,
             updated_at = excluded.updated_at,
             deleted_at = excluded.deleted_at,
             synced_at = excluded.synced_at
           WHERE records.user_id = excluded.user_id
             AND records.updated_at <= excluded.updated_at`,
        )
        .bind(userId, table, syncedAt, JSON.stringify(chunk))
    ),
  ];
  const [foreign] = await db.batch<{ id: string }>(statements);
  return { rejected: foreign.results.map((r) => r.id), syncedAt };
}

export interface OutRow {
  id: string;
  data: unknown;
  updatedAt: string;
  deletedAt: string | null;
  syncedAt: string;
}

export async function pullRows(
  db: D1Database,
  userId: string,
  table: SyncTable,
  opts: { since?: string | null; offset?: number; limit?: number },
): Promise<OutRow[]> {
  const { results } = await db
    .prepare(
      `SELECT id, data, updated_at, deleted_at, synced_at FROM records
       WHERE user_id = ?1 AND kind = ?2 AND synced_at > ?3
       ORDER BY synced_at, id
       LIMIT ?4 OFFSET ?5`,
    )
    .bind(
      userId,
      table,
      opts.since ?? "",
      opts.limit ?? MAX_ROWS,
      opts.offset ?? 0,
    )
    .all<{
      id: string;
      data: string;
      updated_at: string;
      deleted_at: string | null;
      synced_at: string;
    }>();
  return results.map((r) => ({
    id: r.id,
    data: JSON.parse(r.data),
    updatedAt: r.updated_at,
    deletedAt: r.deleted_at,
    syncedAt: r.synced_at,
  }));
}

function intParam(
  raw: string | null,
  fallback: number,
  min: number,
  max: number,
): number {
  if (raw == null || raw === "") return fallback;
  if (!/^\d+$/.test(raw)) {
    throw new ApiError("bad_request", "That sync request didn't make sense.");
  }
  return Math.min(max, Math.max(min, parseInt(raw, 10)));
}

// ---- Routes ----

/**
 * POST /api/sync/{table}. Rows whose id belongs to another runner can't be
 * written: the other rows are still saved, and the answer is a 409
 * `{"error": "bad_request", "message", "rejected": [ids]}` instead of
 * `{"ok": true}`.
 */
export async function pushRoute(
  request: Request,
  env: Env,
  userId: string,
  tableName: string,
  later?: (work: Promise<unknown>) => Promise<void>,
): Promise<Response> {
  const table = syncTable(tableName);
  const rows = parseRows(await readJson(request));
  // Shows the server hasn't seen before may notify the Crew (src/push.ts).
  const ids = rows.filter((r) => r.deletedAt == null).map((r) => r.id);
  const known =
    table === "shows" && later && pushConfigured(env)
      ? await existingShowIds(env.DB, userId, ids)
      : null;
  const { rejected } = await upsertRows(env.DB, userId, table, rows);
  if (known && later) {
    const fresh = ids.filter((id) => !known.has(id) && !rejected.includes(id));
    if (fresh.length > 0) await later(notifyCrewOfShows(env, userId, fresh));
  }
  if (rejected.length > 0) {
    throw new ApiError(
      "bad_request",
      "Some of these belong to another runner's Setlist, so they weren't synced.",
      409,
      { rejected },
    );
  }
  return json({ ok: true });
}

export async function pullRoute(
  request: Request,
  env: Env,
  userId: string,
  tableName: string,
): Promise<Response> {
  const table = syncTable(tableName);
  const params = new URL(request.url).searchParams;
  const sinceRaw = params.get("since");
  let since: string | null = null;
  if (sinceRaw) {
    since = normalizeIso(sinceRaw);
    if (!since) {
      throw new ApiError("bad_request", "That sync request didn't make sense.");
    }
  }
  const rows = await pullRows(env.DB, userId, table, {
    since,
    offset: intParam(params.get("offset"), 0, 0, Number.MAX_SAFE_INTEGER),
    limit: intParam(params.get("limit"), MAX_ROWS, 1, MAX_ROWS),
  });
  return json({ rows });
}
