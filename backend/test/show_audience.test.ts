import { describe, expect, it } from "vitest";
import { call, callJson, count, newRunner, type Runner } from "./helpers";

async function profile(r: Runner, stageName: string, extra: Record<string, unknown> = {}) {
  const res = await callJson("PUT", "/api/crew/profile", {
    token: r.token,
    body: { stageName, color: 1, ...extra },
  });
  expect(res.status).toBe(200);
  return res.body;
}

async function befriend(a: Runner, b: Runner) {
  const code = (await callJson("POST", "/api/crew/invite", { token: a.token })).body.code;
  expect((await call("POST", "/api/crew/join", { token: b.token, body: { code } })).status).toBe(200);
}

async function syncShow(r: Runner): Promise<string> {
  const id = `show-${crypto.randomUUID().slice(0, 8)}`;
  const res = await call("POST", "/api/sync/shows", {
    token: r.token,
    body: {
      rows: [{ id, data: { id, date: "2026-11-21T07:30:00.000", distanceMiles: 3 }, updatedAt: new Date().toISOString(), deletedAt: null }],
    },
  });
  expect(res.status).toBe(200);
  return `${r.user.id}:${id}`;
}

const seen = (r: Runner, post: string) =>
  call("PUT", `/api/crew/posts/${post}/seen`, { token: r.token });
const audience = async (r: Runner, post: string) =>
  callJson("GET", `/api/crew/posts/${post}/audience`, { token: r.token });
const myPost = async (r: Runner, post: string) =>
  (await callJson("GET", "/api/crew/feed", { token: r.token })).body.posts.find((p: any) => p.id === post);

/** Ryan with a Show, and Maya, Sam and Jo in his Crew. */
async function stage() {
  const ryan = await newRunner("Ryan");
  const maya = await newRunner("Maya");
  const sam = await newRunner("Sam");
  const jo = await newRunner("Jo");
  await profile(ryan, "Ryan");
  await profile(maya, "Maya", { color: 3 });
  await profile(sam, "Sam");
  await profile(jo, "Jo");
  for (const r of [maya, sam, jo]) await befriend(ryan, r);
  const post = await syncShow(ryan);
  return { ryan, maya, sam, jo, post };
}

describe("Seen by", () => {
  it("records Crew mates who saw your Show, once each, newest first", async () => {
    const { ryan, maya, sam, post } = await stage();
    expect((await seen(maya, post)).status).toBe(204);
    expect((await seen(maya, post)).status).toBe(204);
    expect((await seen(sam, post)).status).toBe(204);
    // Your own views aren't recorded.
    expect((await seen(ryan, post)).status).toBe(204);

    const a = await audience(ryan, post);
    expect(a.status).toBe(200);
    expect(a.body.seenBy.map((p: any) => p.stageName).sort()).toEqual(["Maya", "Sam"]);
    expect(a.body.seenBy.find((p: any) => p.stageName === "Maya")).toMatchObject({
      userId: maya.user.id, color: 3, avatarBadge: null, avatarUrl: null,
    });
    expect((await myPost(ryan, post)).seenBy.count).toBe(2);
    expect((await myPost(ryan, post)).seenBy.names.sort()).toEqual(["Maya", "Sam"]);
  });

  it("only the owner gets the list; Crew mates see seenBy null", async () => {
    const { maya, sam, post } = await stage();
    await seen(sam, post);
    const a = await audience(maya, post);
    expect(a.status).toBe(200);
    expect(a.body.seenBy).toBeNull();
    expect((await myPost(maya, post)).seenBy).toBeNull();
  });

  it("names at most three on the feed card", async () => {
    const { ryan, maya, sam, jo, post } = await stage();
    const kit = await newRunner("Kit");
    await profile(kit, "Kit");
    await befriend(ryan, kit);
    for (const r of [maya, sam, jo, kit]) await seen(r, post);
    const s = (await myPost(ryan, post)).seenBy;
    expect(s.count).toBe(4);
    expect(s.names).toHaveLength(3);
  });

  it("strangers can't mark or read a Show", async () => {
    const { post } = await stage();
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");
    expect((await seen(stranger, post)).status).toBe(404);
    expect((await audience(stranger, post)).status).toBe(404);
    expect((await call("PUT", `/api/crew/posts/${post}/seen`)).status).toBe(401);
  });

  it("the switch off stops recording and forgets past views", async () => {
    const { ryan, maya, sam, post } = await stage();
    await seen(maya, post);
    const p = await profile(maya, "Maya", { shareViews: false });
    expect(p.shareViews).toBe(false);
    expect(await count("SELECT count(*) AS n FROM crew_show_views WHERE user_id = ?", maya.user.id)).toBe(0);
    await seen(maya, post);
    await seen(sam, post);
    expect((await audience(ryan, post)).body.seenBy.map((x: any) => x.stageName)).toEqual(["Sam"]);
    // Leaving it out of a later save keeps it off (older app builds).
    expect((await profile(maya, "Maya")).shareViews).toBe(false);
    expect((await profile(maya, "Maya", { shareViews: true })).shareViews).toBe(true);
  });

  it("drops runners who left the Crew or were blocked", async () => {
    const { ryan, maya, sam, post } = await stage();
    await seen(maya, post);
    await seen(sam, post);
    await call("DELETE", `/api/crew/mates/${maya.user.id}`, { token: ryan.token });
    await call("POST", "/api/crew/blocks", { token: ryan.token, body: { userId: sam.user.id } });
    expect((await audience(ryan, post)).body.seenBy).toEqual([]);
    expect((await myPost(ryan, post)).seenBy).toEqual({ count: 0, names: [] });
  });
});

