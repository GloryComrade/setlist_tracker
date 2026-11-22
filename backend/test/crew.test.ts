import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import { INVITE_ALPHABET, inviteCode, newInviteCode } from "../src/crew";
import { call, callJson, count, newRunner, type Runner } from "./helpers";

async function profile(r: Runner, stageName: string, extra: Record<string, unknown> = {}) {
  const res = await callJson("PUT", "/api/crew/profile", {
    token: r.token,
    body: { stageName, color: 1, ...extra },
  });
  expect(res.status).toBe(200);
  return res.body;
}

async function invite(r: Runner): Promise<string> {
  const res = await callJson("POST", "/api/crew/invite", { token: r.token });
  expect(res.status).toBe(200);
  return res.body.code;
}

async function join(r: Runner, code: string) {
  return callJson("POST", "/api/crew/join", { token: r.token, body: { code } });
}

/** Two runners with profiles, in each other's Crew. */
async function crewPair() {
  const maya = await newRunner("Maya");
  const ryan = await newRunner("Ryan");
  await profile(maya, "Maya");
  await profile(ryan, "Ryan");
  expect((await join(ryan, await invite(maya))).status).toBe(200);
  return { maya, ryan };
}

const DAY_MS = 86400_000;

/** A unique record id (records are keyed by kind and id across runners). */
function rid(name: string): string {
  return `${name}-${crypto.randomUUID().slice(0, 8)}`;
}

/** "YYYY-MM-DD", [days] from today (UTC). */
function day(days: number): string {
  return new Date(Date.now() + days * DAY_MS).toISOString().slice(0, 10);
}

/** A full Show, the way lib/models/show.dart writes it. */
function show(id: string, extra: Record<string, unknown> = {}) {
  return {
    schemaVersion: 1,
    id,
    date: "2026-11-21T07:30:00.000",
    venue: "outdoor",
    workoutType: "easy",
    distanceMiles: 3.1,
    durationSeconds: 1800,
    effort: 6,
    feel: "great",
    notes: "Legs felt fresh",
    gearId: null,
    song: { title: "Mr. Brightside", artist: "The Killers" },
    studio: null,
    live: { tracks: [{ index: 1, distanceMiles: 1, durationSeconds: 580 }] },
    plannedShowId: null,
    healthWorkoutId: null,
    createdAt: "2026-11-21T08:00:00.000Z",
    updatedAt: "2026-11-21T08:00:00.000Z",
    deletedAt: null,
    ...extra,
  };
}

/** Syncs [rows] into [table] the way the app does (POST /api/sync). */
async function sync(
  r: Runner,
  table: "shows" | "gear" | "tours",
  rows: { id: string; data: Record<string, unknown>; deletedAt?: string | null; updatedAt?: string }[],
) {
  const res = await call("POST", `/api/sync/${table}`, {
    token: r.token,
    body: {
      rows: rows.map((row) => ({
        id: row.id,
        data: row.data,
        updatedAt: row.updatedAt ?? new Date().toISOString(),
        deletedAt: row.deletedAt ?? null,
      })),
    },
  });
  expect(res.status).toBe(200);
}

/** Syncs one Show and returns its id. */
async function logShow(r: Runner, name: string, extra: Record<string, unknown> = {}) {
  const id = rid(name);
  await sync(r, "shows", [{ id, data: show(id, extra) }]);
  return id;
}

function tour(id: string, setup: Record<string, unknown>, extra: Record<string, unknown> = {}) {
  return {
    schemaVersion: 1,
    id,
    name: "Spring Tour",
    setup: { goal: "finish", ...setup },
    weeks: [{ index: 0, shows: [] }],
    ...extra,
  };
}

async function feed(r: Runner) {
  const res = await callJson("GET", "/api/crew/feed", { token: r.token });
  expect(res.status).toBe(200);
  return res.body.posts as any[];
}

