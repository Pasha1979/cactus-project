import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Запись архива конфликтов синхронизации.
class SyncConflict {
  const SyncConflict({
    required this.type,
    required this.permanentId,
    required this.localJson,
    required this.remoteJson,
    required this.at,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json) => SyncConflict(
        type: json['type'] as String,
        permanentId: json['permanentId'] as String,
        localJson: json['localJson'] as Map<String, dynamic>?,
        remoteJson: json['remoteJson'] as Map<String, dynamic>?,
        at: DateTime.tryParse(json['at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// 'edit_vs_edit' | 'delete_vs_edit'
  final String type;

  /// permanentId конфликтующей записи.
  final String permanentId;

  /// Локальная версия (сохранена — молчаливых потерь нет, R-024).
  final Map<String, dynamic>? localJson;

  /// Удалённая версия, которая победила по LWW.
  final Map<String, dynamic>? remoteJson;

  /// Когда зафиксирован конфликт.
  final DateTime at;
}

/// Архив конфликтов (Hive-бокс 'sync_conflicts', Box<String>, JSON).
///
/// При конфликте удалённая версия применяется (LWW по серверному
/// last_modified), а локальная архивируется сюда — для восстановления
/// через UI в задаче 2.5 (молчаливых потерь нет, R-024).
class SyncConflictStore {
  SyncConflictStore(this._box);

  final Box<String> _box;

  Future<void> archive({
    required String type,
    required String permanentId,
    Map<String, dynamic>? localJson,
    Map<String, dynamic>? remoteJson,
  }) =>
      _box.put(
        '$permanentId:${DateTime.now().microsecondsSinceEpoch}',
        jsonEncode({
          'type': type,
          'permanentId': permanentId,
          'localJson': localJson,
          'remoteJson': remoteJson,
          'at': DateTime.now().toIso8601String(),
        }),
      );

  /// Все зафиксированные конфликты (для UI в задаче 2.5).
  List<SyncConflict> listConflicts() => _box.keys
      .map((k) => _box.get(k))
      .whereType<String>()
      .map((s) => SyncConflict.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();

  Future<void> remove(String key) => _box.delete(key);

  int get length => _box.length;
}
