/// Статус аутентификации пользователя (R-029: почта + пароль).
enum AuthStatus { unauthenticated, authenticating, authenticated }

/// Пользователь системы аутентификации.
class AuthUser {
  final String id;
  final String email;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    required this.createdAt,
  });
}