describe("profile", () => {
  it("is null at first, then saved and trimmed", async () => {
    const r = await newRunner();
    expect((await callJson("GET", "/api/crew/profile", { token: r.token })).body).toBeNull();
    const p = await profile(r, "  Maya   Runs ", { color: 7 });
    expect(p).toEqual({ userId: r.user.id, stageName: "Maya Runs", color: 7 });
    expect((await callJson("GET", "/api/crew/profile", { token: r.token })).body).toEqual(p);
  });

  it("ignores the old sharing fields, so older app builds still save", async () => {
    const r = await newRunner();
    const p = await profile(r, "Maya", {
      alwaysShare: "yes",
      showOpeningNight: true,
      openingNight: "April 20",
      tourName: 42,
    });
    expect(p).toEqual({ userId: r.user.id, stageName: "Maya", color: 1 });
  });

  it("validates stage name and color", async () => {
    const r = await newRunner();
    for (const body of [
      { stageName: "   " },
      { stageName: "x".repeat(31) },
      { stageName: "Maya", color: 8 },
      { stageName: "Maya", color: -1 },
      { stageName: "Maya", color: 1.5 },
      { color: 1 },
    ]) {
      const res = await callJson("PUT", "/api/crew/profile", { token: r.token, body });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe("bad_request");
    }
    // 30 characters is fine.
    expect((await profile(r, "x".repeat(30))).stageName).toHaveLength(30);
  });

  it("needs sign-in", async () => {
    expect((await callJson("GET", "/api/crew/profile")).status).toBe(401);
  });
});

