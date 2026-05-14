import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logger/app_logger.dart';

/// Provider для управления настройками приложения.
///
/// Хранит все пользовательские настройки в SharedPreferences
/// и уведомляет UI об изменениях.
class SettingsProvider with ChangeNotifier {
  // ==================== ТЕМА ====================
  String _themeMode = 'system'; // 'light', 'dark', 'system'
  String get themeMode => _themeMode;

  // ==================== ОБЛАКО ====================
  bool _autoSyncOnStartup = false;
  bool get autoSyncOnStartup => _autoSyncOnStartup;

  // ==================== ПОГОДА ====================
  bool _weatherEnabled = true;
  bool get weatherEnabled => _weatherEnabled;

  // ==================== БЭКАП ====================
  bool _autoBackupEnabled = true;
  bool get autoBackupEnabled => _autoBackupEnabled;

  String _backupFrequency = '24h'; // '12h', '24h', '7d'
  String get backupFrequency => _backupFrequency;

  // ==================== УВЕДОМЛЕНИЯ ====================
  bool _wateringNotificationsEnabled = true;
  bool get wateringNotificationsEnabled => _wateringNotificationsEnabled;

  String _notificationTime = '09:00';
  String get notificationTime => _notificationTime;

  bool _notificationSoundEnabled = true;
  bool get notificationSoundEnabled => _notificationSoundEnabled;

  // ==================== ПОВЕДЕНИЕ ====================
  bool _autoSaveEnabled = true;
  bool get autoSaveEnabled => _autoSaveEnabled;

  bool _confirmBeforeDelete = true;
  bool get confirmBeforeDelete => _confirmBeforeDelete;

  bool _animationsEnabled = true;
  bool get animationsEnabled => _animationsEnabled;

  // ==================== ЭКСПЕРИМЕНТЫ ====================
  bool _showPlantIds = false;
  bool get showPlantIds => _showPlantIds;

  // ==================== ОТЛАДКА ====================
  bool _apiLoggingEnabled = false;
  bool get apiLoggingEnabled => _apiLoggingEnabled;

  // ==================== ИНИЦИАЛИЗАЦИЯ ====================

  /// Загрузить все настройки из SharedPreferences.
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _themeMode = prefs.getString('settings_theme_mode') ?? 'system';
      _autoSyncOnStartup = prefs.getBool('settings_auto_sync_startup') ?? false;
      _weatherEnabled = prefs.getBool('settings_weather_enabled') ?? true;
      _autoBackupEnabled = prefs.getBool('settings_auto_backup_enabled') ?? true;
      _backupFrequency = prefs.getString('settings_backup_frequency') ?? '24h';
      _wateringNotificationsEnabled =
          prefs.getBool('settings_watering_notifications') ?? true;
      _notificationTime = prefs.getString('settings_notification_time') ?? '09:00';
      _notificationSoundEnabled =
          prefs.getBool('settings_notification_sound') ?? true;
      _autoSaveEnabled = prefs.getBool('settings_auto_save') ?? true;
      _confirmBeforeDelete = prefs.getBool('settings_confirm_delete') ?? true;
      _animationsEnabled = prefs.getBool('settings_animations') ?? true;
      _showPlantIds = prefs.getBool('settings_show_plant_ids') ?? false;
      _apiLoggingEnabled = prefs.getBool('settings_api_logging') ?? false;

      notifyListeners();
      AppLogger.api('Settings loaded successfully', tag: 'SETTINGS');
    } catch (e) {
      AppLogger.api('Error loading settings: $e', tag: 'SETTINGS');
    }
  }

  // ==================== СЕТТЕРЫ ====================

  Future<void> setThemeMode(String value) async {
    _themeMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_theme_mode', value);
    notifyListeners();
    AppLogger.api('Theme mode changed to: $value', tag: 'SETTINGS');
  }

  Future<void> setAutoSyncOnStartup(bool value) async {
    _autoSyncOnStartup = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_auto_sync_startup', value);
    notifyListeners();
  }

  Future<void> setWeatherEnabled(bool value) async {
    _weatherEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_weather_enabled', value);
    notifyListeners();
  }

  Future<void> setAutoBackupEnabled(bool value) async {
    _autoBackupEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_auto_backup_enabled', value);
    notifyListeners();
  }

  Future<void> setBackupFrequency(String value) async {
    _backupFrequency = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_backup_frequency', value);
    notifyListeners();
  }

  Future<void> setWateringNotificationsEnabled(bool value) async {
    _wateringNotificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_watering_notifications', value);
    notifyListeners();
  }

  Future<void> setNotificationTime(String value) async {
    _notificationTime = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_notification_time', value);
    notifyListeners();
  }

  Future<void> setNotificationSoundEnabled(bool value) async {
    _notificationSoundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_notification_sound', value);
    notifyListeners();
  }

  Future<void> setAutoSaveEnabled(bool value) async {
    _autoSaveEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_auto_save', value);
    notifyListeners();
  }

  Future<void> setConfirmBeforeDelete(bool value) async {
    _confirmBeforeDelete = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_confirm_delete', value);
    notifyListeners();
  }

  Future<void> setAnimationsEnabled(bool value) async {
    _animationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_animations', value);
    notifyListeners();
  }

  Future<void> setShowPlantIds(bool value) async {
    _showPlantIds = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_show_plant_ids', value);
    notifyListeners();
  }

  Future<void> setApiLoggingEnabled(bool value) async {
    _apiLoggingEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings_api_logging', value);
    notifyListeners();
  }

  // ==================== СБРОС ====================

  /// Сбросить все настройки к значениям по умолчанию.
  Future<void> resetToDefaults() async {
    _themeMode = 'system';
    _autoSyncOnStartup = false;
    _weatherEnabled = true;
    _autoBackupEnabled = true;
    _backupFrequency = '24h';
    _wateringNotificationsEnabled = true;
    _notificationTime = '09:00';
    _notificationSoundEnabled = true;
    _autoSaveEnabled = true;
    _confirmBeforeDelete = true;
    _animationsEnabled = true;
    _showPlantIds = false;
    _apiLoggingEnabled = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('settings_theme_mode');
    await prefs.remove('settings_auto_sync_startup');
    await prefs.remove('settings_weather_enabled');
    await prefs.remove('settings_auto_backup_enabled');
    await prefs.remove('settings_backup_frequency');
    await prefs.remove('settings_watering_notifications');
    await prefs.remove('settings_notification_time');
    await prefs.remove('settings_notification_sound');
    await prefs.remove('settings_auto_save');
    await prefs.remove('settings_confirm_delete');
    await prefs.remove('settings_animations');
    await prefs.remove('settings_show_plant_ids');
    await prefs.remove('settings_api_logging');

    notifyListeners();
    AppLogger.api('Settings reset to defaults', tag: 'SETTINGS');
  }
}
