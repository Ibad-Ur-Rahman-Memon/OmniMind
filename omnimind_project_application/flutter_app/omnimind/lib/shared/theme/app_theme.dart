import 'package:flutter/material.dart';

class AppColors {
  // Brand
  // Keeping your required palette (from prompt)
  // Updated for stronger contrast + clearer “blue” visuals across the app
  static const primary = Color(0xFF2F6BFF); // brighter blue
  static const primaryLight = Color(0xFF7AA7FF); // used for gradients
  static const primaryDark = Color(0xFF1E4FD9);
  static const secondary = Color(0xFF00C9A7); // #00C9A7
  static const accent = Color(0xFFFF6B6B); // #FF6B6B

  // Emotion colors
  static const emotionAnxiety = Color(0xFFFF9800);
  static const emotionDepression = Color(0xFF5C6BC0);
  static const emotionStress = Color(0xFFEF5350);
  static const emotionNeutral = Color(0xFF66BB6A);
  static const emotionCrisis = Color(0xFFF44336);

  // Risk colors
  static const riskLow = Color(0xFF4CAF50);
  static const riskModerate = Color(0xFFFF9800);
  static const riskHigh = Color(0xFFF44336);
  static const riskUnknown = Color(0xFF9E9E9E);

  // Light mode
  static const lightBackground = Color(0xFFF8F9FF);
  static const lightSurface = Colors.white;
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1A1A2E);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightBorder = Color(0xFFE5E7EB);

  // Dark mode
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkCard = Color(0xFF111827);

  static const darkText = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF2E2E4A);

  // LOGIN: tokens tuned for readability on assets/images/back_login.png
  // (background is an image; we use a consistent “dark glass” overlay + tint)
  static const loginText = Color(0xFFF8FAFF);
  static const loginTextSecondary = Color(0xFFE8EEFF);

  static const loginDivider = Color(0xFFFFFFFF); // use opacity at call-site

  static const loginOverlay = Color(0xFF000000); // use withOpacity

  static const loginGlassFill = Color(0xFF0B1220); // dark glass base
  static const loginGlassBorder = Color(0xFFFFFFFF); // use opacity

  static const loginFieldFill = Color(0xFF0B1220); // dark inside fields
  static const loginFieldBorder = Color(0xFF99A3B5); // use withOpacity

  static const List<Color> primaryGradient = [Color(0xFF2F6BFF), Color(0xFF7A5CFF)];
  static const List<Color> secondaryGradient = [Color(0xFF7A5CFF), Color(0xFF2F6BFF)];


  static const List<Color> warmGradient = [Color(0xFFFF6B6B), Color(0xFFFF8E53)];
  static const List<Color> darkGradient = [Color(0xFF0F172A), Color(0xFF1E293B)];

}


class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSans',
    ).textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.lightText,
      ),
      displayMedium: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      headlineLarge: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.lightText,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.lightText,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.lightTextSecondary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.lightText,
      ),
      iconTheme: IconThemeData(color: AppColors.lightText),
    ),
cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightTextSecondary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.darkSurface,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'NotoSans',
    ).textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
      displayMedium: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      headlineLarge: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.darkText,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.darkText,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.darkTextSecondary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      iconTheme: IconThemeData(color: AppColors.darkText),
    ),
cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextSecondary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
