import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/models/plant.dart';
import '../../domain/repositories/plant_repository.dart';
import 'settings_sync_adapter.dart';
import 'sync_state_store.dart';

/// Автобэкап локальных данных перед миграцией на Supabase (задача 2.6, R-026).
///
/// Выгружает ВСЕ локальные plants + 6 legacy-ключей prefs в один JSON-файл
/// в каталоге документов приложения. Путь сохраняется в
/// sync_state['migration_backup_path'] — точка восстановления для rollback.
/// Файл не удаляется автоматически — ручной откат всегда возможен.
class MigrationBackup {
  MigrationBackup({
    required PlantRepository plants,
    required SettingsSyncAdapter settings,
    required SyncStateStore state,
    Future<Directory> Function()? docsDir,
  })  : _plants = plants,
        _settings = settings,
        _state = state,
        _docsDir = docsDir ?? getApplicationDocumentsDirectory;

  final PlantRepository _plants;
  final SettingsSyncAdapter _settings;
  final SyncStateStore _state;
  final Future<Directory> Function() _docsDir;

  /// Создать бэкап: все plants + legacy-ключи → JSON-файл.
  /// Возвращает абсолютный путь к файлу.
  Future<String> createBackup() async {
    final plants = await _plants.getAllPlants();
    final legacy = <String, dynamic>{
      for (final key in SettingsSyncAdapter.syncedKeys)
        key: _settings.readLegacy(key),
    };

    final payload = {
      'version': 1,
      'created_at': DateTime.now().toIso8601String(),
      'plants': plants.map((p) => p.toJson()).toList(),
      'legacy': legacy,
    };

    final dir = await _docsDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/migration_backup_$ts.json');
    await file.writeAsString(jsonEncode(payload));
    await _state.setValue('migration_backup_path', file.path);
    return file.path;
  }

  /// Откат: восстановить plants (putAll) и legacy-ключи из файла бэкапа,
  /// сбросить флаг migration_v1_done — миграция сможет повториться.
  /// writeLegacy идёт напрямую в prefs (без _save-хуков) — ре-enqueue нет.
  Future<void> rollback(String backupPath) async {
    final raw = await File(backupPath).readAsString();
    final payload = jsonDecode(raw) as Map<String, dynamic>;

    for (final j in (payload['plants'] as List? ?? const [])) {
      final plant = Plant.fromJson(j as Map<String, dynamic>);
      final existing = await _plants.getPlantById(plant.permanentId);
      if (existing == null) {
        await _plants.addPlant(plant);
      } else {
        await _plants.updatePlant(plant);
      }
    }

    final legacy = payload['legacy'] as Map<String, dynamic>? ?? const {};
    for (final entry in legacy.entries) {
      await _settings.writeLegacy(entry.key, entry.value);
    }

    await _state.removeValue('migration_v1_done');
  }
}
