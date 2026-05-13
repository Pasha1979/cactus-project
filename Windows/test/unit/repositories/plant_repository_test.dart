import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_cactus/data/datasources/local/plant_local_datasource.dart';
import 'package:my_cactus/data/models/plant_dto.dart';
import 'package:my_cactus/data/repositories/plant_repository_impl.dart';
import 'package:my_cactus/models/plant.dart';

import 'plant_repository_test.mocks.dart';

@GenerateMocks([PlantLocalDataSource])
void main() {
  late PlantRepositoryImpl repository;
  late MockPlantLocalDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockPlantLocalDataSource();
    repository = PlantRepositoryImpl(mockDataSource);
  });

  group('getAllPlants', () {
    test('should return list of plants when data source has plants', () async {
      // Arrange
      final plantDtos = [
        _createTestPlantDto('1', 'Echinocactus'),
        _createTestPlantDto('2', 'Gymnocalycium'),
      ];
      when(mockDataSource.getAllPlants()).thenAnswer((_) async => plantDtos);

      // Act
      final result = await repository.getAllPlants();

      // Assert
      expect(result, isA<List<Plant>>());
      expect(result.length, 2);
      expect(result.first.latinName, 'Echinocactus');
      verify(mockDataSource.getAllPlants()).called(1);
    });

    test('should return empty list when data source is empty', () async {
      // Arrange
      when(mockDataSource.getAllPlants()).thenAnswer((_) async => []);

      // Act
      final result = await repository.getAllPlants();

      // Assert
      expect(result, isEmpty);
      verify(mockDataSource.getAllPlants()).called(1);
    });
  });

  group('getPlantById', () {
    test('should return plant when found', () async {
      // Arrange
      final plantDto = _createTestPlantDto('1', 'Echinocactus');
      when(mockDataSource.getPlantById('1')).thenAnswer((_) async => plantDto);

      // Act
      final result = await repository.getPlantById('1');

      // Assert
      expect(result, isNotNull);
      expect(result!.permanentId, '1');
      expect(result.latinName, 'Echinocactus');
      verify(mockDataSource.getPlantById('1')).called(1);
    });

    test('should return null when plant not found', () async {
      // Arrange
      when(mockDataSource.getPlantById('999')).thenAnswer((_) async => null);

      // Act
      final result = await repository.getPlantById('999');

      // Assert
      expect(result, isNull);
      verify(mockDataSource.getPlantById('999')).called(1);
    });
  });

  group('addPlant', () {
    test('should call dataSource.addPlant with correct dto', () async {
      // Arrange
      final plant = _createTestPlant('1', 'Echinocactus');
      when(mockDataSource.addPlant(any)).thenAnswer((_) async {});

      // Act
      await repository.addPlant(plant);

      // Assert
      verify(mockDataSource.addPlant(any)).called(1);
    });
  });

  group('updatePlant', () {
    test('should call dataSource.updatePlant with correct dto', () async {
      // Arrange
      final plant = _createTestPlant('1', 'Echinocactus');
      when(mockDataSource.updatePlant(any)).thenAnswer((_) async {});

      // Act
      await repository.updatePlant(plant);

      // Assert
      verify(mockDataSource.updatePlant(any)).called(1);
    });
  });

  group('deletePlant', () {
    test('should call dataSource.deletePlant with correct id', () async {
      // Arrange
      when(mockDataSource.deletePlant(any)).thenAnswer((_) async {});

      // Act
      await repository.deletePlant('1');

      // Assert
      verify(mockDataSource.deletePlant('1')).called(1);
    });
  });

  group('getPlantsByStatus', () {
    test('should return plants filtered by status', () async {
      // Arrange
      final plantDtos = [
        _createTestPlantDto('1', 'Echinocactus', status: 'alive'),
        _createTestPlantDto('2', 'Gymnocalycium', status: 'dead'),
      ];
      when(mockDataSource.getPlantsByStatus('alive'))
          .thenAnswer((_) async => [plantDtos[0]]);

      // Act
      final result = await repository.getPlantsByStatus('alive');

      // Assert
      expect(result.length, 1);
      expect(result.first.status, 'alive');
      verify(mockDataSource.getPlantsByStatus('alive')).called(1);
    });
  });

  group('getPlantsByCategory', () {
    test('should return plants filtered by category', () async {
      // Arrange
      final plantDtos = [
        _createTestPlantDto('1', 'Echinocactus', category: 'Cactaceae'),
        _createTestPlantDto('2', 'Gymnocalycium', category: 'Aloe'),
      ];
      when(mockDataSource.getPlantsByCategory('Cactaceae'))
          .thenAnswer((_) async => [plantDtos[0]]);

      // Act
      final result = await repository.getPlantsByCategory('Cactaceae');

      // Assert
      expect(result.length, 1);
      expect(result.first.category, 'Cactaceae');
      verify(mockDataSource.getPlantsByCategory('Cactaceae')).called(1);
    });
  });

  group('searchPlants', () {
    test('should return plants matching query', () async {
      // Arrange
      final plantDtos = [
        _createTestPlantDto('1', 'Echinocactus grusonii'),
        _createTestPlantDto('2', 'Gymnocalycium mihanovichii'),
      ];
      when(mockDataSource.searchPlants('echino'))
          .thenAnswer((_) async => [plantDtos[0]]);

      // Act
      final result = await repository.searchPlants('echino');

      // Assert
      expect(result.length, 1);
      expect(result.first.latinName, 'Echinocactus grusonii');
      verify(mockDataSource.searchPlants('echino')).called(1);
    });
  });
}

// Helpers
PlantDto _createTestPlantDto(
  String id,
  String latinName, {
  String status = 'alive',
  String category = 'Cactaceae',
}) {
  return PlantDto(
    permanentId: id,
    displayId: 'C-$id',
    latinName: latinName,
    status: status,
    year: 2024,
    customNumber: 1,
    category: category,
    seedsCount: 0,
    germinatedCount: 0,
    userPhotos: [],
    lliflePhotoUrls: [],
    wateringDates: [],
    customWateringDates: [],
    hasUnreadNotification: false,
    germinationHistoryJson: [],
    floweringHistoryJson: [],
    notesJson: [],
    gbifPhotoUrls: [],
    gbifOccurrencesJson: [],
    isBatch: false,
    childrenIds: [],
  );
}

Plant _createTestPlant(String id, String latinName) {
  return Plant(
    permanentId: id,
    displayId: 'C-$id',
    latinName: latinName,
    status: 'alive',
    year: 2024,
    customNumber: 1,
    category: 'Cactaceae',
    seedsCount: 0,
    germinatedCount: 0,
    userPhotos: [],
    lliflePhotoUrls: [],
    wateringDates: [],
    customWateringDates: [],
    hasUnreadNotification: false,
    germinationHistory: [],
    floweringHistory: [],
    notes: [],
    gbifPhotoUrls: [],
    gbifOccurrences: [],
    isBatch: false,
    childrenIds: [],
  );
}
