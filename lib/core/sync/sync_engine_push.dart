import 'dart:async';

import '../../data/datasources/remote/plant_remote_datasource.dart';
import '../../data/mappers/plant_sync_mapper.dart';
import '../../domain/repositories/plant_repository.dart';
import '../auth/auth_repository.dart';
import '../logger/app_logger.dart';
import 'sync_engine.dart';
import 'sync_outbox.dart';

/// Push-реализация SyncEngine (задача 2.3).
///
/// Отправляет очередь [SyncOutbox] в Supabase с серверным временем
/// (триггер миграции 00002). Без аккаунта — no-op, локальный режим (R-008).
/// pullRemoteChanges — заглушка до задачи 2.4.
class PushSyncEngine implements SyncEngine {
  PushSyncEngine({
    required SyncOutbox outbox,
    required PlantRemoteDataSource remote,
    required PlantRepository plants,
    required AuthRepository auth,
  })  : _outbox = outbox,
        _remote = remote,
        _plants = plants,
        _auth = auth;

  final SyncOutbox _outbox;
  final PlantRemoteDataSource _remote;
  final PlantRepository _plants;
  final AuthRepository _auth;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.idle;

  @override
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  /// Текущий статус (для опроса без подписки на стрим).
  SyncStatus get currentStatus => _currentStatus;

  void _setStatus(SyncStatus s) {
    _currentStatus = s;
    _statusController.add(s);
  }

  /// Полный цикл синхронизации: push → pull.
  /// Pull добавится в задаче 2.4 — пока только push.
  @override
  Future<void> sync() => pushLocalChanges();

  @override
  Future<void> pushLocalChanges() async {
    // Локальный режим: без аккаунта синхронизация — no-op (R-008)
    final user = _auth.currentUser;
    if (user == null) {
      _setStatus(SyncStatus.idle);
      return;
    }

    _setStatus(SyncStatus.syncing);
    var hadError = false;

    for (final entry in _outbox.pending()) {
      try {
        if (entry.op == SyncOutbox.opDelete) {
          await _remote.deletePlant(entry.recordId);
        } else {
          final plant = await _plants.getPlantById(entry.recordId);
          if (plant == null) {
            // Запись исчезла локально — преобразуем в удаление
            await _remote.deletePlant(entry.recordId);
          } else {
            // last_modified в строке отсутствует — ставит сервер (R-045)
            await _remote.uploadPlant(plantToSyncRow(plant, user.id));
          }
        }
        await _outbox.remove(entry.recordId);
      } catch (e, st) {
        hadError = true;
        AppLogger.error(
          'Push ${entry.op} ${entry.recordId} не удался — остаётся в outbox',
          tag: 'SYNC',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (!hadError) {
      try {
        await _remote.updateLastSync();
      } catch (e, st) {
        AppLogger.warning(
          'Не удалось обновить sync_metadata: $e',
          tag: 'SYNC',
          error: e,
          stackTrace: st,
        );
      }
    }

    _setStatus(hadError ? SyncStatus.error : SyncStatus.idle);
  }

  @override
  Future<void> pullRemoteChanges() async {
    throw UnimplementedError('pull — задача 2.4');
  }
}
