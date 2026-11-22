import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:setlist_tracker/models/enums.dart';
import 'package:setlist_tracker/theme/app_theme.dart';
import 'package:setlist_tracker/ui/widgets/stage_widgets.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Files under lib/ui and lib/theme allowed to build a gradient. Empty: the
/// app is flat. Add a path here only with a line in DESIGN.md saying why.
const _gradientAllowlist = <String>{};

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('no gradients under lib/ui or lib/theme', () {
    final gradient = RegExp(
      r'\b(Linear|Radial|Sweep)Gradient\b|\bgradient\s*:|\bGradientRotation\b',
    );
    final offenders = <String>[];
    for (final dir in ['lib/ui', 'lib/theme']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final path = f.path.replaceAll(r'\', '/');
        if (_gradientAllowlist.contains(path)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          // Doc comments may say "no gradients"; code may not use one.
          final code = lines[i].split('//').first;
          if (gradient.hasMatch(code)) offenders.add('$path:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  group('contrast (WCAG AA)', () {
    test('Gold Ink on amber and on the gold foil', () {
      expect(contrast(StageColors.goldInk, StageColors.amber), greaterThan(10));
      expect(
        contrast(StageColors.goldInk, StageColors.goldMid),
        greaterThan(11),
      );
      expect(
        contrast(StageColors.goldInk, StageColors.goldDeep),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('venue marks read as text on every stage surface', () {
      for (final mark in [StageColors.liveMark, StageColors.studioMark]) {
        for (final ground in [
          StageColors.background,
          StageColors.surface,
          StageColors.surfaceHigh,
        ]) {
          expect(contrast(mark, ground), greaterThanOrEqualTo(4.5));
        }
      }
    });

    test('amber, white and grey type on every stage surface', () {
      for (final ground in [
        StageColors.background,
        StageColors.surface,
        StageColors.surfaceHigh,
      ]) {
        expect(contrast(StageColors.amber, ground), greaterThanOrEqualTo(4.5));
        expect(contrast(StageColors.text, ground), greaterThanOrEqualTo(4.5));
        expect(
          contrast(StageColors.textMuted, ground),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('every Feel Face keeps its face at 3:1 or better', () {
      for (final feel in Feel.values) {
        final fill = FeelFace.fills[feel]!;
        expect(
          contrast(FeelFace.faceOn(feel), fill),
          greaterThanOrEqualTo(4.5),
          reason: feel.name,
        );
      }
      // One flat fill each, no two the same.
      expect(FeelFace.fills.values.toSet(), hasLength(Feel.values.length));
    });

    test('the selected tab icon on its amber pill', () {
      final pill = Color.alphaBlend(
        StageColors.amber.withValues(alpha: 0.3),
        StageColors.surface,
      );
      expect(contrast(StageColors.text, pill), greaterThanOrEqualTo(4.5));
    });
  });

  test('amber is the action color, magenta is only a venue mark', () {
    final scheme = AppTheme.dark().colorScheme;
    expect(scheme.primary, StageColors.amber);
    expect(scheme.onPrimary, StageColors.goldInk);
    expect(markFor(Venue.live), StageColors.liveMark);
    expect(markFor(Venue.studio), StageColors.studioMark);
  });

  testWidgets('the Stage Button is a flat amber pill with Gold Ink type', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(StageButton(label: 'Book a Show', onPressed: () {})),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(StageButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, StageColors.amber);
    final text = tester.widget<Text>(find.text('BOOK A SHOW'));
    expect(text.style?.color, StageColors.goldInk);
  });

  testWidgets('the Venue Badge is an outline in its mark, never a fill', (
    tester,
  ) async {
    for (final venue in Venue.values) {
      await tester.pumpWidget(_wrap(VenueBadge(venue)));
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(VenueBadge),
          matching: find.byType(Container),
        ),
      );
      final d = box.decoration! as BoxDecoration;
      expect(d.color, isNull);
      expect(d.gradient, isNull);
      expect((d.border! as Border).top.color, markFor(venue));
      final label = tester.widget<Text>(find.text(venue.label.toUpperCase()));
      expect(label.style?.color, markFor(venue));
    }
  });

  testWidgets('a poster is flat Stage Surface with an outline and grain', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(width: 358, child: PosterHeader(title: 'THE SETLIST')),
      ),
    );
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(PosterSurface),
            matching: find.byType(Container),
          )
          .first,
    );
    final d = box.decoration! as BoxDecoration;
    expect(d.color, StageColors.surface);
    expect(d.gradient, isNull);
    final outline = box.foregroundDecoration! as BoxDecoration;
    expect((outline.border! as Border).top.color, StageColors.outline);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GrainPainter,
      ),
      findsOneWidget,
    );
  });
}
