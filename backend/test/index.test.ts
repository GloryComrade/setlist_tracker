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

  it("plain http is sent to https, keeping the path and query", async () => {
    const http = ORIGIN.replace("https://", "http://");
    for (const path of ["/", "/api/auth/google/start?return=x", "/api/auth/apple/callback"]) {
      const res = await worker.fetch(new Request(`${http}${path}`, { method: "GET" }), env as Env);
      expect(res.status).toBe(308);
      expect(res.headers.get("Location")).toBe(`${ORIGIN}${path}`);
    }
  });

  it("an http page visit goes to https before the website's assets", async () => {
    let assetCalls = 0;
    const assets = {
      fetch: async () => {
        assetCalls++;
        return new Response("<html>");
      },
    } as unknown as Fetcher;
    const http = ORIGIN.replace("https://", "http://");
    const res = await worker.fetch(new Request(`${http}/crew?x=1`), { ...env, ASSETS: assets } as Env);
    expect(res.status).toBe(308);
    expect(res.headers.get("Location")).toBe(`${ORIGIN}/crew?x=1`);
    expect(assetCalls).toBe(0);
  });

  it("a sign-in started from an http page comes back to the https page", async () => {
    const http = ORIGIN.replace("https://", "http://");
    const ret = encodeURIComponent(`${http}/#/backstage`);
    const res = await worker.fetch(new Request(`${http}/api/auth/google/start?return=${ret}`), env as Env);
    expect(res.status).toBe(308);
    const loc = new URL(res.headers.get("Location")!);
    expect(loc.origin).toBe(ORIGIN);
    expect(loc.searchParams.get("return")).toBe(`${ORIGIN}/#/backstage`);
    const next = await worker.fetch(new Request(loc.toString(), { redirect: "manual" }), env as Env);
    expect(next.headers.get("Location")).toMatch(/^https:\/\/accounts\.google\.com\//);
  });

  it("an off-site http return address is left alone", async () => {
    const http = ORIGIN.replace("https://", "http://");
    const ret = encodeURIComponent("http://evil.example/");
    const res = await worker.fetch(new Request(`${http}/api/auth/google/start?return=${ret}`), env as Env);
    expect(new URL(res.headers.get("Location")!).searchParams.get("return")).toBe("http://evil.example/");
  });

  it("local http (wrangler dev) is not redirected", async () => {
    const res = await worker.fetch(
      new Request("http://localhost:8787/api/nothing"),
      env as Env,
    );
    expect(res.status).toBe(404);
  });

  it("bad JSON is a 400", async () => {
    const r = await newRunner();
    const res = await callJson("PUT", "/api/crew/profile", { token: r.token, body: "{not json" });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe("bad_request");
  });
});
