// Song search for the Song of the Show picker, backed by Spotify.
//
// Spotify's Web API needs a client secret, which must never ship in the app,
// so the app calls this route instead. It uses the Client Credentials flow
// (app-only: the runner never signs in to Spotify).
//
// GET /api/spotify/search?q=mr+brightside&limit=25
// -> {"results": [{title, artist, album, artworkUrl, spotifyUrl, durationMs}]}

import type { Env } from "./env";
import { ApiError, json } from "./http";
import { clampLimit, parseSpotifyTracks, type SongResult } from "./spotify_parse";

// The app token lives in module memory while this isolate stays warm.
let cachedToken: { value: string; expiresAt: number } | null = null;

/** For tests. */
export function resetSpotifyToken(): void {
  cachedToken = null;
}

async function appToken(env: Env): Promise<string> {
  const now = Date.now();
  if (cachedToken && now < cachedToken.expiresAt) return cachedToken.value;

  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${env.SPOTIFY_CLIENT_ID}:${env.SPOTIFY_CLIENT_SECRET}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) throw new Error(`Spotify token request failed (${res.status})`);
  const data = (await res.json()) as { access_token?: unknown; expires_in?: unknown };
  if (typeof data?.access_token !== "string") {
    throw new Error("Spotify token response had no access_token");
  }
  const ttlSeconds = typeof data.expires_in === "number" ? data.expires_in : 3600;
  cachedToken = {
    value: data.access_token,
    // Renew a minute early so a token never expires mid-request.
    expiresAt: now + Math.max(0, ttlSeconds - 60) * 1000,
  };
  return cachedToken.value;
}

async function searchSpotify(
  env: Env,
  q: string,
  limit: number,
  retry = true,
): Promise<SongResult[]> {
  const url = new URL("https://api.spotify.com/v1/search");
  url.searchParams.set("q", q);
  url.searchParams.set("type", "track");
  url.searchParams.set("limit", String(limit));
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${await appToken(env)}` },
  });
  if (res.status === 401 && retry) {
    // Token revoked or expired early: get a fresh one, once.
    cachedToken = null;
    return searchSpotify(env, q, limit, false);
  }
  if (!res.ok) throw new Error(`Spotify search failed (${res.status})`);
  return parseSpotifyTracks(await res.json());
}

export async function spotifySearchRoute(
  request: Request,
  env: Env,
): Promise<Response> {
  if (!env.SPOTIFY_CLIENT_ID || !env.SPOTIFY_CLIENT_SECRET) {
    throw new ApiError("not_configured", "Spotify search isn't set up on this server.");
  }
  const params = new URL(request.url).searchParams;
  const q = (params.get("q") ?? "").trim();
  if (!q) throw new ApiError("bad_request", "Type a song or an artist to search.");
  try {
    return json({ results: await searchSpotify(env, q, clampLimit(params.get("limit"))) });
  } catch (e) {
    console.error(e);
    throw new ApiError("upstream", "Spotify search is unavailable right now.");
  }
}