describe("who gave Encores", () => {
  it("names Encores from you and your Crew, counts the rest", async () => {
    const { ryan, maya, sam, post } = await stage();
    // Sam is in Ryan's Crew but not Maya's.
    for (const r of [maya, sam]) {
      expect((await call("PUT", `/api/crew/posts/${post}/encore`, { token: r.token })).status).toBe(204);
    }
    const owner = (await audience(ryan, post)).body;
    expect(owner.encores.map((p: any) => p.stageName).sort()).toEqual(["Maya", "Sam"]);
    expect(owner.otherEncores).toBe(0);

    const mates = (await audience(maya, post)).body;
    expect(mates.encores.map((p: any) => p.stageName)).toEqual(["Maya"]);
    expect(mates.otherEncores).toBe(1);
  });
});

const shout = (r: Runner, post: string, body: unknown) =>
  callJson("POST", `/api/crew/posts/${post}/shoutouts`, { token: r.token, body: { body } });
const shoutouts = async (r: Runner, post: string) => {
  const res = await callJson("GET", `/api/crew/posts/${post}/shoutouts`, { token: r.token });
  expect(res.status).toBe(200);
  return res.body.shoutouts as any[];
};

describe("Shout-outs", () => {
  it("the owner and their Crew post, oldest first, counted on the feed", async () => {
    const { ryan, maya, sam, post } = await stage();
    const a = await shout(maya, post, "  Huge run!  ");
    expect(a.status).toBe(201);
    expect(a.body).toMatchObject({ body: "Huge run!", stageName: "Maya", mine: true, canDelete: true });
    await shout(ryan, post, "Thanks!");
    await shout(sam, post, "Legend");
    const list = await shoutouts(ryan, post);
    expect(list.map((s) => s.body)).toEqual(["Huge run!", "Thanks!", "Legend"]);
    // The owner can delete anyone's on their Show; others only their own.
    expect(list.every((s) => s.canDelete)).toBe(true);
    const mayaView = await shoutouts(maya, post);
    expect(mayaView.map((s) => s.canDelete)).toEqual([true, false, false]);
    // Sam isn't in Maya's Crew: named, but no photo address.
    expect(mayaView[2]).toMatchObject({ stageName: "Sam", avatarUrl: null });
    expect((await myPost(ryan, post)).shoutouts).toBe(3);
  });

  it("checks the length and who can post", async () => {
    const { maya, post } = await stage();
    expect((await shout(maya, post, "")).status).toBe(400);
    expect((await shout(maya, post, "x".repeat(281))).status).toBe(400);
    expect((await shout(maya, post, "🎸".repeat(280))).status).toBe(201);
    expect((await shout(maya, post, 42)).status).toBe(400);
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");
    expect((await shout(stranger, post, "hi")).status).toBe(404);
    expect((await callJson("GET", `/api/crew/posts/${post}/shoutouts`, { token: stranger.token })).status).toBe(404);
  });

  it("deletes: the writer and the owner, nobody else", async () => {
    const { ryan, maya, sam, post } = await stage();
    const a = (await shout(maya, post, "one")).body.id;
    const b = (await shout(maya, post, "two")).body.id;
    await call("DELETE", `/api/crew/shoutouts/${a}`, { token: sam.token });
    expect((await shoutouts(ryan, post))).toHaveLength(2);
    expect((await call("DELETE", `/api/crew/shoutouts/${a}`, { token: maya.token })).status).toBe(204);
    expect((await call("DELETE", `/api/crew/shoutouts/${b}`, { token: ryan.token })).status).toBe(204);
    expect(await shoutouts(ryan, post)).toEqual([]);
  });

  it("reports copy the text and hide it from the reporter", async () => {
    const { ryan, maya, sam, post } = await stage();
    const id = (await shout(sam, post, "rude words")).body.id;
    const r = await call("POST", `/api/crew/shoutouts/${id}/report`, { token: maya.token, body: { reason: "mean" } });
    expect(r.status).toBe(204);
    expect(await count(
      "SELECT count(*) AS n FROM crew_reports WHERE post_id = ? AND reported_user = ? AND json_extract(post_data, '$.body') = 'rude words'",
      `shoutout:${id}`, sam.user.id,
    )).toBe(1);
    expect(await shoutouts(maya, post)).toEqual([]);
    expect(await shoutouts(ryan, post)).toHaveLength(1);
    expect((await call("POST", `/api/crew/shoutouts/${id}/report`, { token: sam.token, body: { reason: "x" } })).status).toBe(400);
  });

  it("hides writers who left the owner's Crew or are blocked by the reader", async () => {
    const { ryan, maya, sam, jo, post } = await stage();
    await shout(maya, post, "from Maya");
    await shout(sam, post, "from Sam");
    await call("POST", "/api/crew/blocks", { token: jo.token, body: { userId: sam.user.id } });
    expect((await shoutouts(jo, post)).map((s) => s.body)).toEqual(["from Maya"]);
    await call("DELETE", `/api/crew/mates/${maya.user.id}`, { token: ryan.token });
    expect((await shoutouts(ryan, post)).map((s) => s.body)).toEqual(["from Sam"]);
  });

  it("limits Shout-outs per hour", async () => {
    const { maya, post } = await stage();
    for (let i = 0; i < 30; i++) expect((await shout(maya, post, `#${i}`)).status).toBe(201);
    const res = await shout(maya, post, "one more");
    expect(res.status).toBe(429);
  });
});
