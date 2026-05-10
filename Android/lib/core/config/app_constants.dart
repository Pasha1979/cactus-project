/// Основные константы приложения
class AppConstants {
  // Название приложения
  static const String appName = 'My Cactus';
  
  // Версия приложения
  static const String appVersion = '1.0.1';
  
  // Код версии
  static const int appVersionCode = 1;
  
  // Имя пакета
  static const String packageName = 'com.pavel.mycactus';
  
  // Поддерживаемые форматы изображений
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];
  
  // Максимальный размер изображения (в байтах)
  static const int maxImageSize = 10 * 1024 * 1024; // 10 MB
  
  // Максимальное количество растений
  static const int maxPlants = 10000;
  
  // Количество растений на странице
  static const int plantsPerPage = 20;
  
  // Таймаут для сетевых запросов (в секундах)
  static const int networkTimeout = 30;
  
  // Количество попыток повторного запроса
  static const int maxRetryAttempts = 3;
}

/// Ключи SharedPreferences
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
  static const String qrCodeFiles = 'qr_code_files';
  static const String qrScanHistory = 'qr_scan_history';
  static const String cloudStorageType = 'cloud_storage_type';
  static const String hasSeenWelcome = 'has_seen_welcome';
}

/// Статусы растений
class PlantStatus {
  static const String sown = 'sown';
  static const String growing = 'growing';
  static const String inCollection = 'in_collection';
  static const String dead = 'dead';
  static const String failed = 'failed';
}

/// Категории растений
class PlantCategory {
  static const String sown = 'sown';
  static const String purchased = 'purchased';
}
