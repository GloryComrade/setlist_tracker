import { env } from "cloudflare:workers";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { resetSpotifyToken } from "../src/spotify";
import { clampLimit, parseSpotifyTracks } from "../src/spotify_parse";
import { callJson, jsonResponse, mockFetch } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
  resetSpotifyToken();
});

// Ported from supabase/functions/spotify-search/parse_test.ts.
describe("parseSpotifyTracks", () => {
  it("parses tracks, joins artists, picks the largest cover", () => {
    const body = {
      tracks: {
        items: [
          {
            name: "Mr. Brightside",
            artists: [{ name: "The Killers" }],
            album: {
              name: "Hot Fuss",
              images: [
                { url: "small", width: 64 },
                { url: "big", width: 640 },
                { url: "mid", width: 300 },
              ],
            },
            external_urls: { spotify: "https://open.spotify.com/track/abc" },
            duration_ms: 222973,
          },
          {
            name: "Under Pressure",
            artists: [{ name: "Queen" }, { name: "David Bowie" }],
            album: { name: "Hot Space", images: [] },
            external_urls: {},
          },
          { name: "No artists", artists: [] },
          { artists: [{ name: "No title" }] },
        ],
      },
    };
    expect(parseSpotifyTracks(body)).toEqual([
      {
        title: "Mr. Brightside",
        artist: "The Killers",
        album: "Hot Fuss",
        artworkUrl: "big",
        spotifyUrl: "https://open.spotify.com/track/abc",
        durationMs: 222973,
      },
      {
        title: "Under Pressure",
        artist: "Queen, David Bowie",
        album: "Hot Space",
        artworkUrl: null,
        spotifyUrl: null,
        durationMs: null,
      },
    ]);
  });

  it("bad bodies give no results", () => {
    expect(parseSpotifyTracks(null)).toEqual([]);
    expect(parseSpotifyTracks({ tracks: {} })).toEqual([]);
  });

  it("limit is clamped to 1..25", () => {
    expect(clampLimit(null)).toBe(25);
    expect(clampLimit("10")).toBe(10);
    expect(clampLimit(99)).toBe(25);
    expect(clampLimit("0")).toBe(1);
    expect(clampLimit("abc")).toBe(25);
  });
});

const withSpotify = {
  ...env,
  SPOTIFY_CLIENT_ID: "spotify-id",
  SPOTIFY_CLIENT_SECRET: "spotify-secret",
} as Env;

const TRACKS = {
  tracks: {
    items: [{ name: "Run", artists: [{ name: "Snow Patrol" }], album: { name: "Final Straw", images: [] } }],
  },
};

describe("GET /api/spotify/search", () => {
  it("is 503 not_configured without secrets", async () => {
    const calls = mockFetch(() => jsonResponse({}, 500));
    const res = await callJson("GET", "/api/spotify/search?q=run");
    expect(res.status).toBe(503);
    expect(res.body.error).toBe("not_configured");
    expect(calls).toHaveLength(0);
  });

  it("needs no sign-in, caches the app token, and passes the limit", async () => {
    const calls = mockFetch((url) => {
      if (url.href === "https://accounts.spotify.com/api/token") {
        return jsonResponse({ access_token: "app-token", expires_in: 3600 });
      }
      if (url.pathname === "/v1/search") return jsonResponse(TRACKS);
      return jsonResponse({}, 500);
    });
    const a = await callJson("GET", "/api/spotify/search?q=run&limit=5", { env: withSpotify });
    expect(a.status).toBe(200);
    expect(a.body.results).toEqual([
      { title: "Run", artist: "Snow Patrol", album: "Final Straw", artworkUrl: null, spotifyUrl: null, durationMs: null },
    ]);
    await callJson("GET", "/api/spotify/search?q=run", { env: withSpotify });
    expect(calls.filter((c) => c.url.hostname === "accounts.spotify.com")).toHaveLength(1);
    const searches = calls.filter((c) => c.url.pathname === "/v1/search");
    expect(searches[0].url.searchParams.get("limit")).toBe("5");
    expect(searches[0].url.searchParams.get("type")).toBe("track");
    expect(searches[1].url.searchParams.get("limit")).toBe("25");
  });

  it("gets a fresh token once after a 401", async () => {
    let tokens = 0;
    let searches = 0;
    mockFetch((url) => {
      if (url.hostname === "accounts.spotify.com") {
        return jsonResponse({ access_token: `t${++tokens}`, expires_in: 3600 });
      }
      return ++searches === 1 ? jsonResponse({}, 401) : jsonResponse(TRACKS);
    });
    const res = await callJson("GET", "/api/spotify/search?q=run", { env: withSpotify });
    expect(res.status).toBe(200);
    expect(tokens).toBe(2);
  });

  it("is 400 without q and 502 when Spotify fails", async () => {
    expect((await callJson("GET", "/api/spotify/search?q=%20", { env: withSpotify })).body.error).toBe("bad_request");
    mockFetch(() => jsonResponse({}, 500));
    const res = await callJson("GET", "/api/spotify/search?q=run", { env: withSpotify });
    expect(res.status).toBe(502);
    expect(res.body.error).toBe("upstream");
  });
});
