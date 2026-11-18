import 'sync_engine.dart';

/// Точки входа синхронизации из кода верхнего уровня (задача 2.5).
///
/// Старт приложения и кнопка «Синхр.» вызывают один движок.
/// Без аккаунта движок сам делает no-op (R-008).
class SyncActions {
  SyncActions(this._engine);

  final SyncEngine _engine;

  /// Стартовый sync после загрузки провайдеров.
  Future<void> startup() => _engine.sync();

  /// Ручной sync по кнопке «Синхр.».
  Future<void> manual() => _engine.sync();
}
