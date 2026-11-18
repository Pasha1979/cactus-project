import 'auth_repository.dart';
import 'auth_state.dart';

/// Заглушка реализации AuthRepository поверх Supabase.
///
/// Подключение — задача 2.2. До подключения приложение работает
/// в локальном режиме (R-029: без аккаунта — локальный режим).
class SupabaseAuthRepository implements AuthRepository {
  @override
  Stream<AuthStatus> get authStatusStream =>
      Stream.value(AuthStatus.unauthenticated);

  @override
  AuthUser? get currentUser => null;

  @override
  Future<void> signIn(String email, String password) async {
    throw UnimplementedError('Supabase auth not connected yet');
  }

  @override
  Future<void> signUp(String email, String password) async {
    throw UnimplementedError('Supabase auth not connected yet');
  }

  @override
  Future<void> signOut() async {
    throw UnimplementedError('Supabase auth not connected yet');
  }
}
