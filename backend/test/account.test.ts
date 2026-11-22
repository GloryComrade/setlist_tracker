import { env } from "cloudflare:workers";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createLoginCode } from "../src/auth";
import { call, callJson, count, jsonResponse, mockFetch, newRunner } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
});

const TABLES: [string, string][] = [
  ["users", "id = ?1"],
  ["sessions", "user_id = ?1"],
  ["login_codes", "user_id = ?1"],
  ["apple_tokens", "user_id = ?1"],
  ["records", "user_id = ?1"],
  ["crew_profiles", "user_id = ?1"],
  ["crew_links", "?1 IN (user_a, user_b)"],
  ["crew_blocks", "?1 IN (blocker, blocked)"],
  ["crew_invites", "owner = ?1"],
  ["crew_invite_misses", "user_id = ?1"],
  ["crew_encores_v2", "?1 IN (user_id, owner)"],
  ["crew_reports", "?1 IN (reporter, reported_user)"],
  ["crew_tour_invites", "?1 IN (from_user, to_user)"],
  ["crew_avatars", "user_id = ?1"],
  ["crew_show_views", "?1 IN (user_id, owner)"],
  ["crew_shoutouts", "?1 IN (user_id, owner)"],
];

async function rowsOf(userId: string): Promise<Record<string, number>> {
  const out: Record<string, number> = {};
  for (const [table, where] of TABLES) {
    out[table] = await count(`SELECT count(*) AS n FROM ${table} WHERE ${where}`, userId);
  }
  return out;
}


