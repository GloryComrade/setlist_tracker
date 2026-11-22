import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/theme/stage_art.dart';
import 'package:setlist_tracker/ui/widgets/album_art.dart';
import 'package:setlist_tracker/ui/widgets/song_sleeve.dart';
import 'package:setlist_tracker/ui/widgets/stage_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: Center(child: SizedBox(width: 358, child: child)),
  ),
);

const _seedSongs = [
  ('Midnight City', 'M83'),
  ('Dog Days Are Over', 'Florence + The Machine'),
  ('Lose Yourself', 'Eminem'),
  ('Mr. Brightside', 'The Killers'),
  ('Titanium', 'David Guetta, Sia'),
  ('Born to Run', 'Bruce Springsteen'),
  ('Levitating', 'Dua Lipa'),
  ('Run', 'Snow Patrol'),
];

final _warm = {StageColors.magentaDeep, StageColors.orangeDeep};
final _cool = {StageColors.violetDeep, StageColors.tealDeep};

void main() {
  group('venue prints', () {
    test('each venue has its own print', () {
      expect(StageArt.printFor(Venue.live), StageArt.livePrint);
      expect(StageArt.printFor(Venue.studio), StageArt.studioPrint);
      expect(StageArt.livePrint, isNot(StageArt.studioPrint));
    });

    test('every print is bundled, square and only dark ink', () async {
      for (final p in StageArt.prints) {
        final data = await rootBundle.load(p.assetName);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 1080, reason: p.assetName);
        expect(image.height, 1080, reason: p.assetName);
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        var maxAlpha = 0;
        for (var i = 0; i < rgba.length; i += 4) {
          // Black ink only: the print may darken the gradient, never lighten.
          expect(rgba[i] | rgba[i + 1] | rgba[i + 2], 0, reason: p.assetName);
          if (rgba[i + 3] > maxAlpha) maxAlpha = rgba[i + 3];
        }
        // Heaviest overprint stays well short of a black-out (about 60%).
        expect(maxAlpha, lessThan(160), reason: p.assetName);
        // The left 45% of the print, where the type sits, is clear.
        var leftInk = 0;
        for (var y = 0; y < 1080; y += 7) {
          for (var x = 0; x < 486; x += 3) {
            leftInk += rgba[(y * 1080 + x) * 4 + 3];
          }
        }
        expect(leftInk, 0, reason: p.assetName);
        image.dispose();
      }
    });

    testWidgets('a poster paints a print only when given one', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PosterSurface(
            gradient: StageColors.headlineGradient,
            child: Text('THE SETLIST'),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);

      await tester.pumpWidget(
        _wrap(
          PosterHeader(
            title: '15 mi',
            gradient: StageColors.liveGradient,
            venuePrint: StageArt.printFor(Venue.live),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, StageArt.livePrint);
      expect(image.excludeFromSemantics, isTrue);
    });
  });

  group('song sleeves', () {
    test('the same song always gets the same sleeve', () {
      expect(
        SleeveDesign.of('Lose Yourself', 'Eminem'),
        SleeveDesign.of('Lose Yourself', 'Eminem'),
      );
      // Case and stray spaces don't change it.
      expect(
        SleeveDesign.of(' lose yourself', 'EMINEM '),
        SleeveDesign.of('Lose Yourself', 'Eminem'),
      );
    });

    test('the hash is fixed, so sleeves match across devices and runs', () {
      // Reference values from a plain 32-bit FNV-1a with the same xorshift
      // finish (worked out in Python), so the split multiply matches.
      expect(SleeveDesign.fnv1a(''), 0x4622a677);
      expect(SleeveDesign.fnv1a('lose yourself|eminem'), 0x5bbf1900);
    });

    test('the seeded songs all get different sleeves', () {
      final designs = {for (final (t, a) in _seedSongs) SleeveDesign.of(t, a)};
      expect(designs, hasLength(_seedSongs.length));
    });

    test('every sleeve mixes one warm and one cool ink', () {
      for (var i = 0; i < 400; i++) {
        final d = SleeveDesign.of('Song $i', 'Artist ${i * 7}');
        final inks = {d.ground, d.ink};
        expect(inks.intersection(_warm), hasLength(1));
        expect(inks.intersection(_cool), hasLength(1));
      }
    });

    test('layouts and ink pairs spread across many songs', () {
      final layouts = <SleeveLayout, int>{};
      final grounds = <Color, int>{};
      for (var i = 0; i < 2000; i++) {
        final d = SleeveDesign.of('Track $i', 'Band ${i % 37}');
        layouts[d.layout] = (layouts[d.layout] ?? 0) + 1;
        grounds[d.ground] = (grounds[d.ground] ?? 0) + 1;
      }
      expect(layouts.keys, hasLength(SleeveLayout.values.length));
      for (final n in layouts.values) {
        expect(n, greaterThan(350));
      }
      expect(grounds.keys, hasLength(4));
    });

    testWidgets('sleeve type does not grow with text size', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _wrap(
            const SizedBox.square(
              dimension: 115,
              child: SongSleeve(title: 'Dog Days Are Over', artist: 'Florence'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.element(find.text('DOG DAYS ARE OVER'));
      expect(MediaQuery.textScalerOf(title), TextScaler.noScaling);
    });
  });

  group('AlbumArt', () {
    testWidgets('a song with no art gets its printed sleeve', (tester) async {
      await tester.pumpWidget(
        _wrap(const AlbumArt(url: null, size: 96, title: 'Run', artist: 'X')),
      );
      expect(find.byType(SongSleeve), findsOneWidget);
      expect(find.text('RUN'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(const AlbumArt(url: null, size: 36, title: 'Run', artist: 'X')),
      );
      expect(find.text('R'), findsOneWidget, reason: 'small: first letter');
    });

    testWidgets('no song: a quiet tile, never a sleeve', (tester) async {
      await tester.pumpWidget(_wrap(const AlbumArt(url: null, size: 52)));
      expect(find.byType(SongSleeve), findsNothing);
      expect(find.byIcon(Icons.album), findsOneWidget);
    });

    testWidgets('real art loads over a quiet tile, not a made-up cover', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AlbumArt(
            url: 'https://example.invalid/cover.jpg',
            size: 52,
            title: 'Run',
            artist: 'Snow Patrol',
          ),
        ),
      );
      expect(find.byType(SongSleeve), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.excludeFromSemantics, isTrue);
    });

    testWidgets('the art adds nothing for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const AlbumArt(url: null, size: 96, title: 'Run', artist: 'X')),
      );
      expect(find.bySemanticsLabel(RegExp('RUN')), findsNothing);
      expect(
        tester.getSemantics(find.byType(AlbumArt)),
        isNot(matchesSemantics(isImage: true)),
      );
      handle.dispose();
    });
  });
}
