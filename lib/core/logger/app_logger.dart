// Firebase отключено для Windows из-за проблем с CMake
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
// import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Глобальный экземпляр logger
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    noBoxingByDefault: false,
  ),
  filter: ProductionFilter(),
  output: ConsoleOutput(),
);

/// Фильтр для продакшн-режима (отключает debug логи)
class ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // В продакшн-режиме логируем только warning и error
    // В debug-режиме логируем всё
    return true;
  }
}

/// Настройка уровней логирования
enum LogLevel {
  trace,
  debug,
  info,
  warning,
  error,
  fatal,
  none,
}

/// Установка уровня логирования
void setLogLevel(LogLevel level) {
  switch (level) {
    case LogLevel.trace:
      Logger.level = Level.trace;
      break;
    case LogLevel.debug:
      Logger.level = Level.debug;
      break;
    case LogLevel.info:
      Logger.level = Level.info;
      break;
    case LogLevel.warning:
      Logger.level = Level.warning;
      break;
    case LogLevel.error:
      Logger.level = Level.error;
      break;
    case LogLevel.fatal:
      Logger.level = Level.fatal;
      break;
    case LogLevel.none:
      Logger.level = Level.off;
      break;
  }
}

/// Категории логов
enum LogCategory {
  sync,
  db,
  api,
  ui,
  photo,
  notification,
}

/// Логирование с категорией
void logWithCategory(LogCategory category, String message, {dynamic error, StackTrace? stackTrace}) {
  final categoryPrefix = '[${category.name.toUpperCase()}]';
  logger.d('$categoryPrefix $message', error: error, stackTrace: stackTrace);
}

/// Удобная обёртка для логирования с тегом.
class AppLogger {
  /// Буфер последних логов для отображения в UI.
  static final List<String> _recentLogs = [];
  static const int _maxRecentLogs = 200;

  /// Возвращает последние [limit] записей лога.
  static List<String> getRecentLogs({int limit = 100}) {
    final logs = List<String>.from(_recentLogs);
    return logs.length > limit ? logs.sublist(logs.length - limit) : logs;
  }

  /// Очищает буфер логов.
  static void clearLogs() => _recentLogs.clear();

  static void _addToBuffer(String message) {
    _recentLogs.add(message);
    if (_recentLogs.length > _maxRecentLogs) {
      _recentLogs.removeAt(0);
    }
  }

  static void api(String message, {String? tag}) {
    final msg = '${tag != null ? '[$tag] ' : ''}$message';
    _addToBuffer('[${_timestamp()}] [API] $msg');
    logger.i(msg);
  }

  static void db(String message, {String? tag}) {
    final msg = '${tag != null ? '[$tag] ' : ''}$message';
    _addToBuffer('[${_timestamp()}] [DB] $msg');
    logger.d(msg);
  }

  static void ui(String message, {String? tag}) {
    final msg = '${tag != null ? '[$tag] ' : ''}$message';
    _addToBuffer('[${_timestamp()}] [UI] $msg');
    logger.d(msg);
  }

  static void warning(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    final msg = '${tag != null ? '[$tag] ' : ''}$message';
    _addToBuffer('[${_timestamp()}] [WARN] $msg${error != null ? ' | $error' : ''}');
    logger.w(msg, error: error, stackTrace: stackTrace);
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  static void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    final fullMessage = '${tag != null ? '[$tag] ' : ''}$message';
    _addToBuffer('[${_timestamp()}] [ERROR] $fullMessage${error != null ? ' | $error' : ''}');
    logger.e(fullMessage, error: error, stackTrace: stackTrace);

    // Отправляем в Crashlytics (только в release режиме) - отключено для Windows
    // if (!kDebugMode) {
    //   FirebaseCrashlytics.instance.recordError(
    //     error ?? Exception(message),
    //     stackTrace,
    //     reason: fullMessage,
    //     information: tag != null ? [tag] : [],
    //   );
    // }
  }

  /// Отправка custom event в Analytics - отключено для Windows
  static void logEvent(String name, {Map<String, dynamic>? parameters}) {
    // if (!kDebugMode) {
    //   FirebaseAnalytics.instance.logEvent(
    //     name: name,
    //     parameters: parameters,
    //   );
    // }
  }

  /// Инициализация Firebase Crashlytics - отключено для Windows
  static Future<void> initializeCrashlytics() async {
    // Включаем автоматический сбор крашей
    // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    
    // Перехватываем все непойманные ошибки Flutter
    // FlutterError.onError = (errorDetails) {
    //   FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    // };
    
    // Перехватываем ошибки в зонах (async)
    // PlatformDispatcher.instance.onError = (error, stack) {
    //   FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    //   return true;
    // };
  }
}

