import 'auth_state.dart';

/// Интерфейс репозитория аутентификации.
///
/// Реализация — Supabase (R-003/R-029, европейский ДЦ R-030).
abstract class AuthRepository {
  Stream<AuthStatus> get authStatusStream;
  AuthUser? get currentUser;

  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();
}
