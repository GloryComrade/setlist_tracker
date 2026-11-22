import { describe, expect, it } from "vitest";
import { call, callJson, newRunner } from "./helpers";

// Migration 0006: the demo "Review Crew" runner and its permanent code.
describe("Review Crew demo invite", () => {
  it("lets any runner join with TRYCREW2 and see the demo Shows", async () => {
    const reviewer = await newRunner("Reviewer");
    await call("PUT", "/api/crew/profile", { token: reviewer.token, body: { stageName: "App Review" } });

    const preview = await callJson("GET", "/api/crew/invite/trycrew-2", { token: reviewer.token });
    expect(preview.status).toBe(200);
    expect(preview.body.stageName).toBe("Review Crew");

    const join = await callJson("POST", "/api/crew/join", { token: reviewer.token, body: { code: "TRYCREW2" } });
    expect(join.status).toBe(200);

    const feed = await callJson("GET", "/api/crew/feed", { token: reviewer.token });
    const demo = feed.body.posts.filter((p: any) => p.ownerId === "review-crew");
    expect(demo.map((p: any) => p.showId)).toEqual([
      "review-crew-show-1",
      "review-crew-show-2",
      "review-crew-show-3",
    ]);
    expect(demo[0].stageName).toBe("Review Crew");
    expect(demo[0].shoutouts).toBe(1);
  });

  it("joins people to Review Crew only, not to each other", async () => {
    const a = await newRunner("A");
    const b = await newRunner("B");
    for (const r of [a, b]) {
      await call("PUT", "/api/crew/profile", { token: r.token, body: { stageName: r.user.name } });
      expect((await call("POST", "/api/crew/join", { token: r.token, body: { code: "TRYCREW2" } })).status).toBe(200);
    }
    const mates = await callJson("GET", "/api/crew/mates", { token: a.token });
    const ids = JSON.stringify(mates.body);
    expect(ids).toContain("review-crew");
    expect(ids).not.toContain(b.user.id);
  });
});
