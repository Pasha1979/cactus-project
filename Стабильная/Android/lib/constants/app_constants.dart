// lib/constants/app_constants.dart
// Централизованные константы для избежания опечаток в строковых литералах

// === Ключи SharedPreferences ===
class PrefsKeys {
  static const String plants = 'plants';
  static const String globalWateringDates = 'global_watering_dates';
  static const String searchHistory = 'search_history';
  static const String rememberMe = 'remember_me';
  static const String winteringStart = 'wintering_start';
  static const String winteringEnd = 'wintering_end';
  static const String winteringTemp = 'wintering_temp';
  static const String winteringLog = 'wintering_log';
  static const String adultImages = 'adult_images';
  static const String tokensCleanedAfterRebuild = 'tokens_cleaned_after_rebuild';
  static const String weatherCache = 'weather_cache';
}

// === Статусы растений ===
class PlantStatus {
  static const String sown = 'sown';
  static const String growing = 'growing';
  static const String inCollection = 'in_collection';
  static const String dead = 'dead';
  static const String failed = 'failed';
}

// === Категории растений ===
class PlantCategory {
  static const String sown = 'sown';
  static const String purchased = 'purchased';
}
