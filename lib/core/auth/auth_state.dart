/// Статус аутентификации пользователя (R-029: почта + пароль).
enum AuthStatus { unauthenticated, authenticating, authenticated }

/// Пользователь системы аутентификации.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.createdAt,
  });

  final String id;
  final String email;
  final DateTime createdAt;
}