describe("invites", () => {
  it("codes are 8 characters from the alphabet", () => {
    for (let i = 0; i < 200; i++) {
      const code = newInviteCode();
      expect(code).toHaveLength(8);
      for (const ch of code) expect(INVITE_ALPHABET).toContain(ch);
    }
  });

  it("needs a stage name", async () => {
    const r = await newRunner();
    const res = await callJson("POST", "/api/crew/invite", { token: r.token });
    expect(res.status).toBe(409);
    expect(res.body.error).toBe("need_stage_name");
  });

  it("reuses the code while more than a day is left, then makes a new one", async () => {
    const r = await newRunner();
    await profile(r, "Maya");
    const code = await invite(r);
    expect(code).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$/);
    expect(await invite(r)).toBe(code);

    const row = await env.DB.prepare("SELECT created_at, expires_at FROM crew_invites WHERE code = ?")
      .bind(code)
      .first<{ created_at: string; expires_at: string }>();
    expect(Date.parse(row!.expires_at) - Date.parse(row!.created_at)).toBe(7 * 86400_000);

    // Six and a half days later: less than a day left, so a new code.
    const later = new Date(Date.now() + 6.5 * 86400_000);
    const fresh = await inviteCode(env.DB, r.user.id, later);
    expect(fresh).not.toBe(code);
    expect(await count("SELECT count(*) AS n FROM crew_invites WHERE owner = ?", r.user.id)).toBe(1);
  });

  it("preview says who sent it; unknown codes are invite_invalid", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya", { color: 3 });
    const code = await invite(maya);

    const pretty = `${code.slice(0, 4).toLowerCase()}-${code.slice(4)}`;
    const res = await callJson("GET", `/api/crew/invite/${pretty}`, { token: ryan.token });
    expect(res).toEqual({
      status: 200,
      body: { stageName: "Maya", color: 3, alreadyCrew: false, ownInvite: false },
    });

    const own = await callJson("GET", `/api/crew/invite/${code}`, { token: maya.token });
    expect(own.body).toMatchObject({ ownInvite: true, alreadyCrew: false });

    const bad = await callJson("GET", "/api/crew/invite/ZZZZZZZZ", { token: ryan.token });
    expect(bad.status).toBe(404);
    expect(bad.body.error).toBe("invite_invalid");
    expect(await count("SELECT count(*) AS n FROM crew_invite_misses WHERE user_id = ?", ryan.user.id)).toBe(1);
  });

  it("join links both ways; preview then says alreadyCrew", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");

    const code = await invite(maya);
    const noName = await join(ryan, code);
    expect(noName.status).toBe(409);
    expect(noName.body.error).toBe("need_stage_name");

    await profile(ryan, "Ryan");
    const res = await join(ryan, code);
    expect(res).toEqual({ status: 200, body: { userId: maya.user.id } });
    // Joining again is fine.
    expect((await join(ryan, code)).status).toBe(200);

    const preview = await callJson("GET", `/api/crew/invite/${code}`, { token: ryan.token });
    expect(preview.body.alreadyCrew).toBe(true);

    const mayaMates = (await callJson("GET", "/api/crew/mates", { token: maya.token })).body.mates;
    expect(mayaMates).toEqual([
      expect.objectContaining({ userId: ryan.user.id, stageName: "Ryan", blocked: false }),
    ]);
    const ryanMates = (await callJson("GET", "/api/crew/mates", { token: ryan.token })).body.mates;
    expect(ryanMates[0]).toMatchObject({ userId: maya.user.id, stageName: "Maya", color: 1 });
    expect(ryanMates[0].since).toMatch(/Z$/);
  });

  it("own invite gets own_invite", async () => {
    const maya = await newRunner("Maya");
    await profile(maya, "Maya");
    const res = await join(maya, await invite(maya));
    expect(res.status).toBe(409);
    expect(res.body.error).toBe("own_invite");
  });

  it("expired codes are invite_invalid", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");
    await profile(ryan, "Ryan");
    const old = await inviteCode(env.DB, maya.user.id, new Date(Date.now() - 8 * 86400_000));
    const res = await join(ryan, old);
    expect(res.status).toBe(404);
    expect(res.body.error).toBe("invite_invalid");
  });

  it("ten wrong codes in an hour gets too_many_tries, even for a good code", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");
    await profile(ryan, "Ryan");
    const good = await invite(maya);

    for (let i = 0; i < 10; i++) {
      const res = await join(ryan, "WRONGWRNG".slice(0, 8));
      expect(res.body.error).toBe("invite_invalid");
    }
    const blocked = await join(ryan, good);
    expect(blocked.status).toBe(429);
    expect(blocked.body.error).toBe("too_many_tries");
    const preview = await callJson("GET", `/api/crew/invite/${good}`, { token: ryan.token });
    expect(preview.status).toBe(429);

    // Misses older than an hour don't count.
    await env.DB.prepare("UPDATE crew_invite_misses SET at = ? WHERE user_id = ?")
      .bind(new Date(Date.now() - 2 * 3600_000).toISOString(), ryan.user.id)
      .run();
    expect((await join(ryan, good)).status).toBe(200);
  });

  it("nine wrong codes still let you in", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");
    await profile(ryan, "Ryan");
    for (let i = 0; i < 9; i++) await join(ryan, "ZZZZZZZZ");
    expect((await join(ryan, await invite(maya))).status).toBe(200);
  });

  it("a blocked runner's code counts as wrong, both ways", async () => {
    const maya = await newRunner("Maya");
    const ryan = await newRunner("Ryan");
    await profile(maya, "Maya");
    await profile(ryan, "Ryan");
    const code = await invite(maya);
    // Maya blocks Ryan: Ryan can't use Maya's code.
    expect((await call("POST", "/api/crew/blocks", { token: maya.token, body: { userId: ryan.user.id } })).status).toBe(204);
    const res = await join(ryan, code);
    expect(res.body.error).toBe("invite_invalid");
    expect(await count("SELECT count(*) AS n FROM crew_invite_misses WHERE user_id = ?", ryan.user.id)).toBe(1);
    // And Maya can't use Ryan's.
    const back = await join(maya, await invite(ryan));
    expect(back.body.error).toBe("invite_invalid");
  });
});

