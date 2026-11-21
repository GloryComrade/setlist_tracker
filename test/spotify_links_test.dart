import 'package:flutter_test/flutter_test.dart';
import 'package:setlist_tracker/logic/spotify_links.dart';

void main() {
  test('search link encodes title and artist', () {
    expect(
      spotifySearchUri('Mr. Brightside', 'The Killers').toString(),
      'https://open.spotify.com/search/Mr.%20Brightside%20The%20Killers',
    );
  });

  test('accepts copied song links and strips tracking', () {
    const id = '003vvx7Niy0yvhvHt4a68B';
    const clean = 'https://open.spotify.com/track/$id';
    expect(
      normalizeSpotifyTrackLink('https://open.spotify.com/track/$id?si=abc123'),
      clean,
    );
    expect(
      normalizeSpotifyTrackLink('https://open.spotify.com/intl-de/track/$id'),
      clean,
    );
    expect(normalizeSpotifyTrackLink('spotify:track:$id'), clean);
  });

  test('rejects links that are not songs', () {
    expect(
      normalizeSpotifyTrackLink(
        'https://open.spotify.com/album/003vvx7Niy0yvhvHt4a68B',
      ),
      isNull,
    );
    expect(
      normalizeSpotifyTrackLink(
        'https://example.com/track/003vvx7Niy0yvhvHt4a68B',
      ),
      isNull,
    );
    expect(normalizeSpotifyTrackLink('hello'), isNull);
  });
}
