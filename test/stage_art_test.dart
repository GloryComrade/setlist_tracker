import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
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

    test('every print is bundled, 9:10 and only light black ink', () async {
      for (final p in StageArt.prints) {
        final data = await rootBundle.load(p.assetName);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 810, reason: p.assetName);
        expect(image.height, 900, reason: p.assetName);
        expect(image.width / image.height, StageArt.printAspect);
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        var maxAlpha = 0;
        var edgeInk = 0;
        for (var i = 0; i < rgba.length; i += 4) {
          // Black ink only: the alpha is the screen, and the poster prints
          // it in its venue mark.
          expect(rgba[i] | rgba[i + 1] | rgba[i + 2], 0, reason: p.assetName);
          if (rgba[i + 3] > maxAlpha) maxAlpha = rgba[i + 3];
          if ((i ~/ 4) % image.width == 0) edgeInk += rgba[i + 3];
        }
        // One screen of ink at 40% at most, even where strokes cross.
        expect(maxAlpha, lessThanOrEqualTo(102), reason: p.assetName);
        // The left edge, where the print meets the type, is soft: no ink.
        expect(edgeInk, 0, reason: p.assetName);
        image.dispose();
      }
    });

    // The Show page poster's type, at the longest values it shows.
    Widget showPoster(Venue venue, double textScale) => MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: _wrap(
        // In a scroll view on the Show page: the poster sizes to its type.
        SingleChildScrollView(
          child: PosterHeader(
            title: '26.2 mi',
            mark: markFor(venue),
            venuePrint: StageArt.printFor(venue),
            children: [
              const Text(
                '10:42 /mi  ·  4:40:12',
                style: TextStyle(
                  fontFamily: StageFonts.display,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sun, Nov 22, 2026 · 6:30 AM',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(children: [VenueBadge(venue)]),
            ],
          ),
        ),
      ),
    );

    Future<void> loadFonts() async {
      for (final (family, files) in const [
        ('ArchivoCondensed', ['Archivo-ExtraCondensedBlack.ttf']),
        (
          'Archivo',
          [
            'Archivo-400.ttf',
            'Archivo-600.ttf',
            'Archivo-700.ttf',
            'Archivo-800.ttf',
          ],
        ),
      ]) {
        final loader = FontLoader(family);
        for (final f in files) {
          loader.addFont(rootBundle.load('assets/fonts/$f'));
        }
        await loader.load();
      }
    }

    for (final venue in Venue.values) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets('the ${venue.name} print never sits under type at '
            '${(scale * 100).round()}% text', (tester) async {
          await tester.runAsync(loadFonts);
          await tester.pumpWidget(showPoster(venue, scale));
          await tester.pump();
          final beside = tester.renderObject<RenderPrintBeside>(
            find.byType(PrintBeside),
          );
          final printRect = beside.printRect;
          if (scale == 1.0) {
            expect(printRect, isNotNull, reason: 'shows at 100% text');
            expect(printRect!.width, greaterThan(90));
          }
          if (printRect == null) return;
          // Every line of type and every pill, against the print's box.
          final origin = beside.localToGlobal(Offset.zero);
          final ink = printRect.shift(origin);
          for (final e
              in find
                  .descendant(
                    of: find.byType(PrintBeside),
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is RichText || w is DecoratedBox || w is Container,
                    ),
                  )
                  .evaluate()) {
            final r = e.renderObject;
            if (r is RenderParagraph) {
              final boxes = r.getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: r.text.toPlainText().length,
                ),
              );
              for (final b in boxes) {
                final rect = MatrixUtils.transformRect(
                  r.getTransformTo(null),
                  b.toRect(),
                );
                expect(
                  rect.right,
                  lessThanOrEqualTo(ink.left),
                  reason: '"${r.text.toPlainText()}" runs under the print',
                );
              }
            } else if (r is RenderDecoratedBox && r.hasSize) {
              final rect = MatrixUtils.transformRect(
                r.getTransformTo(null),
                Offset.zero & r.size,
              );
              // The poster's own box spans everything; skip it.
              if (rect.width >= 300) continue;
              expect(rect.right, lessThanOrEqualTo(ink.left));
            }
          }
        });
      }
    }

    testWidgets('the grain covers the poster whatever the child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PosterSurface(
            mark: StageColors.liveMark,
            venuePrint: StageArt.livePrint,
            child: const Text('5 mi'),
          ),
        ),
      );
      final paint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GrainPainter,
      );
      expect(tester.getSize(paint).width, 358);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is HalftonePainter,
        ),
        findsNothing,
      );
    });

    testWidgets('a poster paints a print only when given one, in its mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PosterSurface(child: Text('THE SETLIST'))),
      );
      expect(find.byType(Image), findsNothing);

      for (final venue in Venue.values) {
        await tester.pumpWidget(
          _wrap(
            PosterHeader(
              title: '15 mi',
              mark: markFor(venue),
              venuePrint: StageArt.printFor(venue),
            ),
          ),
        );
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, StageArt.printFor(venue));
        expect(image.excludeFromSemantics, isTrue);
        // Recolored to the venue mark, never the black ink on the dark stage.
        expect(image.colorBlendMode, BlendMode.srcIn);
        expect(
          image.color,
          markFor(venue).withValues(alpha: PosterSurface.printStrength),
        );
      }
    });

    testWidgets('only the Gold Records foil keeps a halftone', (tester) async {
      await tester.pumpWidget(
        _wrap(const PosterSurface.foil(child: Text('GOLD RECORDS'))),
      );
      final halftone = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is HalftonePainter,
        ),
      );
      expect((halftone.painter! as HalftonePainter).ink, StageColors.goldDeep);
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PosterSurface),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((box.decoration! as BoxDecoration).color, StageColors.goldMid);
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

    testWidgets('sleeves of one size set their titles at one size', (
      tester,
    ) async {
      double sizeOf(String title) {
        final text = tester.widget<Text>(find.text(title.toUpperCase()));
        return text.style!.fontSize!;
      }

      final sizes = <double>[];
      for (final (t, a) in _seedSongs) {
        await tester.pumpWidget(
          _wrap(
            Center(
              child: SizedBox.square(
                dimension: 115,
                child: SongSleeve(title: t, artist: a),
              ),
            ),
          ),
        );
        sizes.add(sizeOf(t));
      }
      expect(sizes.toSet(), {SongSleeve.titleSizeFor(115)});
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
      expect(find.byType(SongSleeve), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SongSleeve),
          matching: find.byType(Text),
        ),
        findsNothing,
        reason: 'small: the print alone, no letter that reads as an avatar',
      );
    });

    testWidgets('a slot with the title beside it leaves it off the sleeve', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AlbumArt(
            url: null,
            size: 96,
            title: 'Run',
            artist: 'X',
            printTitle: false,
          ),
        ),
      );
      expect(find.byType(SongSleeve), findsOneWidget);
      expect(find.text('RUN'), findsNothing);
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
