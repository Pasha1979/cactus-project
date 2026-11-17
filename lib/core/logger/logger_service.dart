import 'package:logger/logger.dart';
import 'app_logger.dart' as app_logger;

/// Сервис для логирования с дополнительными возможностями
class LoggerService {

  LoggerService({Logger? logger}) : _logger = logger ?? app_logger.logger;
  final Logger _logger;

  /// Логирование trace сообщения
  void trace(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Логирование debug сообщения
  void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Логирование info сообщения
  void info(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Логирование warning сообщения
  void warning(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Логирование error сообщения
  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Логирование fatal сообщения
  void fatal(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Логирование с кастомным уровнем
  void log(Level level, String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.log(level, message, error: error, stackTrace: stackTrace);
  }
}

/// Глобальный экземпляр LoggerService
final loggerService = LoggerService();
