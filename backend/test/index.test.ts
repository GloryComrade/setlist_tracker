import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import type { Env } from "../src/env";
import worker from "../src/index";
import { callJson, newRunner, ORIGIN } from "./helpers";

describe("routing", () => {
  it("unknown API paths are 404 not_found JSON", async () => {
    const res = await callJson("GET", "/api/nothing/here");
    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: "not_found", message: expect.any(String) });
    const r = await newRunner();
    expect((await callJson("GET", "/api/crew/nope", { token: r.token })).status).toBe(404);
    expect((await callJson("PATCH", "/api/me", { token: r.token })).status).toBe(404);
  });

  it("everything outside /api goes to the website's assets", async () => {
    const seen: string[] = [];
    const assets = {
      fetch: async (req: Request) => {
        seen.push(new URL(req.url).pathname);
        return new Response("<html>", { headers: { "Content-Type": "text/html" } });
      },
    } as unknown as Fetcher;
    const testEnv = { ...env, ASSETS: assets } as Env;
    for (const path of ["/", "/crew", "/apiary"]) {
      const res = await worker.fetch(new Request(`${ORIGIN}${path}`), testEnv);
      expect(await res.text()).toBe("<html>");
    }
    expect(seen).toEqual(["/", "/crew", "/apiary"]);
  });

  it("bad JSON is a 400", async () => {
    const r = await newRunner();
    const res = await callJson("PUT", "/api/crew/profile", { token: r.token, body: "{not json" });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe("bad_request");
  });
});
