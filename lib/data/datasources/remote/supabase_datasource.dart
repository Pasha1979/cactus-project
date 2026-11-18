/// Удалённый источник данных Supabase (заглушка).
///
/// Записи (растения, поливы, заметки и т.д.) — в Supabase (R-003/R-030).
/// Фото — отдельно на Яндекс.Диске. Подключение — задача 2.2.
class SupabaseDatasource {
  Future<List<Map<String, dynamic>>> fetchPlants() async {
    throw UnimplementedError('Supabase not connected yet');
  }

  Future<void> uploadPlant(Map<String, dynamic> plant) async {
    throw UnimplementedError('Supabase not connected yet');
  }
}
