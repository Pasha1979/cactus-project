import 'package:logger/logger.dart';
import 'failures.dart';
import 'exceptions.dart';

/// Централизованный обработчик ошибок
class ErrorHandler {
  final Logger _logger;

  ErrorHandler({Logger? logger}) : _logger = logger ?? Logger();

  /// Обрабатывает исключение и возвращает соответствующий Failure
  Failure handleException(Exception exception) {
    _logger.e('Exception occurred: $exception');

    if (exception is NetworkException) {
      return const NetworkFailure();
    } else if (exception is ServerException) {
      return const ServerFailure();
    } else if (exception is CacheException) {
      return const CacheFailure();
    } else if (exception is ValidationException) {
      return const ValidationFailure();
    } else if (exception is AuthenticationException) {
      return const AuthenticationFailure();
    } else if (exception is DuplicateIdException) {
      return const DuplicateFailure();
    } else if (exception is OAuth2Exception) {
      return const OAuth2Failure();
    } else {
      return const UnknownFailure();
    }
  }

  /// Логирует ошибку
  void logError(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Логирует предупреждение
  void logWarning(String message, {dynamic error}) {
    _logger.w(message, error: error);
  }

  /// Логирует информационное сообщение
  void logInfo(String message) {
    _logger.i(message);
  }
}
