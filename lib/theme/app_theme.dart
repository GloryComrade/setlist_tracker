import 'package:material_ui/material_ui.dart';

/// House Lights Down: a dark stage with the house lights off. Surfaces are
/// flat and high contrast, with a film grain instead of light; Marquee
/// [amber] is the one accent, and the venue marks ([liveMark],
/// [studioMark]) are only ever edges, outlines and small marks.
///
/// Fills that carry white text use the deeper "stage" shades so labels stay
/// readable (4.5:1 or better). The bright shades are for text and marks on the
/// dark background. There are no gradients anywhere in the app.
class StageColors {
  static const background = Color(0xFF0B0A12);
  static const surface = Color(0xFF16141F);
  static const surfaceHigh = Color(0xFF221F2E);
  static const outline = Color(0xFF3A3548);

  static const text = Color(0xFFF5F3FA);
  static const textMuted = Color(0xFFA8A3B8);

  /// Bright lights: text and marks on the dark stage.
  static const magenta = Color(0xFFFF4D9A);
  static const amber = Color(0xFFFFB020);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);

  /// Live Show's venue mark: poster and stub edges, the Venue Badge outline
  /// and its text (5.9:1 on [surface]), calendar dots, the Live chart series.
  /// Never a fill bigger than a mark.
  static const liveMark = magenta;

  /// Studio Session's venue mark, used exactly like [liveMark] (10.1:1 on
  /// [surface]).
  static const studioMark = cyan;

  /// Deep lights: fills with white text on them.
  static const magentaDeep = Color(0xFFE0157A);
  static const orangeDeep = Color(0xFFC2410C);
  static const violetDeep = Color(0xFF6D28D9);
  static const tealDeep = Color(0xFF0E7490);

  /// A plain stage grey for the Fine Feel Face (white face 9.3:1).
  static const feelFine = Color(0xFF4A4458);

  /// Gold for Gold Records (the flat foil, discs and badges). Only [goldInk]
  /// sits on gold as text (11.4:1 on [goldMid], 15.4:1 on [goldLight], 5.1:1
  /// on [goldDeep]); gold is never body text on the dark stage, [amber] does
  /// that job. [goldInk] is also the text on [amber] (10.1:1).
  static const goldLight = Color(0xFFFFE9A8);
  static const goldMid = Color(0xFFF5C451);

  /// The printed halftone dots on the foil, and the disc's grooves.
  static const goldDeep = Color(0xFFB7791F);

  /// Near-black brown ink for text on the gold foil and on amber.
  static const goldInk = Color(0xFF1A1206);

  /// Spotify's brand green. The one brand color allowed in the app, and only
  /// as the fill of the "Open in Spotify" button, always with black text
  /// (8.1:1). Never on song picker rows or anywhere else.
  static const spotifyGreen = Color(0xFF1DB954);

  /// The film grain over the stage and the posters: Spotlight White at 5%.
  static const grainOpacity = 0.05;
}

/// Font families bundled in assets/fonts.
///
/// [display] is Archivo cut at extra-condensed width and black weight: the
/// tour-poster face for titles and big numbers. It has lowercase, so names
/// (songs, Gear, routes) stay in their own case; titles are uppercased where
/// they are written. [body] is the same family at normal width.
class StageFonts {
  static const display = 'ArchivoCondensed';
  static const body = 'Archivo';

  /// Digits that line up in columns (times, paces, miles).
  static const tabular = [FontFeature.tabularFigures()];
}

