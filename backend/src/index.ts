// Setlist Tracker's Worker: the website (static assets) and the API under
// /api/*. The contract with the app is docs/cloudflare-api.md.

import { deleteAccount } from "./account";
import {
  exchangeLoginCode,
  refreshSession,
  requireUser,
  signOut,
} from "./auth";
import { crewRoute } from "./crew";
import type { Env } from "./env";
import {
  ApiError,
  corsHeaders,
  errorResponse,
  json,
  noContent,
  readJson,
  withCors,
} from "./http";
import { appleCallback, appleNative, googleCallback, startSignIn } from "./oauth";
import { spotifySearchRoute } from "./spotify";
import { pullRoute, pushRoute } from "./sync";

export type { Env };

function notFound(): ApiError {
  return new ApiError("not_found", "There's nothing backstage at that address.");
}

async function tokenField(request: Request, name: string): Promise<string> {
  const v = (await readJson(request))[name];
  if (typeof v !== "string" || !v) {
    throw new ApiError("bad_request", "That request didn't make sense.");
  }
  return v;
}

/** Routes one /api/* request. */
export async function handleApi(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const m = request.method;
  // "/api/crew/posts/x/encore" -> ["crew", "posts", "x", "encore"]
  let parts: string[];
  try {
    parts = url.pathname
      .replace(/^\/api\/?/, "")
      .split("/")
      .filter((p) => p !== "")
      .map(decodeURIComponent);
  } catch {
    throw notFound();
  }
  const [a, b, c] = parts;
  const n = parts.length;

  // ---- Sign-in ----
  if (a === "auth") {
    if ((b === "google" || b === "apple") && c === "start" && n === 3 && m === "GET") {
      return startSignIn(request, env, b);
    }
    if (b === "google" && c === "callback" && n === 3 && m === "GET") {
      return googleCallback(request, env);
    }
    if (b === "apple" && c === "callback" && n === 3 && m === "POST") {
      return appleCallback(request, env);
    }
    if (b === "apple" && c === "native" && n === 3 && m === "POST") {
      return appleNative(request, env);
    }
    if (n === 2 && m === "POST") {
      if (b === "exchange") {
        return json(await exchangeLoginCode(env, await tokenField(request, "code")));
      }
      if (b === "refresh") {
        return json(await refreshSession(env, await tokenField(request, "refreshToken")));
      }
      if (b === "signout") {
        await signOut(env, await tokenField(request, "refreshToken"));
        return noContent();
      }
    }
    throw notFound();
  }

  // ---- Spotify (no sign-in) ----
  if (a === "spotify" && b === "search" && n === 2 && m === "GET") {
    return spotifySearchRoute(request, env);
  }

  // ---- Everything else needs sign-in ----
  if (a === "me" && n === 1 && (m === "GET" || m === "DELETE")) {
    const user = await requireUser(request, env);
    if (m === "GET") return json(user);
    await deleteAccount(env, user.id);
    return noContent();
  }
  if (a === "sync" && n === 2 && (m === "GET" || m === "POST")) {
    const user = await requireUser(request, env);
    return m === "GET"
      ? pullRoute(request, env, user.id, b)
      : pushRoute(request, env, user.id, b);
  }
  if (a === "crew" && n >= 1) {
    const user = await requireUser(request, env);
    const res = await crewRoute(request, env, user.id, parts.slice(1));
    if (res) return res;
  }
  throw notFound();
}

function isLocalHost(host: string): boolean {
  return host === "localhost" || host === "127.0.0.1" || host === "[::1]";
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    // Someone who types http://setlisttracker.com would otherwise get a
    // "not secure" page, and sign-in would send Google and Apple an http://
    // callback they don't know (redirect_uri_mismatch). Send every plain-http
    // visit to the https address first. 308 keeps the method (Apple's POST).
    if (url.protocol === "http:" && !isLocalHost(url.hostname)) {
      url.protocol = "https:";
      return new Response(null, {
        status: 308,
        headers: { Location: url.toString() },
      });
    }
    if (url.pathname !== "/api" && !url.pathname.startsWith("/api/")) {
      return env.ASSETS.fetch(request);
    }
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }
    let response: Response;
    try {
      response = await handleApi(request, env);
    } catch (e) {
      if (e instanceof ApiError) {
        response = errorResponse(e);
      } else {
        console.error("unhandled error", e);
        response = errorResponse(
          new ApiError(
            "server_error",
            "Something went wrong backstage. Try again in a moment.",
          ),
        );
      }
    }
    return withCors(request, response);
  },
} satisfies ExportedHandler<Env>;
