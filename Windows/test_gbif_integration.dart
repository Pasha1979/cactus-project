import 'lib/services/api/gbif_service.dart';
import 'lib/services/api/llifle_service.dart';

/// Тест интеграции GBIF с полной цепочкой обработки
void main() async {
  print('🌍 Тест полной интеграции GBIF...\n');
  
  final testPlant = 'Astrophytum asterias';
  print('🔍 Тестирование: $testPlant\n');
  
  try {
    // Шаг 1: Прямой запрос к GBIF API
    print('📡 Шаг 1: Прямой запрос к GBIF API');
    final gbifData = await GbifService().fetchGbifData(testPlant);
    
    if (gbifData != null) {
      print('✅ GBIF данные получены:');
      print('  📸 Фото: ${gbifData['gbifPhotoCount']}');
      print('  📍 Occurrence: ${gbifData['gbifOccurrenceCount']}');
      print('  🇺🇸 Страна: ${gbifData['gbifCountry']}');
      print('  📝 Синонимы: ${gbifData['gbifSynonyms']}');
      print('  🌍 Ареал: ${gbifData['gbifHabitat']}');
      
      // Проверяем структуру данных
      if (gbifData['gbifPhotoUrls'] != null) {
        final photos = gbifData['gbifPhotoUrls'] as List<dynamic>;
        print('  📸 URL фото: ${photos.length}');
        for (int i = 0; i < photos.length && i < 3; i++) {
          print('    📸 ${photos[i]}');
        }
      }
      
      if (gbifData['gbifOccurrences'] != null) {
        final occurrences = gbifData['gbifOccurrences'] as List<dynamic>;
        print('  📍 Occurrence данные: ${occurrences.length}');
        for (int i = 0; i < occurrences.length && i < 2; i++) {
          final occ = occurrences[i];
          if (occ is Map<String, dynamic>) {
            print('    📍 ${occ['decimalLatitude']}, ${occ['decimalLongitude']} - ${occ['country']}');
          }
        }
      }
    } else {
      print('❌ GBIF данные не получены');
      return;
    }
    
    print('\n🔧 Шаг 2: Полная цепочка fetchPlantData');
    final fullData = await LlifleService().fetchPlantData(testPlant);
    
    if (fullData != null) {
      print('✅ Полные данные получены:');
      print('  📸 Llifle фото: ${fullData['photoUrls']?.length ?? 0}');
      print('  📸 GBIF фото: ${fullData['gbifPhotoUrls']?.length ?? 0}');
      print('  📍 GBIF occurrence: ${fullData['gbifOccurrences']?.length ?? 0}');
      print('  🇺🇸 Страна: ${fullData['country']}');
      print('  📝 Синонимы: ${fullData['synonyms']}');
      print('  🌍 Ареал: ${fullData['habitat']}');
      
      // Проверяем общее количество фото
      final lliflePhotos = (fullData['photoUrls'] as List<dynamic>?)?.length ?? 0;
      final gbifPhotos = (fullData['gbifPhotoUrls'] as List<dynamic>?)?.length ?? 0;
      print('  📊 Всего фото: ${lliflePhotos + gbifPhotos} (Llifle: $lliflePhotos, GBIF: $gbifPhotos)');
      
      // Проверяем occurrence данные
      if (fullData['gbifOccurrences'] != null) {
        final occurrences = fullData['gbifOccurrences'] as List<dynamic>;
        print('  📍 Структура occurrence:');
        for (int i = 0; i < occurrences.length && i < 2; i++) {
          final occ = occurrences[i];
          if (occ is Map<String, dynamic>) {
            print('    📍 Запись #$i: ${occ.keys.toList()}');
          }
        }
      }
      
    } else {
      print('❌ Полные данные не получены');
    }
    
    print('\n🎯 Шаг 3: Тест конвертации в Plant модель');
    
    // Симуляция конвертации как в plant_card_screen.dart
    if (fullData != null) {
      // Обработка GBIF фото
      List<String> gbifPhotoUrls = [];
      if (fullData['gbifPhotoUrls'] != null) {
        final photoData = fullData['gbifPhotoUrls'] as List<dynamic>?;
        gbifPhotoUrls = photoData?.map((e) => e.toString()).toList() ?? [];
      }
      
      // Обработка GBIF occurrences
      List<Map<String, dynamic>> gbifOccurrences = [];
      if (fullData['gbifOccurrences'] != null) {
        final occurrenceData = fullData['gbifOccurrences'] as List<dynamic>?;
        gbifOccurrences = occurrenceData?.map((e) {
          if (e is Map) {
            return Map<String, dynamic>.from(e);
          }
          return <String, dynamic>{};
        }).where((map) => map.isNotEmpty).toList() ?? [];
      }
      
      print('✅ Конвертация успешна:');
      print('  📸 GBIF фото: ${gbifPhotoUrls.length}');
      print('  📍 GBIF occurrence: ${gbifOccurrences.length}');
      print('  🇺🇸 Страна: ${fullData['country']}');
      print('  📝 Синонимы: ${fullData['synonyms']}');
      print('  🌍 Ареал: ${fullData['habitat']}');
      
      // Показываем примеры данных
      if (gbifPhotoUrls.isNotEmpty) {
        print('  📸 Пример фото: ${gbifPhotoUrls.first}');
      }
      if (gbifOccurrences.isNotEmpty) {
        final occ = gbifOccurrences.first;
        print('  📍 Пример occurrence: ${occ['decimalLatitude']}, ${occ['decimalLongitude']} - ${occ['country']}');
      }
    }
    
    print('\n🎉 Тест завершен успешно!');
    
  } catch (e) {
    print('❌ Ошибка теста: $e');
    print('📍 Stack trace:\n${StackTrace.current}');
  }
}
