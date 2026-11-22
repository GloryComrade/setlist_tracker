import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import { upsertRows } from "../src/sync";
import { callJson, newRunner } from "./helpers";

const T1 = "2026-11-20T10:00:00.000Z";
const T2 = "2026-11-21T10:00:00.000Z";
const T3 = "2026-11-22T10:00:00.000Z";

function row(id: string, updatedAt: string, data: Record<string, unknown> = {}, deletedAt: string | null = null) {
  return { id, data: { id, ...data }, updatedAt, deletedAt };
}

async function push(token: string, table: string, rows: unknown[]) {
  return callJson("POST", `/api/sync/${table}`, { token, body: { rows } });
}

async function pull(token: string, table: string, query = "") {
  return callJson("GET", `/api/sync/${table}${query}`, { token });
}

describe("sync", () => {
  it("needs sign-in", async () => {
    const res = await callJson("GET", "/api/sync/shows");
    expect(res.status).toBe(401);
  });

  it("knows only shows, gear, saved_mixes and tours", async () => {
    const r = await newRunner();
    for (const t of ["shows", "gear", "saved_mixes", "tours"]) {
      expect((await pull(r.token, t)).status).toBe(200);
    }
    expect((await pull(r.token, "users")).status).toBe(404);
    expect((await push(r.token, "records", [])).body.error).toBe("not_found");
  });

  it("round-trips rows with a server syncedAt shared by the request", async () => {
    const r = await newRunner();
    const id1 = crypto.randomUUID();
    const id2 = crypto.randomUUID();
    const before = new Date().toISOString();
    const res = await push(r.token, "shows", [
      row(id1, T1, { miles: 3.1, song: { title: "Mr. Brightside" } }),
      row(id2, "2026-11-21T10:00:00.123456Z", {}, "2026-11-21T10:00:00Z"),
    ]);
    expect(res).toEqual({ status: 200, body: { ok: true } });

    const { body } = await pull(r.token, "shows");
    expect(body.rows).toHaveLength(2);
    const [a, b] = body.rows;
    expect(a.syncedAt).toBe(b.syncedAt);
    expect(a.syncedAt >= before).toBe(true);
    expect(a.syncedAt).toMatch(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/);
    const byId = Object.fromEntries(body.rows.map((x: any) => [x.id, x]));
    expect(byId[id1]).toMatchObject({
      data: { id: id1, miles: 3.1, song: { title: "Mr. Brightside" } },
      updatedAt: T1,
      deletedAt: null,
    });
    // Times are normalized to UTC with milliseconds.
    expect(byId[id2]).toMatchObject({
      updatedAt: "2026-11-21T10:00:00.123Z",
      deletedAt: "2026-11-21T10:00:00.000Z",
    });
    // Other tables are separate.
    expect((await pull(r.token, "gear")).body.rows).toEqual([]);
  });

  it("keeps the newer copy: older updatedAt never overwrites", async () => {
    const r = await newRunner();
    const id = crypto.randomUUID();
    await upsertRows(env.DB, r.user.id, "shows", [
      { id, data: '{"v":2}', updatedAt: T2, deletedAt: null },
    ], new Date("2026-11-22T00:00:00.000Z"));

    // Older: ignored, syncedAt unchanged.
    await upsertRows(env.DB, r.user.id, "shows", [
      { id, data: '{"v":1}', updatedAt: T1, deletedAt: null },
    ], new Date("2026-11-22T00:00:01.000Z"));
    let rows = (await pull(r.token, "shows")).body.rows;
    expect(rows).toEqual([
      { id, data: { v: 2 }, updatedAt: T2, deletedAt: null, syncedAt: "2026-11-22T00:00:00.000Z" },
    ]);

    // Same updatedAt: written (only a *later* stored copy wins).
    await upsertRows(env.DB, r.user.id, "shows", [
      { id, data: '{"v":"same"}', updatedAt: T2, deletedAt: null },
    ], new Date("2026-11-22T00:00:02.000Z"));
    rows = (await pull(r.token, "shows")).body.rows;
    expect(rows[0].data).toEqual({ v: "same" });

    // Newer, with a soft delete: written.
    const res = await push(r.token, "shows", [row(id, T3, { v: 3 }, T3)]);
    expect(res.status).toBe(200);
    rows = (await pull(r.token, "shows")).body.rows;
    expect(rows[0]).toMatchObject({ data: { id, v: 3 }, updatedAt: T3, deletedAt: T3 });
    expect(rows[0].syncedAt > "2026-11-22T00:00:02.000Z").toBe(true);
  });

  it("pulls since / offset / limit, ordered by syncedAt then id", async () => {
    const r = await newRunner();
    const ids = ["a", "b", "c", "d", "e"].map((x) => `${x}-${crypto.randomUUID()}`);
    await upsertRows(env.DB, r.user.id, "gear",
      ids.slice(0, 3).reverse().map((id) => ({ id, data: "{}", updatedAt: T1, deletedAt: null })),
      new Date("2026-11-22T01:00:00.000Z"));
    await upsertRows(env.DB, r.user.id, "gear",
      ids.slice(3).map((id) => ({ id, data: "{}", updatedAt: T1, deletedAt: null })),
      new Date("2026-11-22T02:00:00.000Z"));

    const all = (await pull(r.token, "gear")).body.rows.map((x: any) => x.id);
    expect(all).toEqual(ids);

    const since = (await pull(r.token, "gear", "?since=2026-11-22T01:00:00.000Z")).body.rows;
    expect(since.map((x: any) => x.id)).toEqual(ids.slice(3));

    const page = (await pull(r.token, "gear", "?limit=2&offset=1")).body.rows;
    expect(page.map((x: any) => x.id)).toEqual(ids.slice(1, 3));

    const over = await pull(r.token, "gear", "?limit=9999");
    expect(over.status).toBe(200);
    expect(over.body.rows).toHaveLength(5);

    expect((await pull(r.token, "gear", "?since=yesterday")).status).toBe(400);
    expect((await pull(r.token, "gear", "?limit=-3")).status).toBe(400);
  });

  it("never shows another runner's rows", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await push(maya.token, "tours", [row(crypto.randomUUID(), T1, { name: "Spring Tour" })]);
    expect((await pull(ryan.token, "tours")).body.rows).toEqual([]);
    expect((await pull(maya.token, "tours")).body.rows).toHaveLength(1);
  });

  it("rejects ids that belong to another runner with a 409, and saves the rest", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    const taken = crypto.randomUUID();
    await push(maya.token, "shows", [row(taken, T1, { owner: "maya" })]);

    const mine = crypto.randomUUID();
    const res = await push(ryan.token, "shows", [
      row(taken, T3, { owner: "ryan" }),
      row(mine, T3, { owner: "ryan" }),
    ]);
    expect(res.status).toBe(409);
    expect(res.body.error).toBe("bad_request");
    expect(res.body.rejected).toEqual([taken]);
    expect(typeof res.body.message).toBe("string");

    // Ryan's own row went in; Maya's row is untouched.
    expect((await pull(ryan.token, "shows")).body.rows.map((x: any) => x.id)).toEqual([mine]);
    const mayas = (await pull(maya.token, "shows")).body.rows;
    expect(mayas).toHaveLength(1);
    expect(mayas[0].data.owner).toBe("maya");

    // The same id in another table is fine.
    expect((await push(ryan.token, "gear", [row(taken, T1)])).status).toBe(200);
  });

  it("validates rows", async () => {
    const r = await newRunner();
    const bad = [
      {},
      { rows: "nope" },
      { rows: [{ id: "x", data: {}, updatedAt: "not a time" }] },
      { rows: [{ id: "x", data: [], updatedAt: T1 }] },
      { rows: [{ id: "", data: {}, updatedAt: T1 }] },
      { rows: [{ id: "x", data: {}, updatedAt: T1, deletedAt: "soon" }] },
      { rows: Array.from({ length: 501 }, (_, i) => row(`r${i}`, T1)) },
    ];
    for (const body of bad) {
      const res = await callJson("POST", "/api/sync/shows", { token: r.token, body });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe("bad_request");
    }
    expect((await pull(r.token, "shows")).body.rows).toEqual([]);
  });

  it("takes 500 rows in one request", async () => {
    const r = await newRunner();
    const rows = Array.from({ length: 500 }, (_, i) =>
      row(`bulk-${i}-${crypto.randomUUID()}`, T1, { notes: "x".repeat(2000) }));
    expect((await push(r.token, "shows", rows)).status).toBe(200);
    const pulled = (await pull(r.token, "shows")).body.rows;
    expect(pulled).toHaveLength(500);
  });
});
