import { describe, expect, it } from "vitest";
import { hasBlockedWords } from "../src/filter";
import { call, callJson, newRunner } from "./helpers";

describe("word filter", () => {
  it("catches blocked words, disguised or not", () => {
    for (const t of ["what the fuck", "FUUUCK yeah", "sh1t pace", "f u c k", "f.u.c.k", "you f@g", "motherfucker", "Fückïng hills"]) {
      expect(hasBlockedWords(t), t).toBe(true);
    }
  });

  it("lets ordinary running talk through", () => {
    for (const t of [
      "Ten along the river. Negative split the last three!",
      "Scunthorpe half marathon", "class of 2026", "Niger Delta 10K", "Cocktail after?",
      "Dickens Run 5K", "Shiitake tacos after", "a b c", "6 x 800 @ 5:40", "Assessment week",
      "Grape gels", "Therapist said rest", "Skyscraper hill repeats",
    ]) {
      expect(hasBlockedWords(t), t).toBe(false);
    }
  });

  it("rejects a blocked stage name and Shout-out", async () => {
    const r = await newRunner("Filter");
    const bad = await callJson("PUT", "/api/crew/profile", { token: r.token, body: { stageName: "B1tch Runner" } });
    expect(bad.status).toBe(400);
    expect((await call("PUT", "/api/crew/profile", { token: r.token, body: { stageName: "Hill Runner" } })).status).toBe(200);

    const code = (await callJson("POST", "/api/crew/invite", { token: r.token })).body.code;
    const mate = await newRunner("Mate");
    await call("PUT", "/api/crew/profile", { token: mate.token, body: { stageName: "Mate" } });
    expect((await call("POST", "/api/crew/join", { token: mate.token, body: { code } })).status).toBe(200);
    const id = "show-filter";
    await call("POST", "/api/sync/shows", {
      token: r.token,
      body: { rows: [{ id, data: { id, date: "2026-11-21T07:30:00.000", distanceMiles: 3 }, updatedAt: new Date().toISOString(), deletedAt: null }] },
    });
    const post = `${r.user.id}:${id}`;
    const no = await callJson("POST", `/api/crew/posts/${post}/shoutouts`, { token: mate.token, body: { body: "fuuuck that was fast" } });
    expect(no.status).toBe(400);
    expect(JSON.stringify(no.body)).toContain("doesn't allow");
    const yes = await call("POST", `/api/crew/posts/${post}/shoutouts`, { token: mate.token, body: { body: "Huge run!" } });
    expect(yes.status).toBe(201);
  });
});
