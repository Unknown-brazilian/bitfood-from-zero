import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFEA1D2C);
  static const Color orange = Color(0xFFFF6900);
  static const Color background = Color(0xFFF7F7F7);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF3E3E3E);
  static const Color textGrey = Color(0xFF717171);
  static const Color textLight = Color(0xFFAAAAAA);
  static const Color success = Color(0xFF50A773);
  static const Color divider = Color(0xFFEEEEEE);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.cardWhite,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          titleTextStyle: TextStyle(color: AppColors.textDark, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        useMaterial3: true,
      );
}
