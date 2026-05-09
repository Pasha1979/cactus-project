/// Базовый класс для всех исключений в приложении
abstract class AppException implements Exception {
  final String message;
  final int? code;

  const AppException({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Исключение сети (нет интернета, таймаут и т.д.)
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Ошибка сети',
    super.code,
  });
}

/// Исключение сервера (500, 502, 503 и т.д.)
class ServerException extends AppException {
  const ServerException({
    super.message = 'Ошибка сервера',
    super.code,
  });
}

/// Исключение кэша (нет данных в кэше)
class CacheException extends AppException {
  const CacheException({
    super.message = 'Ошибка кэша',
    super.code,
  });
}

/// Исключение валидации данных
class ValidationException extends AppException {
  const ValidationException({
    super.message = 'Ошибка валидации',
    super.code,
  });
}

/// Исключение аутентификации
class AuthenticationException extends AppException {
  const AuthenticationException({
    super.message = 'Ошибка аутентификации',
    super.code,
  });
}

/// Неизвестное исключение
class UnknownException extends AppException {
  const UnknownException({
    super.message = 'Неизвестная ошибка',
    super.code,
  });
}
