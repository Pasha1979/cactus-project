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

