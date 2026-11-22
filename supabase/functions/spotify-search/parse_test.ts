// Run with: deno test supabase/functions/spotify-search/
import { assertEquals } from "jsr:@std/assert@1";
import { clampLimit, parseSpotifyTracks } from "./parse.ts";

Deno.test("parses tracks, joins artists, picks the largest cover", () => {
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
  assertEquals(parseSpotifyTracks(body), [
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

Deno.test("bad bodies give no results", () => {
  assertEquals(parseSpotifyTracks(null), []);
  assertEquals(parseSpotifyTracks({ tracks: {} }), []);
});

Deno.test("limit is clamped to 1..25", () => {
  assertEquals(clampLimit(null), 25);
  assertEquals(clampLimit("10"), 10);
  assertEquals(clampLimit(99), 25);
  assertEquals(clampLimit("0"), 1);
  assertEquals(clampLimit("abc"), 25);
});