class AppTheme {
  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: StageColors.amber,
          brightness: Brightness.dark,
        ).copyWith(
          // Amber is the one accent: every action, selection, focus ring and
          // progress indicator, with Gold Ink on it (10.1:1).
          primary: StageColors.amber,
          onPrimary: StageColors.goldInk,
          secondary: StageColors.amber,
          onSecondary: StageColors.goldInk,
          tertiary: StageColors.cyan,
          surface: StageColors.surface,
          onSurface: StageColors.text,
          onSurfaceVariant: StageColors.textMuted,
          surfaceContainerHighest: StageColors.surfaceHigh,
          outline: StageColors.outline,
        );

    final base = ThemeData.dark().textTheme.apply(fontFamily: StageFonts.body);
    // Condensed poster type for the big stuff.
    TextStyle poster(TextStyle? b, double size) =>
        (b ?? const TextStyle()).copyWith(
          fontFamily: StageFonts.display,
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1.05,
          color: StageColors.text,
        );
    final text = base
        .copyWith(
          displayLarge: poster(base.displayLarge, 64),
          displayMedium: poster(base.displayMedium, 48),
          displaySmall: poster(base.displaySmall, 38),
          headlineLarge: poster(base.headlineLarge, 34),
          headlineMedium: poster(base.headlineMedium, 30),
          headlineSmall: poster(base.headlineSmall, 26),
          titleLarge: poster(base.titleLarge, 24),
        )
        .apply(bodyColor: StageColors.text, displayColor: StageColors.text);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: StageFonts.body,
      scaffoldBackgroundColor: StageColors.background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: StageColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: StageColors.text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: StageColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: StageColors.outline),
        ),
      ),
      // Filled fields float their label inside the fill. (An outline border
      // here would park the label on the field's top edge, half outside it.)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StageColors.surfaceHigh,
        border: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StageColors.amber, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: const TextStyle(color: StageColors.textMuted),
        hintStyle: const TextStyle(color: StageColors.textMuted),
        floatingLabelStyle: const TextStyle(color: StageColors.amber),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: StageColors.surfaceHigh,
        selectedColor: StageColors.amber,
        side: const BorderSide(color: StageColors.outline),
        // Readable label on both the dark (unselected) and amber chip.
        labelStyle: TextStyle(
          fontFamily: StageFonts.body,
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? StageColors.goldInk
                : StageColors.text,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      // Secondary filled buttons are flat Stage Surface High with an outline,
      // so amber stays the one Stage Button (and selection) on a screen.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: StageColors.surfaceHigh,
          foregroundColor: StageColors.text,
          side: const BorderSide(color: StageColors.outline),
          textStyle: const TextStyle(
            fontFamily: StageFonts.body,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: StageColors.amber),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StageColors.amber,
          side: const BorderSide(color: StageColors.outline),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: StageColors.amber,
        foregroundColor: StageColors.goldInk,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      // The selected tab sits on an amber pill (amber 30% on the surface)
      // with its icon in Spotlight White (9.9:1 on the pill).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: StageColors.surface,
        indicatorColor: StageColors.amber.withValues(alpha: 0.3),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? StageColors.text
                : StageColors.textMuted,
          ),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: StageFonts.body,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: StageColors.surface,
        indicatorColor: StageColors.amber.withValues(alpha: 0.3),
        selectedIconTheme: const IconThemeData(color: StageColors.text),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: StageColors.amber,
        thumbColor: StageColors.amber,
        inactiveTrackColor: StageColors.outline,
        valueIndicatorColor: StageColors.amber,
        valueIndicatorTextStyle: TextStyle(
          color: StageColors.goldInk,
          fontWeight: FontWeight.w700,
        ),
      ),
      // On: an amber thumb on an amber-tinted track with an amber outline.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? StageColors.amber
              : StageColors.textMuted,
        ),
        trackColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? StageColors.amber.withValues(alpha: 0.3)
              : StageColors.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? StageColors.amber
              : StageColors.textMuted,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: StageColors.amber,
        linearTrackColor: StageColors.surfaceHigh,
      ),
      // The parts the browser would otherwise draw in its own colors.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: StageColors.amber,
        selectionColor: StageColors.amber.withValues(alpha: 0.35),
        selectionHandleColor: StageColors.amber,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          StageColors.textMuted.withValues(alpha: 0.4),
        ),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? StageColors.amber
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? StageColors.goldInk
                : StageColors.text,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: StageColors.outline),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: StageColors.outline),
      // Dialogs, sheets and menus sit on the stage's own surfaces instead of
      // the warm grey Material tints from the seed color.
      dialogTheme: DialogThemeData(
        backgroundColor: StageColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.headlineSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: StageColors.outline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: StageColors.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: StageColors.outline,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: StageColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: StageColors.outline),
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: StageColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: StageColors.surfaceHigh,
        headerForegroundColor: StageColors.text,
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: StageColors.surface,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: StageColors.surfaceHigh,
        contentTextStyle: TextStyle(color: StageColors.text),
      ),
    );
  }
}
