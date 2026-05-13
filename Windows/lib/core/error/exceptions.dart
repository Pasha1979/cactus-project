/// Базовый класс для всех исключений в приложении
abstract class AppException implements Exception {

  const AppException({
    required this.message,
    this.code,
  });
  final String message;
  final int? code;

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

/// Дублированный ID
class DuplicateIdException extends AppException {
  const DuplicateIdException({
    super.message = 'Дублированный идентификатор',
    super.code = 409,
  });
}

/// Ошибка OAuth2 аутентификации
class OAuth2Exception extends AppException {
  const OAuth2Exception({
    super.message = 'Ошибка OAuth2 аутентификации',
    super.code = 401,
  });
}

/// Неизвестное исключение
class UnknownException extends AppException {
  const UnknownException({
    super.message = 'Неизвестная ошибка',
    super.code,
  });
}
