import 'package:flutter/material.dart';

/// NrBaku rəng sabitləri — API adları dəyişdirilmir, dəyərlər yenilənib.
class AppColors {
  AppColors._();

  static const Color primaryPink   = Color(0xFF8B1A1A); // kartel qırmızısı
  static const Color primaryPurple = Color(0xFFC9A84C); // patron qızılı
  static const Color primaryBlue   = Color(0xFFE8C96A); // açıq qızıl

  static const Color backgroundLight = Color(0xFF0A0A0A);
  static const Color surfaceLight    = Color(0xFF1A1208);
  static const Color textLight       = Color(0xFFF5F0E8);

  static const Color primaryPinkDark   = primaryPink;
  static const Color primaryPurpleDark = primaryPurple;
  static const Color primaryBlueDark   = primaryBlue;

  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark    = Color(0xFF1A1208);
  static const Color textDark       = Color(0xFFF5F0E8);

  static const Color danger  = Color(0xFF8B0000);
  static const Color success = Color(0xFFC9A84C);
  static const Color warning = Color(0xFFE8C96A);

  static const LinearGradient sosGradient = LinearGradient(
    colors: [Color(0xFF8B0000), Color(0xFFCC2200)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC9A84C), Color(0xFFE8C96A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
