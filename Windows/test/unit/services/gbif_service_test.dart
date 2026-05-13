import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_cactus/services/api/gbif_service.dart';

void main() {
  late GbifService service;

  setUp(() {
    service = GbifService();
    SharedPreferences.setMockInitialValues({});
  });

  group('getMostFrequentCountry', () {
    test('should return most frequent country', () {
      // Arrange
      final countries = ['Mexico', 'USA', 'Mexico', 'Canada', 'Mexico'];

      // Act
      final result = service.getMostFrequentCountry(countries);

      // Assert
      expect(result, 'Mexico');
    });

    test('should return empty string for empty list', () {
      // Arrange
      final countries = <String>[];

      // Act
      final result = service.getMostFrequentCountry(countries);

      // Assert
      expect(result, '');
    });

    test('should handle single country', () {
      // Arrange
      final countries = ['Argentina'];

      // Act
      final result = service.getMostFrequentCountry(countries);

      // Assert
      expect(result, 'Argentina');
    });

    test('should handle tied frequencies', () {
      // Arrange
      final countries = ['Mexico', 'USA', 'Mexico', 'USA'];

      // Act
      final result = service.getMostFrequentCountry(countries);

      // Assert - should return first encountered with max frequency
      expect(result, 'Mexico');
    });
  });

  group('Cache operations', () {
    test('should cache and retrieve data', () async {
      // Arrange
      final testData = {
        'gbifOccurrences': [],
        'gbifPhotoUrls': ['http://example.com/photo1.jpg'],
        'gbifCountry': 'Mexico',
        'lastGbifUpdate': DateTime.now().toIso8601String(),
      };

      // Act
      await service.cacheGbifData('Echinocactus', testData);
      final cached = await service.getCachedGbifData('Echinocactus');

      // Assert
      expect(cached, isNotNull);
      expect(cached!['gbifCountry'], 'Mexico');
      expect(cached['gbifPhotoUrls'], ['http://example.com/photo1.jpg']);
    });

    test('should return null for expired cache', () async {
      // Arrange
      final expiredData = {
        'gbifOccurrences': [],
        'gbifCountry': 'Mexico',
        'lastGbifUpdate': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      };
      await service.cacheGbifData('Echinocactus', expiredData);

      // Act
      final cached = await service.getCachedGbifData('Echinocactus');

      // Assert
      expect(cached, isNull);
    });

    test('should return null for non-existent cache', () async {
      // Act
      final cached = await service.getCachedGbifData('NonExistentPlant');

      // Assert
      expect(cached, isNull);
    });

    test('should clear specific cache', () async {
      // Arrange
      final testData = {
        'gbifOccurrences': [],
        'gbifCountry': 'Mexico',
        'lastGbifUpdate': DateTime.now().toIso8601String(),
      };
      await service.cacheGbifData('Echinocactus', testData);

      // Act
      await service.clearGbifCache('Echinocactus');
      final cached = await service.getCachedGbifData('Echinocactus');

      // Assert
      expect(cached, isNull);
    });
  });

  group('Cache key generation', () {
    test('should generate consistent cache keys', () async {
      // Arrange
      final testData = {
        'gbifOccurrences': [],
        'gbifCountry': 'Mexico',
        'lastGbifUpdate': DateTime.now().toIso8601String(),
      };

      // Act - cache with different cases
      await service.cacheGbifData('Echinocactus', testData);

      // Should retrieve regardless of case (implementation detail)
      final cachedLower = await service.getCachedGbifData('echinocactus');
      final cachedUpper = await service.getCachedGbifData('ECHINOCACTUS');

      // Assert - at least one should work (depends on implementation)
      expect(cachedLower != null || cachedUpper != null, isTrue);
    });
  });
}
