import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/data/music/apple_preview.dart';
import 'package:setlist_tracker/data/music/music_search.dart';
import 'package:setlist_tracker/models/song.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/song_picker/song_picker_sheet.dart';

class _SpotifyOnly implements MusicSearch {
  @override
  Future<List<SongResult>> search(String query) async => const [
    SongResult(
      title: 'Mr. Brightside',
      artist: 'The Killers',
      album: 'Hot Fuss',
      spotifyUrl: 'https://open.spotify.com/track/abc',
      source: MusicSource.spotify,
    ),
  ];
}

/// Apple has nothing that matches.
class _NoApple implements MusicSearch {
  final queries = <String>[];
  @override
  Future<List<SongResult>> search(String query) async {
    queries.add(query);
    return const [];
  }
}

void main() {
  testWidgets('a Spotify pick keeps its Spotify link and asks Apple once', (
    tester,
  ) async {
    final apple = _NoApple();
    SongOfTheShow? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicSearchProvider.overrideWithValue(_SpotifyOnly()),
          previewLookupProvider.overrideWithValue(ApplePreviewLookup(apple)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => picked = await showSongPicker(
                  context,
                  initialQuery: 'brightside',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Mr. Brightside'), findsOneWidget);
    expect(find.text('Spotify'), findsOneWidget);

    await tester.tap(find.text('Mr. Brightside'));
    await tester.pumpAndSettle();

    expect(apple.queries, ['Mr. Brightside The Killers']);
    expect(picked?.title, 'Mr. Brightside');
    expect(picked?.spotifyUrl, 'https://open.spotify.com/track/abc');
    expect(picked?.previewUrl, isNull);
  });
}
