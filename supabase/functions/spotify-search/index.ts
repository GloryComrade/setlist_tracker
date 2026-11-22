// Song search for the Song of the Show picker, backed by Spotify.
//
// Spotify's Web API needs a client secret, which must never ship in the app,
// so the app calls this function instead. It uses the Client Credentials
// flow (app-only: the runner never signs in to Spotify).
//
// Secrets (Edge Functions > Secrets, or `supabase secrets set`):
//   SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET
//
// GET  /functions/v1/spotify-search?q=mr+brightside&limit=25
// POST /functions/v1/spotify-search  {"q": "mr brightside", "limit": 25}
// -> {"results": [{title, artist, album, artworkUrl, spotifyUrl, durationMs}]}
//
// Supabase's default JWT check stays on: callers send the project's
// publishable key or a signed-in user's token as the Authorization bearer.

import { clampLimit, parseSpotifyTracks } from "./parse.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// The app token lives in module memory while this instance stays warm.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function appToken(): Promise<string> {
  const now = Date.now();
  if (cachedToken && now < cachedToken.expiresAt) return cachedToken.value;

  const id = Deno.env.get("SPOTIFY_CLIENT_ID");
  const secret = Deno.env.get("SPOTIFY_CLIENT_SECRET");
  if (!id || !secret) throw new Error("Spotify secrets are not set");

  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${id}:${secret}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) throw new Error(`Spotify token request failed (${res.status})`);
  const data = await res.json();
  if (typeof data?.access_token !== "string") {
    throw new Error("Spotify token response had no access_token");
  }
  const ttlSeconds = typeof data.expires_in === "number"
    ? data.expires_in
    : 3600;
  cachedToken = {
    value: data.access_token,
    // Renew a minute early so a token never expires mid-request.
    expiresAt: now + Math.max(0, ttlSeconds - 60) * 1000,
  };
  return cachedToken.value;
}

async function searchSpotify(
  q: string,
  limit: number,
  retry = true,
): Promise<ReturnType<typeof parseSpotifyTracks>> {
  const url = new URL("https://api.spotify.com/v1/search");
  url.searchParams.set("q", q);
  url.searchParams.set("type", "track");
  url.searchParams.set("limit", String(limit));
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${await appToken()}` },
  });
  if (res.status === 401 && retry) {
    // Token revoked or expired early: get a fresh one, once.
    cachedToken = null;
    return searchSpotify(q, limit, false);
  }
  if (!res.ok) throw new Error(`Spotify search failed (${res.status})`);
  return parseSpotifyTracks(await res.json());
}

async function readParams(
  req: Request,
): Promise<{ q: string; limit: unknown }> {
  const url = new URL(req.url);
  let q = url.searchParams.get("q") ?? "";
  let limit: unknown = url.searchParams.get("limit");
  if (req.method === "POST") {
    try {
      const body = await req.json();
      if (typeof body?.q === "string") q = body.q;
      if (body?.limit !== undefined) limit = body.limit;
    } catch {
      // No JSON body: use the query string.
    }
  }
  return { q: q.trim(), limit };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET" && req.method !== "POST") {
    return json({ error: "Use GET or POST" }, 405);
  }
  const { q, limit } = await readParams(req);
  if (!q) return json({ error: "Missing search text (q)" }, 400);
  try {
    return json({ results: await searchSpotify(q, clampLimit(limit)) });
  } catch (e) {
    console.error(e);
    return json({ error: "Spotify search is unavailable right now" }, 502);
  }
});