describe("mates and blocks", () => {
  it("leaving ends the link for both", async () => {
    const { maya, ryan } = await crewPair();
    expect((await call("DELETE", `/api/crew/mates/${maya.user.id}`, { token: ryan.token })).status).toBe(204);
    expect((await callJson("GET", "/api/crew/mates", { token: maya.token })).body.mates).toEqual([]);
    expect((await callJson("GET", "/api/crew/mates", { token: ryan.token })).body.mates).toEqual([]);
  });

  it("blocking ends the link and lists the blocked runner last", async () => {
    const { maya, ryan } = await crewPair();
    const zed = await newRunner("Zed");
    await profile(zed, "Zed");
    await join(zed, await invite(maya));

    await call("POST", "/api/crew/blocks", { token: maya.token, body: { userId: ryan.user.id } });
    const mates = (await callJson("GET", "/api/crew/mates", { token: maya.token })).body.mates;
    expect(mates.map((m: any) => [m.stageName, m.blocked])).toEqual([["Zed", false], ["Ryan", true]]);
    expect(mates[1].tour).toBeNull();
    expect(await count(
      "SELECT count(*) AS n FROM crew_links WHERE ? IN (user_a, user_b) AND ? IN (user_a, user_b)",
      maya.user.id, ryan.user.id,
    )).toBe(0);
    // Ryan doesn't see Maya at all (and doesn't see that he's blocked).
    expect((await callJson("GET", "/api/crew/mates", { token: ryan.token })).body.mates).toEqual([]);
  });

  it("cant_block yourself or an unknown id", async () => {
    const r = await newRunner();
    for (const userId of [r.user.id, crypto.randomUUID(), 42, undefined]) {
      const res = await callJson("POST", "/api/crew/blocks", { token: r.token, body: { userId } });
      expect(res.status).toBe(400);
      expect(res.body.error).toBe("cant_block");
    }
  });

  it("each block is its own row; unblocking removes only your own", async () => {
    const { maya, ryan } = await crewPair();
    await call("POST", "/api/crew/blocks", { token: maya.token, body: { userId: ryan.user.id } });
    await call("POST", "/api/crew/blocks", { token: ryan.token, body: { userId: maya.user.id } });
    expect(await count("SELECT count(*) AS n FROM crew_blocks WHERE blocker IN (?, ?)", maya.user.id, ryan.user.id)).toBe(2);

    // Ryan unblocks Maya: Maya's block of Ryan stays.
    expect((await call("DELETE", `/api/crew/blocks/${maya.user.id}`, { token: ryan.token })).status).toBe(204);
    const rows = await env.DB.prepare("SELECT blocker, blocked FROM crew_blocks WHERE blocker IN (?, ?)")
      .bind(maya.user.id, ryan.user.id)
      .all();
    expect(rows.results).toEqual([{ blocker: maya.user.id, blocked: ryan.user.id }]);

    // Ryan can't remove Maya's block either.
    await call("DELETE", `/api/crew/blocks/${ryan.user.id}`, { token: ryan.token });
    expect(await count("SELECT count(*) AS n FROM crew_blocks WHERE blocker = ?", maya.user.id)).toBe(1);

    // Still blocked: rejoining fails.
    expect((await join(ryan, await invite(maya))).body.error).toBe("invite_invalid");
    // Maya unblocks: now they can rejoin.
    await call("DELETE", `/api/crew/blocks/${ryan.user.id}`, { token: maya.token });
    expect((await join(ryan, await invite(maya))).status).toBe(200);
  });
});

