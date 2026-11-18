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

  /// Штамп последней синхронизации для инкрементального pull (задача 2.4).
  @override
  Future<void> updateLastSync() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Нет авторизованного пользователя для updateLastSync');
    }
    await _client.from('sync_metadata').upsert(
      {'user_id': userId, 'last_sync_at': DateTime.now().toIso8601String()},
      onConflict: 'user_id',
    );
  }
}
