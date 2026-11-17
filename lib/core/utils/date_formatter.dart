import 'package:intl/intl.dart';

/// Утилиты для работы с датами
class DateUtils {
  /// Форматирование даты в формате dd.MM.yyyy
  static String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  /// Форматирование даты и времени в формате dd.MM.yyyy HH:mm
  static String formatDateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  /// Форматирование даты в формате MMMM yyyy (например: "Май 2026")
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy', 'ru').format(date);
  }

  /// Парсинг даты из строки в формате dd.MM.yyyy
  static DateTime? parseDate(String dateString) {
    try {
      return DateFormat('dd.MM.yyyy').parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Получение разницы между датами в днях
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }

  /// Проверка, является ли дата сегодня
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  /// Проверка, является ли дата в будущем
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }

  /// Проверка, является ли дата в прошлом
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  /// Добавление дней к дате
  static DateTime addDays(DateTime date, int days) {
    return date.add(Duration(days: days));
  }

  /// Вычитание дней из даты
  static DateTime subtractDays(DateTime date, int days) {
    return date.subtract(Duration(days: days));
  }

  /// Получение начала дня
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Получение конца дня
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }
}
