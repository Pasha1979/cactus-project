import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Запись архива конфликтов синхронизации.
class SyncConflict {
  const SyncConflict({
    required this.id,
    required this.type,
    required this.permanentId,
    required this.localJson,
    required this.remoteJson,
    required this.at,
  });

  factory SyncConflict.fromJson(Map<String, dynamic> json, {String? id}) =>
      SyncConflict(
        id: id ?? (json['id'] as String? ?? ''),
        type: json['type'] as String,
        permanentId: json['permanentId'] as String,
        localJson: json['localJson'] as Map<String, dynamic>?,
        remoteJson: json['remoteJson'] as Map<String, dynamic>?,
        at: DateTime.tryParse(json['at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Стабильный id записи = ключ в Hive-боксе (`permanentId:micros`).
  /// Нужен UI для удаления конкретной записи (аудит 4.3, H2).
  final String id;

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

  /// Все зафиксированные конфликты — с id для удаления (UI, H2).
  List<SyncConflict> listConflicts() => _box.keys
      .map((k) {
        final raw = _box.get(k);
        if (raw == null) return null;
        return SyncConflict.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
          id: k.toString(),
        );
      })
      .whereType<SyncConflict>()
      .toList();

  Future<void> remove(String key) => _box.delete(key);

  /// Удалить запись по id из [SyncConflict.id] (UI архива, H2).
  Future<void> removeConflict(String id) => _box.delete(id);

  int get length => _box.length;
}
