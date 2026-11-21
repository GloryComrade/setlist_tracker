import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Concert-poster palette: a dark stage, magenta and amber lights.
class StageColors {
  static const background = Color(0xFF0B0A12);
  static const surface = Color(0xFF16141F);
  static const surfaceHigh = Color(0xFF221F2E);
  static const magenta = Color(0xFFFF2E88);
  static const amber = Color(0xFFFFB020);
  static const violet = Color(0xFF7B2FF7);
  static const cyan = Color(0xFF22D3EE);
  static const text = Color(0xFFF5F3FA);
  static const textMuted = Color(0xFFA8A3B8);
  static const outline = Color(0xFF3A3548);

  /// Live Shows: warm stage lights.
  static const liveGradient = LinearGradient(
    colors: [magenta, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Studio Sessions: cool studio lights.
  static const studioGradient = LinearGradient(
    colors: [violet, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Headers and main buttons.
  static const headlineGradient = LinearGradient(
    colors: [violet, magenta, amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: StageColors.magenta,
      brightness: Brightness.dark,
    ).copyWith(
      primary: StageColors.magenta,
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

    final body = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    // Condensed poster type for the big stuff.
    TextStyle poster(TextStyle? base, double size) =>
        GoogleFonts.bebasNeue(textStyle: base).copyWith(
          fontSize: size,
          letterSpacing: 1.2,
          height: 1.0,
          color: StageColors.text,
        );
    final text = body.copyWith(
      displayLarge: poster(body.displayLarge, 64),
      displayMedium: poster(body.displayMedium, 48),
      displaySmall: poster(body.displaySmall, 38),
      headlineLarge: poster(body.headlineLarge, 34),
      headlineMedium: poster(body.headlineMedium, 30),
      headlineSmall: poster(body.headlineSmall, 26),
      titleLarge: poster(body.titleLarge, 24),
    ).apply(bodyColor: StageColors.text, displayColor: StageColors.text);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: StageColors.background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: StageColors.background,
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StageColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StageColors.magenta, width: 2),
        ),
        labelStyle: const TextStyle(color: StageColors.textMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: StageColors.surfaceHigh,
        selectedColor: StageColors.magenta,
        side: const BorderSide(color: StageColors.outline),
        // Readable label on both the dark (unselected) and magenta chip.
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : StageColors.text),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: StageColors.surface,
        indicatorColor: StageColors.magenta.withValues(alpha: 0.25),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: StageColors.surface,
        indicatorColor: StageColors.magenta.withValues(alpha: 0.25),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: StageColors.magenta,
        thumbColor: StageColors.amber,
        inactiveTrackColor: StageColors.outline,
      ),
      dividerTheme: const DividerThemeData(color: StageColors.outline),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: StageColors.surfaceHigh,
        contentTextStyle: TextStyle(color: StageColors.text),
      ),
    );
  }
}
