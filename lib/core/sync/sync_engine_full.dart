import 'dart:async';

import '../../data/datasources/remote/plant_remote_datasource.dart';
import '../../data/mappers/plant_sync_mapper.dart';
import '../../data/models/plant.dart';
import '../../domain/repositories/plant_repository.dart';
import '../auth/auth_repository.dart';
import '../logger/app_logger.dart';
import 'remote_change_applier.dart';
import 'settings_sync_adapter.dart';
import 'sync_conflicts.dart';
import 'sync_engine.dart';
import 'sync_outbox.dart';
import 'sync_state_store.dart';

/// Полный движок синхронизации: push (2.3) + pull (2.4).
///
/// Push: очередь [SyncOutbox] → Supabase; last_modified ставит серверный
/// триггер (R-045). Pull: инкрементальный fetch по серверному курсору,
/// конфликты — LWW по серверному времени, локальная версия архивируется
/// в [SyncConflictStore] (молчаливых потерь нет, R-024/R-046).
/// Без аккаунта — no-op, локальный режим (R-008).
class FullSyncEngine implements SyncEngine {
  FullSyncEngine({
    required SyncOutbox outbox,
    required PlantRemoteDataSource remote,
    required PlantRepository plants,
    required AuthRepository auth,
    required SyncStateStore state,
    required SyncConflictStore conflicts,
    required SettingsSyncAdapter settings,
    RemoteChangeApplier? applier,
    int pageLimit = 1000,
  })  : _outbox = outbox,
        _remote = remote,
        _plants = plants,
        _auth = auth,
        _state = state,
        _conflicts = conflicts,
        _settings = settings,
        _applier = applier,
        _pageLimit = pageLimit;

  final SyncOutbox _outbox;
  final PlantRemoteDataSource _remote;
  final PlantRepository _plants;
  final AuthRepository _auth;
  final SyncStateStore _state;
  final SyncConflictStore _conflicts;
  final SettingsSyncAdapter _settings;
  final RemoteChangeApplier? _applier;
  final int _pageLimit;

  /// Коллбек после успешного pull — перезагрузка провайдеров (задача 2.4, п.4).
  /// Регистрируется в main.dart; UI не трогаем.
  Future<void> Function()? onPullComplete;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.idle;

  @override
  Stream<SyncStatus> get syncStatusStream => _statusController.stream;

  SyncStatus get currentStatus => _currentStatus;

  void _setStatus(SyncStatus s) {
    _currentStatus = s;
    _statusController.add(s);
  }

  /// Полный цикл: push → pull.
  @override
  Future<void> sync() async {
    await pushLocalChanges();
    await pullRemoteChanges();
  }

