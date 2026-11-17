import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/services/api/gbif_service.dart';

/// Тестовый скрипт для проверки GBIF API
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
        }
        
        print('\n📈 Итого:');
        print('  🌍 Occurrence с координатами: $totalOccurrences');
        print('  📸 Всего фото: $totalPhotos');
        
        // Тестируем нашу функцию
        print('\n🔧 Тест нашей функции fetchGbifData:');
        final gbifData = await GbifService().fetchGbifData(testPlant);
        
        if (gbifData != null) {
          print('✅ Данные получены:');
          print('  📍 Страна: ${gbifData['gbifCountry']}');
          print('  🌍 Ареал: ${gbifData['gbifHabitat']}');
          print('  📸 Фото GBIF: ${gbifData['gbifPhotoUrls']?.length ?? 0}');
          print('  🎯 Occurrence: ${gbifData['gbifOccurrences']?.length ?? 0}');
          print('  📝 Синонимы: ${gbifData['gbifSynonyms']}');
          
          if (gbifData['gbifPhotoUrls'] != null) {
            print('\n📸 Список фото:');
            final photoUrls = gbifData['gbifPhotoUrls'] as List<String>;
            for (int i = 0; i < photoUrls.length; i++) {
              print('  📸 Фото #$i: ${photoUrls[i]}');
            }
          }
        } else {
          print('❌ Наша функция вернула null');
        }
      }
    } else {
      print('❌ Ошибка HTTP: ${response.statusCode}');
      print('📄 Ответ: ${response.body}');
    }
  } catch (e) {
    print('❌ Ошибка: $e');
  }
}