describe("the feed", () => {
  it("shows yours and your Crew's synced Shows, not strangers', newest Show first", async () => {
    const { maya, ryan } = await crewPair();
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");

    const shoes = rid("gear");
    await sync(ryan, "gear", [{ id: shoes, data: { id: shoes, name: "Pegasus 41" } }]);
    const mayaShow = await logShow(maya, "maya", { date: "2026-11-20T06:00:00.000" });
    const ryanShow = await logShow(ryan, "ryan", { date: "2026-11-21T07:30:00.000", gearId: shoes });
    const strangerShow = await logShow(stranger, "stranger");

    const posts = await feed(maya);
    expect(posts.map((p) => p.showId)).toEqual([ryanShow, mayaShow]);
    const [ryans, mine] = posts;
    expect(ryans).toMatchObject({
      id: `${ryan.user.id}:${ryanShow}`,
      ownerId: ryan.user.id,
      stageName: "Ryan",
      color: 1,
      showId: ryanShow,
      show: show(ryanShow, { date: "2026-11-21T07:30:00.000", gearId: shoes }),
      gearName: "Pegasus 41",
      encores: 0,
      encoredByMe: false,
      mine: false,
    });
    // Everything on the Show comes through: effort, feel, notes, Tracks, song.
    expect(ryans.show).toMatchObject({ effort: 6, feel: "great", notes: "Legs felt fresh" });
    expect(ryans.show.live.tracks).toHaveLength(1);
    expect(mine).toMatchObject({ mine: true, gearName: null });
    expect(ryans.sharedAt).toMatch(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/);
    expect(Object.keys(ryans).sort()).toEqual(
      ["color", "encoredByMe", "encores", "gearName", "id", "mine", "ownerId", "sharedAt", "show", "showId", "stageName"],
    );

    expect((await feed(stranger)).map((p) => p.showId)).toEqual([strangerShow]);
  });

  it("leaves out deleted Shows and Shows kept off the Crew, yours too", async () => {
    const { maya, ryan } = await crewPair();
    await logShow(ryan, "kept", { crewPrivate: true });
    const open = await logShow(ryan, "open", { crewPrivate: false });
    const gone = rid("gone");
    await sync(ryan, "shows", [{ id: gone, data: show(gone), deletedAt: new Date().toISOString() }]);
    await logShow(maya, "mine", { crewPrivate: true });

    expect((await feed(maya)).map((p) => p.showId)).toEqual([open]);
    expect((await feed(ryan)).map((p) => p.showId)).toEqual([open]);

    // Marking it private later hides it again.
    await sync(ryan, "shows", [{ id: open, data: show(open, { crewPrivate: true }) }]);
    expect(await feed(maya)).toEqual([]);
  });

  it("gearName is null when the Gear is deleted or unknown", async () => {
    const { maya, ryan } = await crewPair();
    const shoes = rid("gear");
    await sync(ryan, "gear", [{ id: shoes, data: { id: shoes, name: "Old pair" }, deletedAt: new Date().toISOString() }]);
    await logShow(ryan, "a", { gearId: shoes, date: "2026-11-21T07:00:00.000" });
    await logShow(ryan, "b", { gearId: "nope", date: "2026-11-20T07:00:00.000" });
    // Gear with the same id under another runner doesn't count.
    const theirs = rid("gear");
    await sync(maya, "gear", [{ id: theirs, data: { id: theirs, name: "Maya's" } }]);
    await logShow(ryan, "c", { gearId: theirs, date: "2026-11-19T07:00:00.000" });
    expect((await feed(maya)).map((p) => p.gearName)).toEqual([null, null, null]);
  });

  it("blocks hide Shows both ways", async () => {
    const { maya, ryan } = await crewPair();
    await logShow(ryan, "ryan");
    const mayaShow = await logShow(maya, "maya");
    await call("POST", "/api/crew/blocks", { token: ryan.token, body: { userId: maya.user.id } });
    expect((await feed(maya)).map((p) => p.showId)).toEqual([mayaShow]);
    // Re-link directly, to check the feed's own block check too.
    const [a, b] = [maya.user.id, ryan.user.id].sort();
    await env.DB.prepare("INSERT INTO crew_links (user_a, user_b, created_at) VALUES (?, ?, ?)")
      .bind(a, b, new Date().toISOString()).run();
    expect((await feed(maya)).map((p) => p.showId)).toEqual([mayaShow]);
    expect((await feed(ryan)).map((p) => p.ownerId)).toEqual([ryan.user.id]);
    expect((await callJson("GET", "/api/crew/mates", { token: maya.token })).body.mates).toEqual([]);
  });

  it("is empty without a stage name", async () => {
    const r = await newRunner();
    await logShow(r, "solo");
    expect(await feed(r)).toEqual([]);
  });

  it("has at most 60 posts", async () => {
    const r = await newRunner();
    await profile(r, "Many");
    const rows = Array.from({ length: 62 }, (_, i) => {
      const id = rid(`s${i}`);
      return { id, data: show(id) };
    });
    await sync(r, "shows", rows);
    expect(await feed(r)).toHaveLength(60);
  });
});