describe("DELETE /api/me", () => {
  it("removes the runner and every row of theirs, and revokes Apple", async () => {
    const me = await newRunner("Me");
    const friend = await newRunner("Friend");
    const blocker = await newRunner("Blocker");
    for (const r of [me, friend, blocker]) {
      await call("PUT", "/api/crew/profile", { token: r.token, body: { stageName: r.user.name } });
    }
    // Crew link both ways, a block each way, invites, a miss.
    const myCode = (await callJson("POST", "/api/crew/invite", { token: me.token })).body.code;
    await call("POST", "/api/crew/join", { token: friend.token, body: { code: myCode } });
    await call("POST", "/api/crew/join", { token: me.token, body: { code: "ZZZZZZZZ" } });
    await call("POST", "/api/crew/blocks", { token: me.token, body: { userId: blocker.user.id } });
    await call("POST", "/api/crew/blocks", { token: blocker.token, body: { userId: me.user.id } });
    // Shows both ways, Encores given and received, reports made and naming me.
    for (const r of [me, friend]) {
      const id = crypto.randomUUID();
      await call("POST", "/api/sync/shows", {
        token: r.token,
        body: { rows: [{ id, data: { id, date: "2026-11-21T07:30:00.000" }, updatedAt: "2026-11-21T08:00:00.000Z", deletedAt: null }] },
      });
    }
    const posts = (await callJson("GET", "/api/crew/feed", { token: me.token })).body.posts;
    expect(posts).toHaveLength(2);
    const mine = posts.find((p: any) => p.mine).id;
    const theirs = posts.find((p: any) => !p.mine).id;
    await call("PUT", `/api/crew/posts/${theirs}/encore`, { token: me.token });
    await call("PUT", `/api/crew/posts/${mine}/encore`, { token: friend.token });
    // Views and Shout-outs both ways.
    await call("PUT", `/api/crew/posts/${theirs}/seen`, { token: me.token });
    await call("PUT", `/api/crew/posts/${mine}/seen`, { token: friend.token });
    await call("POST", `/api/crew/posts/${theirs}/shoutouts`, { token: me.token, body: { body: "Nice!" } });
    await call("POST", `/api/crew/posts/${mine}/shoutouts`, { token: friend.token, body: { body: "Go!" } });
    await call("POST", `/api/crew/posts/${theirs}/report`, { token: me.token, body: { reason: "a" } });
    await call("POST", `/api/crew/posts/${mine}/report`, { token: friend.token, body: { reason: "b" } });
    // A Tour invite to the friend.
    const tourId = crypto.randomUUID();
    const raceDate = new Date(Date.now() + 60 * 86400_000).toISOString().slice(0, 10);
    await call("POST", "/api/sync/tours", {
      token: me.token,
      body: { rows: [{ id: tourId, data: { id: tourId, name: "Spring Tour", setup: { raceDate, raceDistance: "half" } }, updatedAt: "2026-11-21T08:00:00.000Z", deletedAt: null }] },
    });
    await call("POST", "/api/crew/tour-invites", { token: me.token, body: { tourId, to: [friend.user.id] } });
    // A profile photo.
    const photo = new Uint8Array(64).fill(1);
    photo.set([0xff, 0xd8, 0xff]);
    await env.DB.prepare(
      "INSERT INTO crew_avatars (user_id, jpeg, updated_at) VALUES (?, ?, ?)",
    ).bind(me.user.id, photo, new Date().toISOString()).run();
    // A login code, an Apple token.
    await createLoginCode(env.DB, me.user.id);
    await env.DB.prepare(
      "INSERT INTO apple_tokens (user_id, client_id, refresh_token, created_at) VALUES (?, ?, ?, ?)",
    ).bind(me.user.id, env.APPLE_BUNDLE_ID, "apple-refresh", new Date().toISOString()).run();

    const before = await rowsOf(me.user.id);
    for (const [table, n] of Object.entries(before)) {
      expect(n, table).toBeGreaterThan(0);
    }
    const friendBefore = await rowsOf(friend.user.id);

    const calls = mockFetch((url) =>
      url.href === "https://appleid.apple.com/auth/revoke"
        ? new Response(null, { status: 200 })
        : jsonResponse({}, 500));

    const res = await call("DELETE", "/api/me", { token: me.token });
    expect(res.status).toBe(204);

    expect(Object.values(await rowsOf(me.user.id)).every((n) => n === 0)).toBe(true);

    // Apple was asked to revoke the stored token.
    const revoke = calls.find((c) => c.url.pathname === "/auth/revoke")!;
    const form = new URLSearchParams(revoke.body!);
    expect(form.get("token")).toBe("apple-refresh");
    expect(form.get("token_type_hint")).toBe("refresh_token");
    expect(form.get("client_id")).toBe(env.APPLE_BUNDLE_ID);

    // The friend keeps their account, Shows and profile.
    const friendAfter = await rowsOf(friend.user.id);
    expect(friendAfter.users).toBe(1);
    expect(friendAfter.records).toBe(friendBefore.records);
    expect(friendAfter.crew_profiles).toBe(1);
    expect(friendAfter.crew_links).toBe(0);
    expect(friendAfter.crew_encores_v2).toBe(0);
    expect(friendAfter.crew_tour_invites).toBe(0);
    expect(friendAfter.crew_show_views).toBe(0);
    expect(friendAfter.crew_shoutouts).toBe(0);

    // The old token no longer works.
    expect((await call("GET", "/api/me", { token: me.token })).status).toBe(401);
    expect((await callJson("POST", "/api/auth/refresh", { body: { refreshToken: me.refreshToken } })).status).toBe(401);
  });

  it("still deletes when Apple's revoke fails", async () => {
    const me = await newRunner("Me");
    await env.DB.prepare(
      "INSERT INTO apple_tokens (user_id, client_id, refresh_token, created_at) VALUES (?, ?, ?, ?)",
    ).bind(me.user.id, env.APPLE_SERVICES_ID, "t", new Date().toISOString()).run();
    mockFetch(() => {
      throw new Error("network down");
    });
    expect((await call("DELETE", "/api/me", { token: me.token })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM users WHERE id = ?", me.user.id)).toBe(0);
  });

  it("needs sign-in", async () => {
    expect((await call("DELETE", "/api/me")).status).toBe(401);
  });
});
