import 'package:flutter/material.dart';

class CactusColors {
  // Спокойная кактусовая палитра (по твоему пожеланию — мягче)
  static const Color primaryGreen =
      Color(0xFF4A7043); // основной спокойный зелёный
  static const Color accentTerracotta =
      Color(0xFFB36A4E); // приглушённая терракота
  static const Color sandLight = Color(0xFFF5EDE4); // светлый песок
  static const Color sandBeige = Color(0xFFEDE0D4); // тёплый бежевый для чипов
  static const Color backgroundLight = Color(0xFFFBF7F2); // очень светлый фон

  // Тёмная тема (спокойная)
  static const Color primaryGreenDark = Color(0xFF2E4A2B);
  static const Color accentTerracottaDark = Color(0xFF9A5A40);
  static const Color backgroundDark = Color(0xFF1F1F1F);
}

class CactusTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CactusColors.primaryGreen,
        brightness: Brightness.light,
        primary: CactusColors.primaryGreen,
        secondary: CactusColors.accentTerracotta,
        surface: CactusColors.sandLight, // исправлено: background → surface
      ),
      scaffoldBackgroundColor: CactusColors.backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: CactusColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        // исправлено: CardTheme → CardThemeData
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CactusColors.sandBeige,
        labelStyle: const TextStyle(color: Colors.black87, fontSize: 13.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CactusColors.primaryGreen,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CactusColors.primaryGreenDark,
        brightness: Brightness.dark,
        primary: CactusColors.primaryGreenDark,
        secondary: CactusColors.accentTerracottaDark,
        surface: const Color(0xFF2A2A2A), // исправлено: background → surface
      ),
      scaffoldBackgroundColor: CactusColors.backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: CactusColors.primaryGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        // исправлено: CardTheme → CardThemeData
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF2A2A2A),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF3A3A3A),
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
