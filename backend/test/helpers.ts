// Test helpers. Users and sessions are made by calling the Worker's own
// functions directly; there is no HTTP backdoor.

import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { vi } from "vitest";
import { createSession, findOrCreateUser, type User } from "../src/auth";
import type { Env } from "../src/env";
import worker from "../src/index";

export const ORIGIN = "https://setlist.example.workers.dev";

export interface Runner {
  user: User;
  token: string;
  refreshToken: string;
}

let counter = 0;

/** A new Google user with a session. */
export async function newRunner(name = "Runner"): Promise<Runner> {
  const user = await findOrCreateUser(
    env.DB,
    "google",
    `sub-${crypto.randomUUID()}-${++counter}`,
    { name, email: `${name.toLowerCase().replace(/\W/g, "")}@example.com` },
  );
  const session = await createSession(env, user);
  return { user, token: session.accessToken, refreshToken: session.refreshToken };
}

export interface CallOptions {
  token?: string;
  body?: unknown;
  headers?: Record<string, string>;
  env?: Env;
}

/** Calls the Worker the way the app does. */
export async function call(
  method: string,
  path: string,
  opts: CallOptions = {},
): Promise<Response> {
  const headers = new Headers(opts.headers);
  if (opts.token) headers.set("Authorization", `Bearer ${opts.token}`);
  let body: BodyInit | undefined;
  if (opts.body !== undefined) {
    if (typeof opts.body === "string" || opts.body instanceof FormData) {
      body = opts.body;
    } else {
      body = JSON.stringify(opts.body);
      headers.set("Content-Type", "application/json");
    }
  }
  // Waits for background work (push notifications) before answering, so
  // tests can check what was sent.
  const ctx = createExecutionContext();
  const res = await worker.fetch(
    new Request(`${ORIGIN}${path}`, { method, headers, body, redirect: "manual" }),
    opts.env ?? env,
    ctx,
  );
  await waitOnExecutionContext(ctx);
  return res;
}

/** Calls and parses the JSON answer. */
export async function callJson<T = any>(
  method: string,
  path: string,
  opts: CallOptions = {},
): Promise<{ status: number; body: T }> {
  const res = await call(method, path, opts);
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

export type FetchHandler = (
  url: URL,
  init: RequestInit & { method: string },
) => Response | Promise<Response>;

/**
 * Replaces the global fetch (which the Worker's code uses for Google, Apple
 * and Spotify) and records every outbound call.
 */
export function mockFetch(handler: FetchHandler) {
  const calls: { url: URL; method: string; body: string | null }[] = [];
  vi.stubGlobal(
    "fetch",
    async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const req = new Request(input, init);
      const url = new URL(req.url);
      const body = req.body
        ? new TextDecoder().decode(await req.arrayBuffer())
        : null;
      calls.push({ url, method: req.method, body });
      return handler(url, {
        ...init,
        method: req.method,
        body,
        headers: req.headers,
      });
    },
  );
  return calls;
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function count(sql: string, ...params: unknown[]): Promise<number> {
  const row = await env.DB.prepare(sql).bind(...params).first<{ n: number }>();
  return row?.n ?? 0;
}
