import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../supabase_client.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

/// Реализация [AuthRepository] на Supabase Auth (почта + пароль, R-029).
class SupabaseAuthRepository implements AuthRepository {
  final _authStatusController = StreamController<AuthStatus>.broadcast();

  SupabaseClient get _client => SupabaseClientManager.client;

  @override
  Stream<AuthStatus> get authStatusStream => _authStatusController.stream;

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    );
  }

  @override
  Future<void> signIn(String email, String password) async {
    _authStatusController.add(AuthStatus.authenticating);
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      _authStatusController.add(AuthStatus.authenticated);
    } catch (e) {
      _authStatusController.add(AuthStatus.unauthenticated);
      rethrow;
    }
  }

  @override
  Future<void> signUp(String email, String password) async {
    _authStatusController.add(AuthStatus.authenticating);
    try {
      await _client.auth.signUp(email: email, password: password);
      _authStatusController.add(AuthStatus.authenticated);
    } catch (e) {
      _authStatusController.add(AuthStatus.unauthenticated);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _authStatusController.add(AuthStatus.unauthenticated);
  }

  void dispose() {
    _authStatusController.close();
  }
}
