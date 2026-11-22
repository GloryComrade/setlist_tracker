import { describe, expect, it } from "vitest";
import { call, callJson, count, newRunner, type Runner } from "./helpers";

const DAY_MS = 86400_000;

/** "YYYY-MM-DD", [days] from today (UTC). */
function day(days: number): string {
  return new Date(Date.now() + days * DAY_MS).toISOString().slice(0, 10);
}

function rid(name: string): string {
  return `${name}-${crypto.randomUUID().slice(0, 8)}`;
}

async function profile(r: Runner, stageName: string, color = 1) {
  const res = await call("PUT", "/api/crew/profile", {
    token: r.token,
    body: { stageName, color },
  });
  expect(res.status).toBe(200);
}

async function befriend(a: Runner, b: Runner) {
  const code = (await callJson("POST", "/api/crew/invite", { token: a.token })).body.code;
  expect((await call("POST", "/api/crew/join", { token: b.token, body: { code } })).status).toBe(200);
}

/** Syncs a Tour for [r] and returns its id. */
async function bookTour(
  r: Runner,
  setup: Record<string, unknown>,
  opts: { id?: string; name?: string; deleted?: boolean } = {},
) {
  const id = opts.id ?? rid("tour");
  const res = await call("POST", "/api/sync/tours", {
    token: r.token,
    body: {
      rows: [
        {
          id,
          data: {
            schemaVersion: 1,
            id,
            name: opts.name ?? "Spring 2027 Half Tour",
            setup: { goal: "finish", ...setup },
            weeks: [],
          },
          updatedAt: new Date().toISOString(),
          deletedAt: opts.deleted ? new Date().toISOString() : null,
        },
      ],
    },
  });
  expect(res.status).toBe(200);
  return id;
}

function send(r: Runner, tourId: string, to: unknown) {
  return callJson("POST", "/api/crew/tour-invites", { token: r.token, body: { tourId, to } });
}

async function invites(r: Runner) {
  const res = await callJson("GET", "/api/crew/tour-invites", { token: r.token });
  expect(res.status).toBe(200);
  return res.body.invites as any[];
}

/** Ryan with Maya and Jordan in his Crew, and a Half on Opening Night. */
async function setup() {
  const ryan = await newRunner("Ryan");
  const maya = await newRunner("Maya");
  const jordan = await newRunner("Jordan");
  await profile(ryan, "Ryan", 2);
  await profile(maya, "Maya");
  await profile(jordan, "Jordan");
  await befriend(ryan, maya);
  await befriend(ryan, jordan);
  const tourId = await bookTour(ryan, { raceDate: day(90), raceDistance: "half" });
  return { ryan, maya, jordan, tourId };
}

