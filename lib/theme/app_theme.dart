import 'package:material_ui/material_ui.dart';

/// Concert-poster palette: a dark stage under magenta, amber and violet lights.
///
/// Fills that carry white text use the deeper "stage" shades so labels stay
/// readable (4.5:1 or better). The bright shades are for text and marks on the
/// dark background.
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

  /// Deep lights: fills with white text on them.
  static const magentaDeep = Color(0xFFE0157A);
  static const orangeDeep = Color(0xFFC2410C);
  static const violetDeep = Color(0xFF6D28D9);
  static const tealDeep = Color(0xFF0E7490);

  /// Live Shows: warm stage lights.
  static const liveGradient = LinearGradient(
    colors: [magentaDeep, orangeDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Studio Sessions: cool studio lights.
  static const studioGradient = LinearGradient(
    colors: [violetDeep, tealDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Screen headers and the main call to action.
  static const headlineGradient = LinearGradient(
    colors: [violetDeep, magentaDeep, orangeDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
          seedColor: StageColors.magentaDeep,
          brightness: Brightness.dark,
        ).copyWith(
          primary: StageColors.magentaDeep,
          onPrimary: Colors.white,
          secondary: StageColors.amber,
          onSecondary: Colors.black,
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
          borderSide: const BorderSide(color: StageColors.magenta, width: 2),
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
        floatingLabelStyle: const TextStyle(color: StageColors.magenta),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: StageColors.surfaceHigh,
        selectedColor: StageColors.magentaDeep,
        side: const BorderSide(color: StageColors.outline),
        // Readable label on both the dark (unselected) and pink chip.
        labelStyle: TextStyle(
          fontFamily: StageFonts.body,
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : StageColors.text,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: StageColors.magentaDeep,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: StageFonts.body,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: StageColors.magenta),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: StageColors.magenta,
          side: const BorderSide(color: StageColors.outline),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: StageColors.magentaDeep,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: StageColors.surface,
        indicatorColor: StageColors.magentaDeep.withValues(alpha: 0.35),
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
        indicatorColor: StageColors.magentaDeep.withValues(alpha: 0.35),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: StageColors.magenta,
        thumbColor: StageColors.amber,
        inactiveTrackColor: StageColors.outline,
        valueIndicatorColor: StageColors.magentaDeep,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? StageColors.magentaDeep
              : StageColors.surfaceHigh,
        ),
      ),
      // The parts the browser would otherwise draw in its own colors.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: StageColors.magenta,
        selectionColor: StageColors.magenta.withValues(alpha: 0.35),
        selectionHandleColor: StageColors.magenta,
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
                ? StageColors.magentaDeep
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
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
