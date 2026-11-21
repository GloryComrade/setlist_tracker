/// Spotify links without the Spotify API.
///
/// v1 needs no account or API key: "Find on Spotify" opens Spotify's search
/// for the song, and a pasted song link is saved on the Show. The v2 music
/// search (album art, one-tap pick) needs the Spotify Web API and a small
/// server to hold the API secret, so it waits for accounts in Phase 5.
library;

/// Spotify search for "title artist". Opens the Spotify app on iPhone when
/// it's installed, otherwise the Spotify web player.
Uri spotifySearchUri(String title, String artist) {
  final query = [
    title.trim(),
    artist.trim(),
  ].where((s) => s.isNotEmpty).join(' ');
  return Uri(
    scheme: 'https',
    host: 'open.spotify.com',
    pathSegments: ['search', query],
  );
}

final _trackLink = RegExp(
  r'^https?://open\.spotify\.com/(?:intl-[a-z-]+/)?track/([A-Za-z0-9]{22})',
);
final _trackUri = RegExp(r'^spotify:track:([A-Za-z0-9]{22})$');

/// Turns a pasted Spotify song link (from Share → Copy Song Link, or a
/// spotify:track: URI) into a clean https link. Returns null if it isn't one.
String? normalizeSpotifyTrackLink(String input) {
  final text = input.trim();
  final match = _trackLink.firstMatch(text) ?? _trackUri.firstMatch(text);
  if (match == null) return null;
  return 'https://open.spotify.com/track/${match.group(1)}';
}
