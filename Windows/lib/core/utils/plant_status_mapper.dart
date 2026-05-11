/// Централизованный маппер статусов растений.
///
/// Унифицирует:
/// - Нормализацию сырых строк → канонические статусы
/// - Отображаемый текст на русском
/// - Порядок сортировки
/// - Валидацию
class PlantStatusMapper {
  // ==================== КАНОНИЧЕСКИЕ СТАТУСЫ ====================

  static const _canonical = {
    'sown': true,
    'growing': true,
    'in_collection': true,
    'dead': true,
    'failed': true,
  };

  // ==================== ПОРЯДОК СОРТИРОВКИ ====================

  static const _sortOrder = {
    'sown': 0,
    'growing': 1,
    'in_collection': 2,
    'dead': 3,
    'failed': 4,
  };

  // ==================== ОТОБРАЖАЕМЫЙ ТЕКСТ ====================

  static const _displayText = {
    'sown': 'Посеян',
    'growing': 'Растёт',
    'in_collection': 'В коллекции',
    'dead': 'Погиб',
    'failed': 'Не взошел',
  };

  // ==================== МАППИНГ СЫРЫХ СТРОК ====================

  static const _rawToCanonical = {
    'не взошел': 'failed',
    'посеян': 'sown',
    'растёт': 'growing',
    'растет': 'growing',
    'в коллекции': 'in_collection',
    'погиб': 'dead',
  };

  // ==================== ПУБЛИЧНЫЙ API ====================

  /// Нормализует сырую строку статуса в каноническое значение.
  /// Возвращает исходное значение, если не распознано.
  static String normalize(dynamic rawStatus) {
    final s = rawStatus?.toString().trim().toLowerCase() ?? '';
    if (_canonical.containsKey(s)) return s;
    return _rawToCanonical[s] ?? rawStatus?.toString() ?? '';
  }

  /// Возвращает отображаемый текст для статуса.
  /// При неизвестном статусе — 'Неизвестный статус'.
  static String toDisplayText(String? status) {
    if (status == null) return 'Неизвестный статус';
    return _displayText[normalize(status)] ?? 'Неизвестный статус';
  }

  /// Возвращает порядок сортировки для статуса.
  /// Неизвестные статусы получают максимальный порядок (99).
  static int sortOrder(String? status) {
    return _sortOrder[normalize(status)] ?? 99;
  }

  /// Проверяет, является ли строка каноническим статусом.
  static bool isValid(String? status) {
    if (status == null) return false;
    return _canonical.containsKey(normalize(status));
  }
}
