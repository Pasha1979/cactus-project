import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

/// Удалённый источник данных Supabase (записи растений, R-003).
///
/// Фото синхронизируются отдельно через Яндекс.Диск (задача 2.5).
class SupabaseDatasource {
  SupabaseClient get _client => SupabaseClientManager.client;

  /// Все неудалённые растения текущего пользователя (RLS фильтрует по user_id).
  Future<List<Map<String, dynamic>>> fetchPlants() async {
    final response = await _client
        .from('plants')
        .select()
        .eq('is_deleted', false)
        .order('last_modified', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Upsert записи: конфликт по паре (user_id, permanent_id) — идемпотентно.
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
  Future<void> deletePlant(String plantId) async {
    await _client
        .from('plants')
        .update({
          'is_deleted': true,
          'last_modified': DateTime.now().toIso8601String(),
        })
        .eq('permanent_id', plantId);
  }
}
