import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import 'sync_engine.dart';

/// Точки входа синхронизации из кода верхнего уровня (задача 2.5).
///
/// Старт приложения и кнопка «Синхр.» вызывают один движок.
/// Без аккаунта движок сам делает no-op (R-008); для кнопки
/// состояние аккаунта проверяется до вызова — честный UI (R-051).
class SyncActions {
  SyncActions(this._engine, this._auth);

  final SyncEngine _engine;
  final AuthRepository _auth;

  /// Вошёл ли пользователь в Supabase-аккаунт.
  bool get hasAccount => _auth.currentUser != null;

  /// Стартовый sync после загрузки провайдеров (тихий, без SnackBar).
  Future<void> startup() => _engine.sync();

  /// Ручной sync по кнопке «Синхр.».
  Future<void> manual() => _engine.sync();
}

/// Честная обратная связь по кнопке «Синхр.» через существующие SnackBar
/// (задача 2.5б, R-051): без аккаунта — оранжевый, ошибка — красный,
/// успех — зелёный. Логика самой синхронизации не меняется.
Future<void> handleManualSync(BuildContext context, SyncActions actions) async {
  final messenger = ScaffoldMessenger.of(context);

  if (!actions.hasAccount) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Войдите в аккаунт, чтобы синхронизировать'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  messenger.showSnackBar(
    const SnackBar(content: Text('🔄 Синхронизация началась...')),
  );

  try {
    await actions.manual();
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('✅ Синхронизация успешно завершена'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    final msg = e.toString();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Ошибка синхронизации: ${msg.length > 50 ? msg.substring(0, 50) : msg}',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}