describe("tour invites", () => {
  it("invites Crew mates and lists the invite for them", async () => {
    const { ryan, maya, jordan, tourId } = await setup();
    const res = await send(ryan, tourId, [maya.user.id, jordan.user.id, maya.user.id]);
    expect(res.status).toBe(200);
    expect(res.body.invited.sort()).toEqual([maya.user.id, jordan.user.id].sort());

    const list = await invites(maya);
    expect(list).toHaveLength(1);
    expect(list[0]).toEqual({
      id: expect.any(String),
      from: { userId: ryan.user.id, stageName: "Ryan", color: 2 },
      tourId,
      tourName: "Spring 2027 Half Tour",
      raceDate: day(90),
      raceDistance: "half",
      createdAt: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/),
    });
    expect(await invites(ryan)).toEqual([]);
  });

  it("copies the race onto the invite, and shows the Tour's latest version", async () => {
    const { ryan, maya, tourId } = await setup();
    await send(ryan, tourId, [maya.user.id]);
    expect(
      await count(
        "SELECT count(*) AS n FROM crew_tour_invites WHERE tour_id = ? AND race_date = ? AND race_distance = 'half'",
        tourId,
        day(90),
      ),
    ).toBe(1);
    await bookTour(ryan, { raceDate: day(97), raceDistance: "marathon" }, { id: tourId, name: "Boston Tour" });
    const [inv] = await invites(maya);
    expect(inv).toMatchObject({ tourName: "Boston Tour", raceDate: day(97), raceDistance: "marathon" });
  });

  it("skips runners outside the Crew and blocked runners", async () => {
    const { ryan, maya, jordan, tourId } = await setup();
    const stranger = await newRunner("Stranger");
    await profile(stranger, "Stranger");
    await call("POST", "/api/crew/blocks", { token: jordan.token, body: { userId: ryan.user.id } });
    const res = await send(ryan, tourId, [maya.user.id, jordan.user.id, stranger.user.id, ryan.user.id]);
    expect(res.status).toBe(200);
    expect(res.body.invited).toEqual([maya.user.id]);
    expect(await invites(jordan)).toEqual([]);
    expect(await invites(stranger)).toEqual([]);
  });

  it("only sends your own synced, upcoming Tours", async () => {
    const { ryan, maya, tourId } = await setup();
    // Maya can't invite onto Ryan's Tour.
    expect((await send(maya, tourId, [ryan.user.id])).status).toBe(404);
    // A Tour that isn't synced yet.
    const missing = await send(ryan, "not-synced", [maya.user.id]);
    expect(missing.status).toBe(404);
    expect(missing.body.error).toBe("not_found");
    // Deleted, or already raced.
    const gone = await bookTour(ryan, { raceDate: day(60) }, { deleted: true });
    expect((await send(ryan, gone, [maya.user.id])).status).toBe(404);
    const past = await bookTour(ryan, { raceDate: day(-1) });
    expect((await send(ryan, past, [maya.user.id])).status).toBe(400);
    expect(await invites(maya)).toEqual([]);
  });

  it("validates the body and needs a stage name", async () => {
    const { ryan, maya, tourId } = await setup();
    for (const body of [
      {},
      { tourId, to: "x" },
      { tourId, to: [] },
      { tourId: 5, to: [maya.user.id] },
      { tourId, to: [5] },
      { tourId, to: Array.from({ length: 51 }, (_, i) => `u${i}`) },
    ]) {
      const res = await callJson("POST", "/api/crew/tour-invites", { token: ryan.token, body });
      expect(res.status, JSON.stringify(body).slice(0, 60)).toBe(400);
    }
    const nobody = await newRunner("Nobody");
    expect((await send(nobody, tourId, [maya.user.id])).body.error).toBe("need_stage_name");
    expect((await call("GET", "/api/crew/tour-invites")).status).toBe(401);
  });

  it("hides invites once Opening Night passes, the Tour is deleted, or the Crew splits", async () => {
    const { ryan, maya, jordan, tourId } = await setup();
    await send(ryan, tourId, [maya.user.id, jordan.user.id]);
    expect(await invites(maya)).toHaveLength(1);

    // Race date moved into the past.
    await bookTour(ryan, { raceDate: day(-2), raceDistance: "half" }, { id: tourId });
    expect(await invites(maya)).toEqual([]);
    await bookTour(ryan, { raceDate: day(90), raceDistance: "half" }, { id: tourId });
    expect(await invites(maya)).toHaveLength(1);

    // Jordan leaves Ryan's Crew.
    await call("DELETE", `/api/crew/mates/${ryan.user.id}`, { token: jordan.token });
    expect(await invites(jordan)).toEqual([]);

    // Ryan cancels The Tour.
    await bookTour(ryan, { raceDate: day(90) }, { id: tourId, deleted: true });
    expect(await invites(maya)).toEqual([]);
  });

  it("lists the soonest Opening Night first", async () => {
    const { ryan, maya, tourId } = await setup();
    const sooner = await bookTour(ryan, { raceDate: day(20), raceDistance: "fiveK" }, { name: "Turkey Trot" });
    await send(ryan, tourId, [maya.user.id]);
    await send(ryan, sooner, [maya.user.id]);
    expect((await invites(maya)).map((i) => i.tourName)).toEqual(["Turkey Trot", "Spring 2027 Half Tour"]);
  });

  it("dismisses for the recipient only, and stays dismissed", async () => {
    const { ryan, maya, jordan, tourId } = await setup();
    await send(ryan, tourId, [maya.user.id, jordan.user.id]);
    const [inv] = await invites(maya);

    expect((await call("DELETE", `/api/crew/tour-invites/${inv.id}`, { token: ryan.token })).status).toBe(404);
    expect((await call("DELETE", `/api/crew/tour-invites/${inv.id}`, { token: jordan.token })).status).toBe(404);
    expect(await invites(maya)).toHaveLength(1);

    expect((await call("DELETE", `/api/crew/tour-invites/${inv.id}`, { token: maya.token })).status).toBe(204);
    expect((await call("DELETE", `/api/crew/tour-invites/${inv.id}`, { token: maya.token })).status).toBe(204);
    expect(await invites(maya)).toEqual([]);
    expect(await invites(jordan)).toHaveLength(1);

    // Asking again doesn't bring it back.
    expect((await send(ryan, tourId, [maya.user.id])).body.invited).toEqual([maya.user.id]);
    expect(await invites(maya)).toEqual([]);
    expect(await count("SELECT count(*) AS n FROM crew_tour_invites WHERE to_user = ?", maya.user.id)).toBe(1);
  });

  it("goes away with either runner's account", async () => {
    const { ryan, maya, tourId } = await setup();
    await send(ryan, tourId, [maya.user.id]);
    expect((await call("DELETE", "/api/me", { token: ryan.token })).status).toBe(204);
    expect(await count("SELECT count(*) AS n FROM crew_tour_invites WHERE to_user = ?", maya.user.id)).toBe(0);
  });
});