  // ==================== PUSH (задача 2.3) ====================

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
        // Записи настроек: 'settings:<PrefsKey>' → user_settings (2.4б)
        if (SettingsSyncAdapter.isSettingId(entry.recordId)) {
          if (entry.op == SyncOutbox.opDelete) {
            await _remote.upsertSetting({
              'key': SettingsSyncAdapter.settingKey(entry.recordId),
              'value': null,
              'is_deleted': true,
            });
          } else {
            await _remote.upsertSetting(
              _settings.toRow(SettingsSyncAdapter.settingKey(entry.recordId), user.id),
            );
          }
        } else if (entry.op == SyncOutbox.opDelete) {
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

  // ==================== PULL (задача 2.4) ====================

  @override
  Future<void> pullRemoteChanges() async {
    // Локальный режим: без аккаунта — no-op (R-008)
    if (_auth.currentUser == null) {
      _setStatus(SyncStatus.idle);
      return;
    }

    _setStatus(SyncStatus.syncing);
    var hadError = false;

    try {
      // Курсор — только серверное время (R-046)
      var cursor = _state.pullCursor;
      while (true) {
        final page = await _remote.fetchChangesSince(cursor, limit: _pageLimit);
        for (final row in page.rows) {
          await _applyRemoteRow(row);
        }
        if (page.newCursor != null) {
          cursor = page.newCursor;
          await _state.setPullCursor(page.newCursor!);
        }
        if (page.rows.length < _pageLimit) break; // страница неполная — конец
      }

      // Настройки: отдельный курсор settings_cursor (2.4б)
      var scur = _state.settingsCursor;
      while (true) {
        final page =
            await _remote.fetchSettingsSince(scur, limit: _pageLimit);
        for (final row in page.rows) {
          await _applySettingRow(row);
        }
        if (page.newCursor != null) {
          scur = page.newCursor;
          await _state.setSettingsCursor(page.newCursor!);
        }
        if (page.rows.length < _pageLimit) break;
      }

      await onPullComplete?.call();
    } catch (e, st) {
      hadError = true;
      AppLogger.error('Pull не удался', tag: 'SYNC', error: e, stackTrace: st);
    }

    _setStatus(hadError ? SyncStatus.error : SyncStatus.idle);
  }

  /// Применить одну удалённую строку с правилами LWW + архив конфликтов.
  Future<void> _applyRemoteRow(Map<String, dynamic> row) async {
    final permanentId = row['permanent_id'] as String;
    final isDeleted = row['is_deleted'] == true;
    final remoteStamp = DateTime.parse(row['last_modified'] as String);
    final localDirty = _outbox.contains(permanentId);
    final storedStamp = _state.stampFor(permanentId);

    if (isDeleted) {
      // Tombstone: удаление побеждает. Грязную локальную копию — в архив.
      if (localDirty) {
        final local = await _plants.getPlantById(permanentId);
        await _conflicts.archive(
          type: 'delete_vs_edit',
          permanentId: permanentId,
          localJson: local?.toJson(),
          remoteJson: row,
        );
      }
      await _applyDelete(permanentId);
      await _outbox.remove(permanentId);
      await _state.setStamp(permanentId, remoteStamp);
      return;
    }

    if (!localDirty) {
      // Локальная не грязная → просто применить remote.
      await _applyUpsert(plantFromSyncRow(row));
      await _state.setStamp(permanentId, remoteStamp);
      return;
    }

    if (storedStamp != null && !remoteStamp.isAfter(storedStamp)) {
      // remote не новее последней синхронизированной версии →
      // оставить local (она уйдёт в push).
      return;
    }

    // remoteStamp > storedStamp (или записи ещё не было на сервере,
    // а remote существует) → КОНФЛИКТ: remote побеждает по LWW,
    // локальная версия — в архив (молчаливой потери нет, R-024).
    final local = await _plants.getPlantById(permanentId);
    await _conflicts.archive(
      type: 'edit_vs_edit',
      permanentId: permanentId,
      localJson: local?.toJson(),
      remoteJson: row,
    );
    await _applyUpsert(plantFromSyncRow(row));
    await _outbox.remove(permanentId); // remote применён — push не нужен
    await _state.setStamp(permanentId, remoteStamp);
  }

  /// Применить строку user_settings: tombstone → удалить ключ,
  /// иначе записать значение в prefs (провайдеры перечитают в onPullComplete).
  Future<void> _applySettingRow(Map<String, dynamic> row) async {
    final key = row['key'] as String;
    if (row['is_deleted'] == true) {
      await _settings.removeLegacy(key);
    } else {
      await _settings.writeLegacy(key, row['value']);
    }
  }

  Future<void> _applyUpsert(Plant plant) async {
    final applier = _applier;
    if (applier != null) {
      await applier.applyUpsert(plant);
      return;
    }
    // Fallback без провайдера (тесты): прямая запись в репозиторий
    final existing = await _plants.getPlantById(plant.permanentId);
    if (existing == null) {
      await _plants.addPlant(plant);
    } else {
      await _plants.updatePlant(plant);
    }
  }

  Future<void> _applyDelete(String permanentId) async {
    final applier = _applier;
    if (applier != null) {
      await applier.applyDelete(permanentId);
      return;
    }
    await _plants.deletePlant(permanentId);
  }
}
