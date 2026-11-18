import 'dart:convert';

import '../../data/datasources/remote/plant_remote_datasource.dart';
import '../../domain/repositories/plant_repository.dart';
import '../auth/auth_repository.dart';
import '../logger/app_logger.dart';
import 'migration_backup.dart';
import 'settings_sync_adapter.dart';
import 'sync_engine.dart';
import 'sync_outbox.dart';
import 'sync_state_store.dart';

/// Однократная миграция живой коллекции: локальные данные → Supabase
/// (задача 2.6, R-024/R-026/R-052).
///
/// Источник истины на этом этапе — ЛОКАЛЬНЫЕ данные (Hive plants + prefs).
/// Порядок строгий: backup → bulk enqueue → engine.sync() → серверные
/// stamps/курсоры → флаг done → сверка counts. Идемпотентно: флаг
/// 'migration_v1_done' ставится только после чистого push; при частичном
/// сбое остаток остаётся в outbox и домигрирует следующим запуском.
/// Без аккаунта миграция откладывается (R-008) — флаг не ставится.
class InitialMigration {
  InitialMigration({
    required AuthRepository auth,
    required PlantRepository plants,
    required SyncOutbox outbox,
    required SyncStateStore state,
    required SyncEngine engine,
    required PlantRemoteDataSource remote,
    required MigrationBackup backup,
    required SettingsSyncAdapter settings,
  })  : _auth = auth,
        _plants = plants,
        _outbox = outbox,
        _state = state,
        _engine = engine,
        _remote = remote,
        _backup = backup,
        _settings = settings;

  static const String doneKey = 'migration_v1_done';
  static const String reportKey = 'migration_report';

  final AuthRepository _auth;
  final PlantRepository _plants;
  final SyncOutbox _outbox;
  final SyncStateStore _state;
  final SyncEngine _engine;
  final PlantRemoteDataSource _remote;
  final MigrationBackup _backup;
  final SettingsSyncAdapter _settings;

  bool get isDone => _state.getValue(doneKey) == 'true';

  /// Выполнить миграцию. Возвращает true, если флаг done установлен
  /// (миграция завершена в этом или прежнем запуске).
  Future<bool> run() async {
    if (isDone) {
      AppLogger.api('Миграция v1 уже выполнена — пропуск', tag: 'MIGRATION');
      return true;
    }
    if (_auth.currentUser == null) {
      // Без аккаунта — отложить: данные остаются локально, флаг не ставим.
      AppLogger.api('Нет аккаунта — миграция v1 отложена', tag: 'MIGRATION');
      return false;
    }

    // a) Автобэкап ДО любых сетевых вызовов (R-026)
    final backupPath = await _backup.createBackup();
    AppLogger.api('Бэкап перед миграцией: $backupPath', tag: 'MIGRATION');

    // b/c) Bulk enqueue: все локальные plants + 6 legacy-ключей
    final plants = await _plants.getAllPlants();
    for (final p in plants) {
      await _outbox.enqueue(p.permanentId, SyncOutbox.opUpsert);
    }
    for (final key in SettingsSyncAdapter.syncedKeys) {
      await _outbox.enqueue(
        '${SettingsSyncAdapter.prefix}$key',
        SyncOutbox.opUpsert,
      );
    }

    // d) Push + pull через движок
    await _engine.sync();

    // Частичный сбой: outbox не опустел → флаг не ставим, повтор домигрирует
    if (_outbox.length > 0) {
      AppLogger.error(
        'Миграция v1: push не завершён, осталось ${_outbox.length} записей '
        'в outbox — повторим позже',
        tag: 'MIGRATION',
      );
      return false;
    }

    // e) Серверные last_modified → sync_state['stamp:<id>']
    final remoteRows = await _remote.fetchPlants();
    for (final row in remoteRows) {
      final id = row['permanent_id'] as String?;
      final lm = DateTime.tryParse(row['last_modified']?.toString() ?? '');
      if (id != null && lm != null) {
        await _state.setStamp(id, lm);
      }
    }

    // f) Курсоры = серверное now (rpc sync_now) — свои записи не тянем
    //    обратно как «новые изменения» при следующем pull.
    final serverNow = await _remote.updateLastSync();
    if (serverNow != null) {
      await _state.setPullCursor(serverNow);
      await _state.setSettingsCursor(serverNow);
    }

    // g) Флаг — только после чистого завершения всех шагов
    await _state.setValue(doneKey, 'true');

    // Сверка: counts local vs remote (is_deleted=false) — в отчёт и лог
    await _verify(plants.length, remoteRows.length);

    AppLogger.api('Миграция v1 завершена', tag: 'MIGRATION');
    return true;
  }

  /// Механическое доказательство полноты: counts local vs remote.
  /// Расхождение → AppLogger.error, работа не прерывается (outbox доделает).
  Future<void> _verify(int localPlants, int remotePlants) async {
    var localSettings = 0;
    for (final key in SettingsSyncAdapter.syncedKeys) {
      if (_settings.readLegacy(key) != null) localSettings++;
    }
    var remoteSettings = 0;
    try {
      final page = await _remote.fetchSettingsSince(null, limit: 1000);
      remoteSettings = page.rows.where((r) => r['is_deleted'] != true).length;
    } catch (e, st) {
      AppLogger.warning(
        'Сверка user_settings не удалась: $e',
        tag: 'MIGRATION',
        error: e,
        stackTrace: st,
      );
    }

    final report = {
      'at': DateTime.now().toIso8601String(),
      'plants_local': localPlants,
      'plants_remote': remotePlants,
      'settings_local': localSettings,
      'settings_remote': remoteSettings,
      'ok': localPlants == remotePlants && localSettings == remoteSettings,
    };
    await _state.setValue(reportKey, jsonEncode(report));

    if (report['ok'] == true) {
      AppLogger.api('Сверка миграции OK: $report', tag: 'MIGRATION');
    } else {
      AppLogger.error(
        'Сверка миграции: расхождение $report',
        tag: 'MIGRATION',
      );
    }
  }
}
