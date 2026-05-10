import 'package:flutter/material.dart';

/// Конфигурация темы приложения
class ThemeConfig {
  // Основные цвета
  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color secondaryColor = Color(0xFF8BC34A);
  static const Color accentColor = Color(0xFFCDDC39);
  
  // Цвета фона
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color surfaceColor = Color(0xFFF5F5F5);
  
  // Цвета текста
  static const Color primaryTextColor = Color(0xFF212121);
  static const Color secondaryTextColor = Color(0xFF757575);
  
  // Цвета состояния
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color successColor = Color(0xFF388E3C);
  static const Color warningColor = Color(0xFFFFA000);
  static const Color infoColor = Color(0xFF1976D2);
  
  // Размеры шрифтов
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 20.0;
  
  // Отступы
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  
  // Радиус скругления
  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 16.0;
  
  // Тема приложения
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: fontSizeLarge, color: primaryTextColor),
        bodyMedium: TextStyle(fontSize: fontSizeMedium, color: primaryTextColor),
        bodySmall: TextStyle(fontSize: fontSizeSmall, color: secondaryTextColor),
      ),
      useMaterial3: true,
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: fontSizeLarge, color: Colors.white),
        bodyMedium: TextStyle(fontSize: fontSizeMedium, color: Colors.white),
        bodySmall: TextStyle(fontSize: fontSizeSmall, color: Colors.grey),
      ),
      useMaterial3: true,
    );
  }
}