describe("old sharing routes", () => {
  it("answer as before and do nothing", async () => {
    const { maya, ryan } = await crewPair();
    const body = { show: show("x"), showUpdatedAt: "2026-11-21T08:00:00.000Z" };
    expect((await call("PUT", "/api/crew/shared/old-1", { token: maya.token, body })).status).toBe(204);
    expect((await call("DELETE", "/api/crew/shared/old-1", { token: maya.token })).status).toBe(204);
    const shared = await callJson("GET", "/api/crew/shared", { token: maya.token });
    expect(shared).toEqual({ status: 200, body: { shared: {} } });
    expect(await feed(ryan)).toEqual([]);
    expect(await count("SELECT count(*) AS n FROM records WHERE user_id = ?", maya.user.id)).toBe(0);
  });
});

describe("mates and their Tours", () => {
  it("each mate carries their active Tour: the latest race on or after today", async () => {
    const { maya, ryan } = await crewPair();
    const [past, soon, later, gone] = [rid("past"), rid("soon"), rid("later"), rid("gone")];
    await sync(ryan, "tours", [
      { id: past, data: tour(past, { raceDate: day(-3), raceDistance: "half" }) },
      { id: soon, data: tour(soon, { raceDate: day(0), raceDistance: "tenK" }) },
      { id: later, data: tour(later, { raceDate: day(90) }, { name: "Boston Tour", featuring: { userId: maya.user.id, stageName: "Maya" } }) },
      { id: gone, data: tour(gone, { raceDate: day(200) }), deletedAt: new Date().toISOString() },
    ]);
    const mates = (await callJson("GET", "/api/crew/mates", { token: maya.token })).body.mates;
    expect(mates).toEqual([
      {
        userId: ryan.user.id,
        stageName: "Ryan",
        color: 1,
        since: expect.stringMatching(/Z$/),
        tour: {
          id: later,
          name: "Boston Tour",
          raceDate: day(90),
          raceDistance: "marathon",
          featuring: { userId: maya.user.id, stageName: "Maya" },
        },
        blocked: false,
      },
    ]);

    // With the big race deleted, today's race is the active one.
    await sync(ryan, "tours", [{ id: later, data: tour(later, { raceDate: day(90) }), deletedAt: new Date().toISOString() }]);
    const [mate] = (await callJson("GET", "/api/crew/mates", { token: maya.token })).body.mates;
    expect(mate.tour).toEqual({ id: soon, name: "Spring Tour", raceDate: day(0), raceDistance: "tenK", featuring: null });

    // No Tour at all: null.
    expect((await callJson("GET", "/api/crew/mates", { token: ryan.token })).body.mates[0].tour).toBeNull();
  });

  it("mate detail has their profile, whole active Tour and every visible Show", async () => {
    const { maya, ryan } = await crewPair();
    const t = rid("tour");
    const ryanTour = tour(t, { raceDate: day(30), raceDistance: "half" });
    await sync(ryan, "tours", [{ id: t, data: ryanTour }]);
    const rows = Array.from({ length: 70 }, (_, i) => {
      const id = rid(`s${i}`);
      const date = `2026-${String(1 + Math.floor(i / 28)).padStart(2, "0")}-${String(1 + (i % 28)).padStart(2, "0")}T07:00:00.000`;
      return { id, data: show(id, { date }) };
    });
    await sync(ryan, "shows", rows);
    await logShow(ryan, "private", { crewPrivate: true });

    const res = await callJson("GET", `/api/crew/mates/${ryan.user.id}`, { token: maya.token });
    expect(res.status).toBe(200);
    expect(Object.keys(res.body).sort()).toEqual(["mate", "shows", "tour"]);
    expect(res.body.mate).toEqual({
      userId: ryan.user.id,
      stageName: "Ryan",
      color: 1,
      since: expect.stringMatching(/Z$/),
    });
    expect(res.body.tour).toEqual(ryanTour);
    const shows = res.body.shows as any[];
    expect(shows).toHaveLength(70);
    expect(shows[0]).toMatchObject({ ownerId: ryan.user.id, mine: false, gearName: null, encores: 0 });
    expect(shows[0].id).toBe(`${ryan.user.id}:${shows[0].showId}`);
    const dates = shows.map((p) => p.show.date);
    expect(dates).toEqual([...dates].sort().reverse());

    // Your own page works too.
    const own = await callJson("GET", `/api/crew/mates/${maya.user.id}`, { token: maya.token });
    expect(own.status).toBe(200);
    expect(own.body).toMatchObject({ mate: { userId: maya.user.id, stageName: "Maya" }, tour: null, shows: [] });
  });

  it("mate detail is not_found for anyone outside your Crew", async () => {
    const { maya, ryan } = await crewPair();
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");
    await logShow(stranger, "s");
    for (const id of [stranger.user.id, crypto.randomUUID()]) {
      const res = await callJson("GET", `/api/crew/mates/${id}`, { token: maya.token });
      expect(res.status).toBe(404);
      expect(res.body.error).toBe("not_found");
    }
    // Blocked: gone both ways.
    await call("POST", "/api/crew/blocks", { token: maya.token, body: { userId: ryan.user.id } });
    expect((await callJson("GET", `/api/crew/mates/${ryan.user.id}`, { token: maya.token })).status).toBe(404);
    expect((await callJson("GET", `/api/crew/mates/${maya.user.id}`, { token: ryan.token })).status).toBe(404);
  });
});

