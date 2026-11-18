import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_cactus/core/auth/auth_repository.dart';
import 'package:my_cactus/core/auth/auth_state.dart';
import 'package:my_cactus/core/sync/sync_actions.dart';
import 'package:my_cactus/core/sync/sync_engine.dart';

// ==================== FAKES ====================

class FakeEngine implements SyncEngine {
  var syncCalls = 0;
  Object? error;

  @override
  Stream<SyncStatus> get syncStatusStream => const Stream.empty();

  @override
  Future<void> sync() async {
    syncCalls++;
    if (error != null) throw error!;
  }

  @override
  Future<void> pushLocalChanges() async {}

  @override
  Future<void> pullRemoteChanges() async {}
}

class FakeAuth implements AuthRepository {
  AuthUser? user;
  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthStatus> get authStatusStream => const Stream.empty();
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password) async {}
  @override
  Future<void> signOut() async {}
}

// ==================== HELPERS ====================

Widget _appWithSyncButton(SyncActions actions) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => handleManualSync(context, actions),
          child: const Text('Синхр.'),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeEngine engine;
  late FakeAuth auth;

  setUp(() {
    engine = FakeEngine();
    auth = FakeAuth();
  });

  // u1: кнопка без аккаунта → оранжевый SnackBar, sync() НЕ вызван
  testWidgets('u1: без аккаунта — оранжевый SnackBar, sync не вызван',
      (tester) async {
    auth.user = null;
    await tester
        .pumpWidget(_appWithSyncButton(SyncActions(engine, auth)));
    await tester.tap(find.text('Синхр.'));
    await tester.pump();

    expect(engine.syncCalls, 0);
    expect(find.text('Войдите в аккаунт, чтобы синхронизировать'),
        findsOneWidget);
  });

  // u2: кнопка с аккаунтом, engine бросает → красный SnackBar
  testWidgets('u2: ошибка engine — красный SnackBar с причиной',
      (tester) async {
    auth.user = AuthUser(id: 'u1', email: 't@t.t', createdAt: DateTime(2026));
    engine.error = Exception('network timeout');
    await tester
        .pumpWidget(_appWithSyncButton(SyncActions(engine, auth)));
    await tester.tap(find.text('Синхр.'));
    await tester.pumpAndSettle();

    expect(engine.syncCalls, 1);
    expect(
      find.textContaining('Ошибка синхронизации: Exception: network'),
      findsOneWidget,
    );
  });

  // u3: кнопка с аккаунтом, успех → зелёный SnackBar
  testWidgets('u3: успех — зелёный SnackBar «успешно завершена»',
      (tester) async {
    auth.user = AuthUser(id: 'u1', email: 't@t.t', createdAt: DateTime(2026));
    await tester
        .pumpWidget(_appWithSyncButton(SyncActions(engine, auth)));
    await tester.tap(find.text('Синхр.'));
    await tester.pumpAndSettle();

    expect(engine.syncCalls, 1);
    expect(find.text('✅ Синхронизация успешно завершена'), findsOneWidget);
  });
}
