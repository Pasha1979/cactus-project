import 'dart:convert';
import 'package:http/http.dart' as http;

/// Простой тест GBIF API без Flutter зависимостей
void main() async {
  print('🌍 Тестирование GBIF API...\n');
  
  // Тестируем с известным кактусом
  final testPlant = 'Astrophytum asterias';
  
  print('🔍 Поиск данных для: $testPlant');
  
  try {
    // Прямой запрос к GBIF API
    final baseUrl = 'https://api.gbif.org/v1/occurrence/search';
    final scientificName = testPlant.replaceAll(' ', '+');
    final url = Uri.parse('$baseUrl?scientificName=$scientificName&limit=10&hasCoordinate=true');
    
    print('📡 Запрос: $url');
    
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      final count = data['count'] as int? ?? 0;
      
      print('✅ Найдено записей: $count');
      print('📊 Результатов в ответе: ${results?.length ?? 0}');
      
      if (results != null && results.isNotEmpty) {
        print('\n📸 Анализ фото в результатах:');
        
        int totalPhotos = 0;
        int totalOccurrences = 0;
        
        for (int i = 0; i < results.length; i++) {
          final result = results[i] as Map<String, dynamic>;
          
          // Проверяем координаты
          final lat = result['decimalLatitude'];
          final lng = result['decimalLongitude'];
          final hasCoords = lat != null && lng != null;
          
          if (hasCoords) {
            totalOccurrences++;
          }
          
          // Проверяем фото
          final media = result['media'] as List<dynamic>?;
          int photoCount = 0;
          
          if (media != null && media.isNotEmpty) {
            for (final mediaItem in media) {
              if (mediaItem is Map<String, dynamic> && 
                  mediaItem['type'] == 'StillImage') {
                photoCount++;
                totalPhotos++;
                final identifier = mediaItem['identifier'] as String?;
                print('  📸 Фото #$photoCount: $identifier');
              }
            }
          }
          
          print('  📍 Запись #$i: координаты=$hasCoords, фото=$photoCount');
          
          // Показываем полную структуру для первой записи
          if (i == 0) {
            print('\n🔍 Структура первой записи:');
            print('  📄 Все поля: ${result.keys.toList()}');
            if (media != null) {
              print('  📸 Структура media:');
              for (int j = 0; j < media.length; j++) {
                final mediaItem = media[j];
                if (mediaItem is Map<String, dynamic>) {
                  print('    📸 Media #$j: ${mediaItem.keys.toList()}');
                  if (mediaItem['type'] == 'StillImage') {
                    print('      📸 URL: ${mediaItem['identifier']}');
                  }
                }
              }
            }
          }
        }
        
        print('\n📈 Итого:');
        print('  🌍 Occurrence с координатами: $totalOccurrences');
        print('  📸 Всего фото: $totalPhotos');
      }
    } else {
      print('❌ Ошибка HTTP: ${response.statusCode}');
      print('📄 Ответ: ${response.body}');
    }
  } catch (e) {
    print('❌ Ошибка: $e');
  }
}
