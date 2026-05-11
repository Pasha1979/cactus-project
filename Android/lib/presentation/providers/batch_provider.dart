import 'package:flutter/foundation.dart';

import '../../models/plant.dart';

/// Провайдер для управления системой партий
///
/// Отвечает за:
/// - Создание партий из растений
/// - Управление сеянцами
/// - Удаление витрин с отвязыванием
///
/// DI: BatchRepository зарегистрирован в injection_container.dart
class BatchProvider with ChangeNotifier {

  /// Находит следующий свободный номер для сеянца в партии
  int getNextSeedlingNumber(List<Plant> allPlants, String batchDisplayId) {
    final existingNumbers = <int>{};
    for (var plant in allPlants) {
      if (plant.parentId != null && plant.displayId.startsWith('$batchDisplayId-')) {
        final suffix = plant.displayId.substring(batchDisplayId.length + 1);
        final number = int.tryParse(suffix);
        if (number != null) existingNumbers.add(number);
      }
    }
    int nextNumber = 1;
    while (existingNumbers.contains(nextNumber)) {
      nextNumber++;
    }
    return nextNumber;
  }

  /// Получает список сеянцев для витрины
  List<Plant> getBatchSeedlings(List<Plant> allPlants, String batchId) {
    try {
      final batch = allPlants.firstWhere((p) => p.permanentId == batchId);
      if (!batch.isBatch) return [];

      final seedlings = <Plant>[];
      for (var childId in batch.childrenIds) {
        final seedling = allPlants.firstWhere(
          (p) => p.permanentId == childId,
          orElse: () => throw Exception('Seedling not found'),
        );
        if (seedling.parentId == batchId) {
          seedlings.add(seedling);
        }
      }
      seedlings.sort((a, b) => a.displayId.compareTo(b.displayId));
      return seedlings;
    } catch (_) {
      return [];
    }
  }

  /// Проверяет, можно ли создать партию (минимум 2 живых)
  bool canConvertToBatch(Plant plant) {
    return plant.getCurrentAliveCount >= 2;
  }
}
