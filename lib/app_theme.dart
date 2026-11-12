import 'package:flutter/material.dart';

enum PennywiseTheme { oceanBlue }

@immutable
class PennywisePalette extends ThemeExtension<PennywisePalette> {
  const PennywisePalette({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.muted,
    required this.primary,
    required this.primarySoft,
    required this.secondary,
    required this.line,
    required this.field,
    required this.income,
    required this.expense,
    required this.warning,
    required this.gradientStart,
    required this.gradientEnd,
    required this.isDark,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color muted;
  final Color primary;
  final Color primarySoft;
  final Color secondary;
  final Color line;
  final Color field;
  final Color income;
  final Color expense;
  final Color warning;
  final Color gradientStart;
  final Color gradientEnd;
  final bool isDark;

  static const Map<PennywiseTheme, PennywisePalette> themes = {
    PennywiseTheme.oceanBlue: PennywisePalette(
      canvas: Color(0xFFF2F7FC),
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFEAF2FA),
      text: Color(0xFF172A3A),
      muted: Color(0xFF6D8294),
      primary: Color(0xFF1677B8),
      primarySoft: Color(0xFFDCEFFA),
      secondary: Color(0xFF16A6A1),
      line: Color(0xFFD9E5EF),
      field: Color(0xFFF6FAFD),
      income: Color(0xFF15966F),
      expense: Color(0xFFD45D63),
      warning: Color(0xFFE0A52B),
      gradientStart: Color(0xFF126FB0),
      gradientEnd: Color(0xFF24AFC0),
      isDark: false,
    ),
  };

  static PennywisePalette of(BuildContext context) =>
      Theme.of(context).extension<PennywisePalette>() ??
      themes[PennywiseTheme.oceanBlue]!;

  LinearGradient get gradient => LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Color categoryColor(String category) => switch (category) {
    'Food' => warning,
    'PG/Rent' => primary,
    'Transport' => secondary,
    'Shopping' => gradientStart,
    'Entertainment/Movies' => gradientEnd,
    'Bills' || 'Bills & Recharge' => warning,
    'Personal Care' => gradientEnd,
    'Health' => income,
    'Education' => primary,
    'Social & Outings' => expense,
    'Travel' => secondary,
    _ => muted,
  };

  @override
  PennywisePalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? text,
    Color? muted,
    Color? primary,
    Color? primarySoft,
    Color? secondary,
    Color? line,
    Color? field,
    Color? income,
    Color? expense,
    Color? warning,
    Color? gradientStart,
    Color? gradientEnd,
    bool? isDark,
  }) => PennywisePalette(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    primary: primary ?? this.primary,
    primarySoft: primarySoft ?? this.primarySoft,
    secondary: secondary ?? this.secondary,
    line: line ?? this.line,
    field: field ?? this.field,
    income: income ?? this.income,
    expense: expense ?? this.expense,
    warning: warning ?? this.warning,
    gradientStart: gradientStart ?? this.gradientStart,
    gradientEnd: gradientEnd ?? this.gradientEnd,
    isDark: isDark ?? this.isDark,
  );

  @override
  PennywisePalette lerp(
    covariant ThemeExtension<PennywisePalette>? other,
    double t,
  ) {
    if (other is! PennywisePalette) return this;
    return PennywisePalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      line: Color.lerp(line, other.line, t)!,
      field: Color.lerp(field, other.field, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

ThemeData buildAppTheme() {
  final palette = PennywisePalette.themes[PennywiseTheme.oceanBlue]!;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: palette.isDark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: palette.primary,
        onPrimary: Colors.white,
        secondary: palette.secondary,
        surface: palette.surface,
        onSurface: palette.text,
        error: palette.expense,
      );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  return ThemeData(
    useMaterial3: true,
    brightness: palette.isDark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    extensions: [palette],
    scaffoldBackgroundColor: palette.canvas,
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineSmall: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(color: palette.text, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: palette.text),
      bodySmall: TextStyle(color: palette.muted),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.field,
      labelStyle: TextStyle(color: palette.muted),
      hintStyle: TextStyle(color: palette.muted),
      prefixIconColor: palette.muted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.expense),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
