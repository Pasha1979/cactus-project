import 'dart:core';

/// Утилиты для валидации данных
class ValidationUtils {
  /// Валидация email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Валидация URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Валидация телефонного номера (простая проверка)
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^[\d\+\-\(\)\s]+$');
    return phoneRegex.hasMatch(phone) && phone.replaceAll(RegExp(r'[^\d]'), '').length >= 10;
  }

  /// Валидация имени (только буквы и пробелы)
  static bool isValidName(String name) {
    final nameRegex = RegExp(r'^[a-zA-Zа-яА-ЯёЁ\s]+$');
    return nameRegex.hasMatch(name) && name.trim().length >= 2;
  }

  /// Проверка, что строка не пустая
  static bool isNotEmpty(String value) {
    return value.trim().isNotEmpty;
  }

  /// Проверка минимальной длины
  static bool hasMinLength(String value, int minLength) {
    return value.trim().length >= minLength;
  }

  /// Проверка максимальной длины
  static bool hasMaxLength(String value, int maxLength) {
    return value.trim().length <= maxLength;
  }

  /// Проверка длины в диапазоне
  static bool hasLengthInRange(String value, int minLength, int maxLength) {
    final length = value.trim().length;
    return length >= minLength && length <= maxLength;
  }

  /// Проверка, что число в диапазоне
  static bool isNumberInRange(int value, int min, int max) {
    return value >= min && value <= max;
  }

  /// Проверка, что число положительное
  static bool isPositive(int value) {
    return value > 0;
  }

  /// Проверка, что число отрицательное
  static bool isNegative(int value) {
    return value < 0;
  }
}
