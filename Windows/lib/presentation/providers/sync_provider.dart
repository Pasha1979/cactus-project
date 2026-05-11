import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logger/app_logger.dart';
import 'plant_crud_provider.dart';

/// Провайдер для синхронизации и бэкапа данных
///
/// Отвечает за:
/// - Создание локального бэкапа
/// - Восстановление из бэкапа
/// - Экспорт/импорт JSON
class SyncProvider with ChangeNotifier {
  // TODO(1.15.1): подключить SyncRepository через DI
  // final SyncRepository _repository = sl<SyncRepository>();

  DateTime? _lastLocalUpdate;
  final bool _isSyncing = false;

  DateTime? get lastLocalUpdate => _lastLocalUpdate;
  bool get isSyncing => _isSyncing;

  void setLastLocalUpdate(DateTime date) {
    _lastLocalUpdate = date;
    notifyListeners();
  }

  // ==================== ЛОКАЛЬНЫЙ БЭКАП ====================
  Future<String> getBackupFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/plant_photos/plant_provider_backup.json';
  }

  Future<void> createLocalBackup(Map<String, dynamic> data) async {
    try {
      final backupPath = await getBackupFilePath();
      final file = File(backupPath);
      await file.writeAsString(jsonEncode(data));
      logger.d('Локальный бэкап создан: $backupPath');
    } catch (e) {
      logger.d('Ошибка создания бэкапа: $e');
    }
  }

  Future<Map<String, dynamic>?> loadLocalBackup() async {
    try {
      final backupPath = await getBackupFilePath();
      final file = File(backupPath);
      if (!await file.exists()) return null;
      final json = await file.readAsString();
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      logger.d('Ошибка загрузки бэкапа: $e');
      return null;
    }
  }

  /// Восстановить данные из локального бэкапа через PlantCrudProvider
  Future<bool> restoreFromLocalBackup(PlantCrudProvider plantCrudProvider) async {
    try {
      final data = await loadLocalBackup();
      if (data == null) {
        logger.d('Бэкап-файл не найден');
        return false;
      }
      await plantCrudProvider.loadFromCloudJson(data);
      logger.d('✅ Данные успешно восстановлены из локального бэкапа');
      return true;
    } catch (e) {
      logger.d('❌ Ошибка восстановления из бэкапа: $e');
      return false;
    }
  }
}
