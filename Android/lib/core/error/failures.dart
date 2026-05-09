/// Абстрактный класс для всех ошибок в приложении
abstract class Failure {
  final String message;
  final int? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'Failure: $message (code: $code)';
}

/// Ошибка сети (нет интернета, таймаут и т.д.)
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Ошибка сети',
    super.code,
  });
}

/// Ошибка сервера (500, 502, 503 и т.д.)
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Ошибка сервера',
    super.code,
  });
}

/// Ошибка кэша (нет данных в кэше)
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Ошибка кэша',
    super.code,
  });
}

/// Ошибка валидации данных
class ValidationFailure extends Failure {
  const ValidationFailure({
    super.message = 'Ошибка валидации',
    super.code,
  });
}

/// Ошибка аутентификации
class AuthenticationFailure extends Failure {
  const AuthenticationFailure({
    super.message = 'Ошибка аутентификации',
    super.code,
  });
}

/// Неизвестная ошибка
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Неизвестная ошибка',
    super.code,
  });
}