describe("Encores", () => {
  it("only on Shows you can see, never your own; counts without names", async () => {
    const { maya, ryan } = await crewPair();
    const zed = await newRunner("Zed");
    await profile(zed, "Zed");
    await join(zed, await invite(maya));
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");

    const showId = await logShow(maya, "m1");
    const postId = `${maya.user.id}:${showId}`;
    expect((await feed(maya))[0].id).toBe(postId);

    const own = await callJson("PUT", `/api/crew/posts/${postId}/encore`, { token: maya.token });
    expect(own.status).toBe(400);
    expect(own.body.error).toBe("bad_request");

    const notVisible = await callJson("PUT", `/api/crew/posts/${postId}/encore`, { token: stranger.token });
    expect(notVisible.status).toBe(404);
    expect(notVisible.body.error).toBe("not_found");
    for (const bad of [crypto.randomUUID(), `${maya.user.id}:nope`, `${ryan.user.id}:${showId}`, `:${showId}`]) {
      const res = await callJson("PUT", `/api/crew/posts/${encodeURIComponent(bad)}/encore`, { token: ryan.token });
      expect(res.status, bad).toBe(404);
    }

    expect((await call("PUT", `/api/crew/posts/${postId}/encore`, { token: ryan.token })).status).toBe(204);
    expect((await call("PUT", `/api/crew/posts/${postId}/encore`, { token: ryan.token })).status).toBe(204);
    // An encoded colon works too.
    expect((await call("PUT", `/api/crew/posts/${encodeURIComponent(postId)}/encore`, { token: zed.token })).status).toBe(204);

    const forMaya = (await feed(maya))[0];
    expect(forMaya).toMatchObject({ encores: 2, encoredByMe: false });
    expect(JSON.stringify(forMaya)).not.toContain(ryan.user.id);
    const forRyan = (await feed(ryan)).find((p) => p.id === postId);
    expect(forRyan).toMatchObject({ encores: 2, encoredByMe: true });
    const onPage = (await callJson("GET", `/api/crew/mates/${maya.user.id}`, { token: ryan.token })).body.shows[0];
    expect(onPage).toMatchObject({ id: postId, encores: 2, encoredByMe: true });

    expect((await call("DELETE", `/api/crew/posts/${postId}/encore`, { token: ryan.token })).status).toBe(204);
    expect((await feed(ryan)).find((p) => p.id === postId)).toMatchObject({ encores: 1, encoredByMe: false });
  });

  it("not on a Show kept off the Crew or deleted", async () => {
    const { maya, ryan } = await crewPair();
    const kept = await logShow(maya, "kept", { crewPrivate: true });
    const gone = rid("gone");
    await sync(maya, "shows", [{ id: gone, data: show(gone), deletedAt: new Date().toISOString() }]);
    for (const id of [kept, gone]) {
      const res = await callJson("PUT", `/api/crew/posts/${maya.user.id}:${id}/encore`, { token: ryan.token });
      expect(res.status).toBe(404);
    }
  });
});

