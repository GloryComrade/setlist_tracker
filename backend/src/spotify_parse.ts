// Turns a Spotify Web API search response into the small shape the app reads.
// Ported from supabase/functions/spotify-search/parse.ts. Kept free of
// Worker APIs so it is easy to test.

export interface SongResult {
  title: string;
  artist: string;
  album: string | null;
  artworkUrl: string | null;
  spotifyUrl: string | null;
  durationMs: number | null;
}

interface SpotifyImage {
  url?: unknown;
  width?: unknown;
}

/** Largest image by width (Spotify usually lists it first, but not always). */
function largestImage(images: unknown): string | null {
  if (!Array.isArray(images)) return null;
  let best: { url: string; size: number } | null = null;
  for (const img of images as SpotifyImage[]) {
    if (!img || typeof img.url !== "string") continue;
    const size = typeof img.width === "number" ? img.width : 0;
    if (best === null || size > best.size) best = { url: img.url, size };
  }
  return best?.url ?? null;
}

export function parseSpotifyTracks(body: unknown): SongResult[] {
  const items = (body as any)?.tracks?.items;
  if (!Array.isArray(items)) return [];
  const out: SongResult[] = [];
  for (const t of items) {
    if (!t || typeof t.name !== "string") continue;
    const artists: string[] = Array.isArray(t.artists)
      ? t.artists
        .map((a: { name?: unknown }) => a?.name)
        .filter((n: unknown): n is string => typeof n === "string" && n !== "")
      : [];
    if (artists.length === 0) continue;
    out.push({
      title: t.name,
      artist: artists.join(", "),
      album: typeof t.album?.name === "string" ? t.album.name : null,
      artworkUrl: largestImage(t.album?.images),
      spotifyUrl: typeof t.external_urls?.spotify === "string"
        ? t.external_urls.spotify
        : null,
      durationMs: typeof t.duration_ms === "number" ? t.duration_ms : null,
    });
  }
  return out;
}

/** The `limit` to ask Spotify for: 1 to 25, default 25. */
export function clampLimit(raw: unknown): number {
  const n = typeof raw === "number" ? raw : parseInt(String(raw ?? ""), 10);
  if (!Number.isFinite(n)) return 25;
  return Math.min(25, Math.max(1, Math.trunc(n)));
}
