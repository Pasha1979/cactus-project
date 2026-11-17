import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../logger/app_logger.dart';

/// Система Feature Flags для управления функциями без пересборки приложения.
///
/// Позволяет включать/выключать функции удаленно через Firebase Remote Config
/// или локально для тестирования.
///
/// Использование:
/// ```dart
/// if (FeatureFlags.isEnabled(FeatureFlag.enableGbifParsing)) {
///   // Использовать GBIF API
/// }
/// ```
class FeatureFlags {
  static FirebaseRemoteConfig? _remoteConfig;
  static final Map<FeatureFlag, bool> _localOverrides = {};

  /// Инициализация Feature Flags
  ///
  /// Вызывается в main.dart после инициализации Firebase.
  /// В debug режиме использует локальные значения.
  /// В release режиме загружает из Firebase Remote Config.
  static Future<void> initialize() async {
    if (kDebugMode) {
      // В debug используем локальные значения по умолчанию
      return;
    }

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ),);

      await _remoteConfig!.setDefaults(_defaultValues);
      await _remoteConfig!.fetchAndActivate();
    } catch (e) {
      AppLogger.warning('⚠️ Не удалось инициализировать Remote Config: $e', tag: 'FEATURE_FLAGS');
      // При ошибке используем значения по умолчанию
    }
  }

  /// Проверить, включен ли флаг
  static bool isEnabled(FeatureFlag flag) {
    // Сначала проверяем локальный override (для тестирования)
    if (_localOverrides.containsKey(flag)) {
      return _localOverrides[flag]!;
    }

    // В debug режиме используем значения по умолчанию
    if (kDebugMode) {
      return flag.defaultValue;
    }

    // В release режиме используем Remote Config
    if (_remoteConfig != null) {
      return _remoteConfig!.getBool(flag.key);
    }

    return flag.defaultValue;
  }

  /// Установить локальный override (для тестирования)
  ///
  /// [flag] - флаг для изменения
  /// [value] - новое значение
  ///
  /// Пример:
  /// ```dart
  /// FeatureFlags.setLocalOverride(
  ///   FeatureFlag.enableGbifParsing,
  ///   false,
  /// );
  /// ```
  static void setLocalOverride(FeatureFlag flag, bool value) {
    _localOverrides[flag] = value;
  }

  /// Сбросить локальный override
  static void clearLocalOverride(FeatureFlag flag) {
    _localOverrides.remove(flag);
  }

  /// Сбросить все локальные overrides
  static void clearAllLocalOverrides() {
    _localOverrides.clear();
  }

  /// Принудительное обновление из Remote Config
  static Future<void> forceRefresh() async {
    if (_remoteConfig != null && !kDebugMode) {
      await _remoteConfig!.fetchAndActivate();
    }
  }

  /// Значения по умолчанию для Remote Config
  static Map<String, dynamic> get _defaultValues {
    return {
      for (var flag in FeatureFlag.values) flag.key: flag.defaultValue,
    };
  }
}

/// Перечисление всех Feature Flags
///
/// Каждый флаг имеет:
/// - [key] - уникальный ключ для Remote Config
/// - [defaultValue] - значение по умолчанию
/// - [description] - описание для документации
enum FeatureFlag {
  /// Интеграция с GBIF API для поиска данных о растениях
  enableGbifParsing(
    key: 'enable_gbif_parsing',
    defaultValue: true,
    description: 'Включает поиск данных из GBIF по латинскому названию',
  ),

  /// Погодные советы для полива
  enableWeatherAdvice(
    key: 'enable_weather_advice',
    defaultValue: true,
    description: 'Показывает рекомендации по поливу на основе погоды',
  ),

  /// Управление партиями растений (batch/seedlings)
  enableBatchManagement(
    key: 'enable_batch_management',
    defaultValue: true,
    description: 'Включает функционал управления партиями семян/сеянцев',
  ),

  /// Новый улучшенный алгоритм расчета полива
  enableNewWateringAlgorithm(
    key: 'enable_new_watering_algorithm',
    defaultValue: false,
    description: 'Использует новый алгоритм расчета даты следующего полива',
  ),

  /// Расширенная статистика по коллекции
  enableAdvancedStatistics(
    key: 'enable_advanced_statistics',
    defaultValue: true,
    description: 'Показывает расширенные графики и аналитику',
  ),

  /// Экспериментальный UI для карточки растения
  enableExperimentalPlantCard(
    key: 'enable_experimental_plant_card',
    defaultValue: false,
    description: 'Новый дизайн карточки растения (A/B тестирование)',
  ),

  /// Автоматическая синхронизация с облаком
  enableAutoCloudSync(
    key: 'enable_auto_cloud_sync',
    defaultValue: false,
    description: 'Автоматическая синхронизация при изменениях',
  ),

  /// QR-коды для растений
  enableQrCodes(
    key: 'enable_qr_codes',
    defaultValue: true,
    description: 'Включает генерацию и сканирование QR-кодов',
  ),

  /// Уведомления о зимовке
  enableWinteringNotifications(
    key: 'enable_wintering_notifications',
    defaultValue: true,
    description: 'Напоминания о начале/окончании зимовки',
  );

  const FeatureFlag({
    required this.key,
    required this.defaultValue,
    required this.description,
  });

  final String key;
  final bool defaultValue;
  final String description;
}

/// Extension для удобного использования
extension FeatureFlagExtension on FeatureFlag {
  /// Проверить, включен ли флаг
  bool get isEnabled => FeatureFlags.isEnabled(this);
}
