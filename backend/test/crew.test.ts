import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import { INVITE_ALPHABET, inviteCode, newInviteCode } from "../src/crew";
import { call, callJson, count, newRunner, type Runner } from "./helpers";

async function profile(r: Runner, stageName: string, extra: Record<string, unknown> = {}) {
  const res = await callJson("PUT", "/api/crew/profile", {
    token: r.token,
    body: { stageName, color: 1, alwaysShare: false, showOpeningNight: false, openingNight: null, tourName: null, ...extra },
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

const SHOW = {
  date: "2026-11-21T07:30:00.000",
  venue: "outdoor",
  workoutType: "easy",
  distanceMiles: 3.1,
  durationSeconds: 1800,
  song: { title: "Mr. Brightside", artist: "The Killers" },
  goldRecords: ["Fastest 5K"],
  notes: null,
};

async function share(r: Runner, showId: string, show: Record<string, unknown> = SHOW) {
  return call("PUT", `/api/crew/shared/${showId}`, {
    token: r.token,
    body: { show, showUpdatedAt: "2026-11-21T08:00:00.000Z" },
  });
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
    const p = await profile(r, "  Maya   Runs ", {
      color: 7,
      alwaysShare: true,
      showOpeningNight: true,
      openingNight: "2027-04-20",
      tourName: "Boston Tour",
    });
    expect(p).toEqual({
      userId: r.user.id,
      stageName: "Maya Runs",
      color: 7,
      alwaysShare: true,
      showOpeningNight: true,
      openingNight: "2027-04-20",
      tourName: "Boston Tour",
    });
    expect((await callJson("GET", "/api/crew/profile", { token: r.token })).body).toEqual(p);
  });

  it("drops Opening Night and the Tour name when showOpeningNight is off", async () => {
    const r = await newRunner();
    const p = await profile(r, "Maya", { showOpeningNight: false, openingNight: "2027-04-20", tourName: "Boston" });
    expect(p.openingNight).toBeNull();
    expect(p.tourName).toBeNull();
  });

  it("validates stage name, color and date", async () => {
    const r = await newRunner();
    for (const body of [
      { stageName: "   " },
      { stageName: "x".repeat(31) },
      { stageName: "Maya", color: 8 },
      { stageName: "Maya", color: -1 },
      { stageName: "Maya", color: 1.5 },
      { stageName: "Maya", showOpeningNight: true, openingNight: "April 20" },
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
    expect(mates[1]).toMatchObject({ openingNight: null, tourName: null });
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

describe("shared Shows and the feed", () => {
  it("needs a stage name and at most 8 KB", async () => {
    const r = await newRunner();
    const noName = await callJson("PUT", "/api/crew/shared/s1", {
      token: r.token,
      body: { show: SHOW, showUpdatedAt: "2026-11-21T08:00:00.000Z" },
    });
    expect(noName.status).toBe(409);
    expect(noName.body.error).toBe("need_stage_name");

    await profile(r, "Maya");
    const big = await share(r, "s1", { ...SHOW, notes: "x".repeat(9000) });
    expect(big.status).toBe(400);
    const missing = await callJson("PUT", "/api/crew/shared/s1", { token: r.token, body: { show: SHOW } });
    expect(missing.status).toBe(400);
  });

  it("feed shows yours and your Crew's, not strangers', newest first", async () => {
    const { maya, ryan } = await crewPair();
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");

    expect((await share(maya, "maya-1")).status).toBe(204);
    await new Promise((r) => setTimeout(r, 5)); // distinct sharedAt
    expect((await share(ryan, "ryan-1")).status).toBe(204);
    expect((await share(stranger, "stranger-1")).status).toBe(204);

    const posts = await feed(maya);
    expect(posts.map((p) => p.showId)).toEqual(["ryan-1", "maya-1"]);
    const [ryans, mine] = posts;
    expect(ryans).toMatchObject({
      ownerId: ryan.user.id,
      stageName: "Ryan",
      color: 1,
      show: SHOW,
      encores: 0,
      encoredByMe: false,
      mine: false,
    });
    expect(mine.mine).toBe(true);
    expect(ryans.sharedAt).toMatch(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/);
    expect(Object.keys(ryans).sort()).toEqual(
      ["color", "encoredByMe", "encores", "id", "mine", "ownerId", "sharedAt", "show", "showId", "stageName"],
    );

    expect((await feed(stranger)).map((p) => p.showId)).toEqual(["stranger-1"]);
  });

  it("blocks hide posts both ways", async () => {
    const { maya, ryan } = await crewPair();
    await share(ryan, "ryan-1");
    await share(maya, "maya-1");
    // Re-link directly, to check the feed's own block check too.
    await call("POST", "/api/crew/blocks", { token: ryan.token, body: { userId: maya.user.id } });
    const [a, b] = [maya.user.id, ryan.user.id].sort();
    await env.DB.prepare("INSERT INTO crew_links (user_a, user_b, created_at) VALUES (?, ?, ?)")
      .bind(a, b, new Date().toISOString()).run();
    expect((await feed(maya)).map((p) => p.showId)).toEqual(["maya-1"]);
    expect((await feed(ryan)).map((p) => p.showId)).toEqual(["ryan-1"]);
    expect((await callJson("GET", "/api/crew/mates", { token: maya.token })).body.mates).toEqual([]);
  });

  it("re-sharing replaces the copy but keeps sharedAt; shared lists notes", async () => {
    const { maya } = await crewPair();
    await share(maya, "s1");
    const first = (await feed(maya))[0];
    await new Promise((r) => setTimeout(r, 5));
    await call("PUT", "/api/crew/shared/s1", {
      token: maya.token,
      body: { show: { ...SHOW, notes: "Felt great" }, showUpdatedAt: "2026-11-21T09:00:00.000Z" },
    });
    const again = await feed(maya);
    expect(again).toHaveLength(1);
    expect(again[0].id).toBe(first.id);
    expect(again[0].sharedAt).toBe(first.sharedAt);
    expect(again[0].show.notes).toBe("Felt great");

    await share(maya, "s2");
    const shared = (await callJson("GET", "/api/crew/shared", { token: maya.token })).body.shared;
    expect(shared).toEqual({
      s1: { showUpdatedAt: "2026-11-21T09:00:00.000Z", includesNotes: true },
      s2: { showUpdatedAt: "2026-11-21T08:00:00.000Z", includesNotes: false },
    });
  });

  it("feed has at most 60 posts", async () => {
    const r = await newRunner();
    await profile(r, "Many");
    for (let i = 0; i < 62; i++) await share(r, `s${i}`);
    expect(await feed(r)).toHaveLength(60);
  });
});

describe("Encores", () => {
  it("only on posts you can see, never your own; counts without names", async () => {
    const { maya, ryan } = await crewPair();
    const zed = await newRunner("Zed");
    await profile(zed, "Zed");
    await join(zed, await invite(maya));
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");

    await share(maya, "m1");
    const postId = (await feed(maya))[0].id;

    const own = await callJson("PUT", `/api/crew/posts/${postId}/encore`, { token: maya.token });
    expect(own.status).toBe(400);
    expect(own.body.error).toBe("bad_request");

    const notVisible = await callJson("PUT", `/api/crew/posts/${postId}/encore`, { token: stranger.token });
    expect(notVisible.status).toBe(404);
    expect(notVisible.body.error).toBe("not_found");
    const unknown = await callJson("PUT", `/api/crew/posts/${crypto.randomUUID()}/encore`, { token: ryan.token });
    expect(unknown.status).toBe(404);

    expect((await call("PUT", `/api/crew/posts/${postId}/encore`, { token: ryan.token })).status).toBe(204);
    expect((await call("PUT", `/api/crew/posts/${postId}/encore`, { token: ryan.token })).status).toBe(204);
    expect((await call("PUT", `/api/crew/posts/${postId}/encore`, { token: zed.token })).status).toBe(204);

    const forMaya = (await feed(maya))[0];
    expect(forMaya).toMatchObject({ encores: 2, encoredByMe: false });
    expect(JSON.stringify(forMaya)).not.toContain(ryan.user.id);
    const forRyan = (await feed(ryan)).find((p) => p.id === postId);
    expect(forRyan).toMatchObject({ encores: 2, encoredByMe: true });

    expect((await call("DELETE", `/api/crew/posts/${postId}/encore`, { token: ryan.token })).status).toBe(204);
    expect((await feed(ryan)).find((p) => p.id === postId)).toMatchObject({ encores: 1, encoredByMe: false });
  });

  it("unsharing takes the Encores with it", async () => {
    const { maya, ryan } = await crewPair();
    await share(maya, "m1");
    const postId = (await feed(maya))[0].id;
    await call("PUT", `/api/crew/posts/${postId}/encore`, { token: ryan.token });
    expect((await call("DELETE", "/api/crew/shared/m1", { token: maya.token })).status).toBe(204);
    expect(await feed(ryan)).toEqual([]);
    expect(await count("SELECT count(*) AS n FROM crew_encores WHERE post_id = ?", postId)).toBe(0);
    expect((await callJson("GET", "/api/crew/shared", { token: maya.token })).body.shared).toEqual({});
  });
});

describe("reports", () => {
  it("hides the post from the reporter and snapshots its data", async () => {
    const { maya, ryan } = await crewPair();
    await share(maya, "m1", { ...SHOW, notes: "original" });
    const postId = (await feed(ryan))[0].id;

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
    expect(await feed(maya)).toHaveLength(1);

    // Maya edits and then unshares; the report keeps what Ryan saw.
    await share(maya, "m1", { ...SHOW, notes: "edited" });
    await call("DELETE", "/api/crew/shared/m1", { token: maya.token });
    const report = await env.DB.prepare("SELECT * FROM crew_reports WHERE reporter = ?")
      .bind(ryan.user.id)
      .first<{ post_id: string; reported_user: string; post_data: string; reason: string }>();
    expect(report).toMatchObject({ post_id: postId, reported_user: maya.user.id, reason: "Not a real run" });
    expect(JSON.parse(report!.post_data).notes).toBe("original");
  });

  it("can't report a post you can't see", async () => {
    const maya = await newRunner("Maya");
    const stranger = await newRunner("Stranger");
    await profile(maya, "Maya");
    await share(maya, "m1");
    const postId = (await feed(maya))[0].id;
    const res = await callJson("POST", `/api/crew/posts/${postId}/report`, {
      token: stranger.token,
      body: { reason: "spam" },
    });
    expect(res.status).toBe(404);
  });
});
