import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Запись журнала несинхронизированных изменений.
class OutboxEntry {
  const OutboxEntry({
    required this.recordId,
    required this.op,
    required this.queuedAt,
  });

  factory OutboxEntry.fromJson(Map<String, dynamic> json) => OutboxEntry(
        recordId: json['id'] as String,
        op: json['op'] as String,
        queuedAt: DateTime.tryParse(json['queuedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// permanentId записи.
  final String recordId;

  /// 'upsert' | 'delete'
  final String op;

  /// Когда изменение поставлено в очередь.
  final DateTime queuedAt;
}

/// Outbox — надёжная очередь локальных изменений для push (задача 2.3).
///
/// Ключ бокса = recordId: повторный enqueue перезаписывает запись,
/// 'delete' имеет приоритет над 'upsert' (delete не отменяется upsert'ом).
/// Хранит JSON {id, op, queuedAt} в Hive-боксе 'sync_outbox'.
class SyncOutbox {
  SyncOutbox(this._box);

  static const String opUpsert = 'upsert';
  static const String opDelete = 'delete';

  final Box<String> _box;

  /// Поставить изменение в очередь. Если уже стоит 'delete' —
  /// 'upsert' его не отменяет (приоритет удаления).
  Future<void> enqueue(String recordId, String op) async {
    final existing = _box.get(recordId);
    if (existing != null) {
      final cur = jsonDecode(existing) as Map<String, dynamic>;
      if (cur['op'] == opDelete && op == opUpsert) return;
    }
    await _box.put(
      recordId,
      jsonEncode({
        'id': recordId,
        'op': op,
        'queuedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// Все записи в очереди (в порядке вставки ключей).
  List<OutboxEntry> pending() => _box.keys
      .map((k) => _box.get(k))
      .whereType<String>()
      .map((s) => OutboxEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();

  /// Снять запись с очереди после успешной отправки.
  Future<void> remove(String recordId) => _box.delete(recordId);

  int get length => _box.length;
}
