import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import 'plant_remote_datasource.dart';

/// Удалённый источник данных Supabase (записи растений, R-003).
///
/// Фото синхронизируются отдельно через Яндекс.Диск (задача 2.5).
class SupabaseDatasource implements PlantRemoteDataSource {
  SupabaseClient get _client => SupabaseClientManager.client;

  /// Все неудалённые растения текущего пользователя (RLS фильтрует по user_id).
  @override
  Future<List<Map<String, dynamic>>> fetchPlants() async {
    final response = await _client
        .from('plants')
        .select()
        .eq('is_deleted', false)
        .order('last_modified', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Upsert записи: конфликт по паре (user_id, permanent_id) — идемпотентно.
  /// 'last_modified' в строке отсутствует — его ставит серверный триггер (R-045).
  @override
  Future<void> uploadPlant(Map<String, dynamic> plant) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Нет авторизованного пользователя для uploadPlant');
    }
    await _client.from('plants').upsert(
      {...plant, 'user_id': userId},
      onConflict: 'user_id,permanent_id',
    );
  }

  /// Мягкое удаление (tombstone) — для синхронизации удалений.
  @override
  Future<void> deletePlant(String plantId) async {
    await _client
        .from('plants')
        .update({'is_deleted': true})
        .eq('permanent_id', plantId);
  }

  /// Штамп последней синхронизации для инкрементального pull.
  ///
  /// Серверное время берём из триггерного `last_modified` свежайшей строки
  /// plants (PostgREST не умеет `SET x = now()`, а новых миграций/rpc в 2.4
  /// нет — R-046). Клиентское время не используется.
  @override
  Future<DateTime?> updateLastSync() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Нет авторизованного пользователя для updateLastSync');
    }
    final newest = await _client
        .from('plants')
        .select('last_modified')
        .order('last_modified', ascending: false)
        .limit(1)
        .maybeSingle();
    if (newest == null) return null; // таблица пуста — нечем проставить
    final serverStamp = DateTime.parse(newest['last_modified'] as String);
    await _client.from('sync_metadata').upsert(
      {'user_id': userId, 'last_sync_at': serverStamp.toIso8601String()},
      onConflict: 'user_id',
    );
    return serverStamp;
  }

  /// Инкрементальная выборка изменений для pull (R-046).
  /// Включает tombstones — фильтра по is_deleted нет намеренно.
  @override
  Future<RemoteChangesPage> fetchChangesSince(
    DateTime? cursor, {
    int limit = 1000,
  }) async {
    final base = _client.from('plants').select();
    final filtered = cursor == null
        ? base
        : base.gt('last_modified', cursor.toIso8601String());
    final response = await filtered
        .order('last_modified', ascending: true)
        .limit(limit);
    final rows = List<Map<String, dynamic>>.from(response);
    final newCursor = rows.isEmpty
        ? null
        : DateTime.parse(rows.last['last_modified'] as String);
    return RemoteChangesPage(rows: rows, newCursor: newCursor);
  }
}
