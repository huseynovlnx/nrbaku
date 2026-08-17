import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// NrBaku — Kartel estetikası dizayn sistemi.
/// API adları (purple, pink, bg...) dəyişdirilmir — 17 fayl istinad edir.
class AppTheme {
  // ── NrBaku Palitrası ──────────────────────────────────────
  static const Color purple  = Color(0xFFC9A84C); // patron qızılı — əsas vurğu
  static const Color pink    = Color(0xFF8B1A1A);  // kartel qırmızısı — ikinci vurğu
  static const Color bg      = Color(0xFF0A0A0A);  // dərin qara
  static const Color bgDark  = Color(0xFF0A0A0A);

  static const Color surface  = Color(0xFF1A1208); // tünd qızıl panel
  static const Color surface2 = Color(0xFF2A1F0A); // ikinci panel qatı
  static const Color textMain = Color(0xFFF5F0E8); // saralmış kağız — maksimum oxunaqlı
  static const Color textDim  = Color(0xFF8A7A5A); // solğun qızıl
  static const Color border   = Color(0xFF3A2E18); // panel kənarı
  static const Color alert    = Color(0xFF8B0000); // təhlükə qırmızısı
  static const Color warning  = Color(0xFFE8C96A); // xəbərdarlıq — açıq qızıl

  static const LinearGradient gradient = LinearGradient(
    colors: [Color(0xFFC9A84C), Color(0xFFE8C96A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Şrift köməkçiləri ─────────────────────────────────────
  static TextStyle heading({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? spacing,
  }) =>
      GoogleFonts.playfairDisplay(
        fontSize: size,
        fontWeight: weight,
        color: color ?? purple,
        letterSpacing: spacing,
      );

  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? spacing,
  }) =>
      GoogleFonts.sourceCodePro(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textMain,
        letterSpacing: spacing,
      );

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.lato(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textMain,
      );

  // ── Material tema ─────────────────────────────────────────
  static ThemeData _build() {
    final base = ThemeData(brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: purple,
        secondary: pink,
        surface: surface,
        onPrimary: bg,
        onSecondary: textMain,
        onSurface: textMain,
        error: alert,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: textMain, displayColor: purple)
          .copyWith(
            headlineLarge: heading(size: 28),
            headlineMedium: heading(size: 22),
            headlineSmall: heading(size: 18),
            titleLarge: body(size: 17, weight: FontWeight.w700),
            titleMedium: body(size: 15, weight: FontWeight.w600),
            bodyLarge: body(size: 16),
            bodyMedium: body(size: 14),
            bodySmall: body(size: 12, color: textDim),
            labelLarge: mono(size: 14, weight: FontWeight.w600, color: purple),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: purple,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: heading(size: 18, spacing: 0.5),
        iconTheme: const IconThemeData(color: purple),
        shape: const Border(bottom: BorderSide(color: border, width: 1)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141414),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: purple, width: 1.5),
        ),
        hintStyle: body(size: 14, color: textDim),
        labelStyle: body(size: 14, color: textDim),
        prefixIconColor: purple,
        suffixIconColor: textDim,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: purple,
          disabledForegroundColor: textDim,
          minimumSize: const Size(double.infinity, 56),
          side: const BorderSide(color: purple, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          textStyle: mono(size: 15, weight: FontWeight.w700, spacing: 2),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: purple,
          side: const BorderSide(color: purple),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          textStyle: mono(size: 14, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: purple,
          textStyle: body(size: 14, weight: FontWeight.w600, color: purple),
        ),
      ),
      iconTheme: const IconThemeData(color: purple),
      dividerColor: border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface2,
        contentTextStyle: body(size: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F0C06),
        indicatorColor: purple.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: purple);
          }
          return const IconThemeData(color: Color(0xFF5A4A2A));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return mono(size: 11, weight: FontWeight.w700, color: purple);
          }
          return mono(size: 11, color: Color(0xFF5A4A2A));
        }),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
      ),
    );
  }

  static ThemeData light = _build();
  static ThemeData dark  = _build();
}