describe("reports", () => {
  it("hides the Show from the reporter and snapshots its data", async () => {
    const { maya, ryan } = await crewPair();
    const showId = await logShow(maya, "m1", { notes: "original" });
    const postId = (await feed(ryan))[0].id;
    expect(postId).toBe(`${maya.user.id}:${showId}`);

    for (const reason of ["", "   ", "x".repeat(501), 5]) {
      const res = await callJson("POST", `/api/crew/posts/${postId}/report`, { token: ryan.token, body: { reason } });
      expect(res.status).toBe(400);
    }
    const own = await callJson("POST", `/api/crew/posts/${postId}/report`, { token: maya.token, body: { reason: "me" } });
    expect(own.status).toBe(400);

    const res = await call("POST", `/api/crew/posts/${postId}/report`, {
      token: ryan.token,
      body: { reason: "Not a real run" },
    });
    expect(res.status).toBe(204);
    expect(await feed(ryan)).toEqual([]);
    expect((await callJson("GET", `/api/crew/mates/${maya.user.id}`, { token: ryan.token })).body.shows).toEqual([]);
    expect(await feed(maya)).toHaveLength(1);

    // Maya edits and then deletes it; the report keeps what Ryan saw.
    await sync(maya, "shows", [{ id: showId, data: show(showId, { notes: "edited" }) }]);
    await sync(maya, "shows", [{ id: showId, data: show(showId), deletedAt: new Date().toISOString() }]);
    const report = await env.DB.prepare("SELECT * FROM crew_reports WHERE reporter = ?")
      .bind(ryan.user.id)
      .first<{ post_id: string; reported_user: string; post_data: string; reason: string }>();
    expect(report).toMatchObject({ post_id: showId, reported_user: maya.user.id, reason: "Not a real run" });
    expect(JSON.parse(report!.post_data).notes).toBe("original");
  });

  it("can't report a Show you can't see", async () => {
    const maya = await newRunner("Maya");
    const stranger = await newRunner("Stranger");
    await profile(maya, "Maya");
    const showId = await logShow(maya, "m1");
    const res = await callJson("POST", `/api/crew/posts/${maya.user.id}:${showId}/report`, {
      token: stranger.token,
      body: { reason: "spam" },
    });
    expect(res.status).toBe(404);
  });
});
