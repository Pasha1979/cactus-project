import 'dart:convert';

import 'package:hive/hive.dart';

import '../logger/app_logger.dart';

/// Корзина удалений фото с Яндекс.Диска (аудит 4.2, C3+M4, R-004/R-005).
///
/// «Удалить везде» не трогает файл мгновенно — путь ставится в очередь
/// `photo_trash` и удаляется при ближайшей синхронизации ВЫЗОВОМ с
/// `permanently=false` (Яндекс сам кладёт файл в свою Корзину на 30 дней —
/// откат возможен на стороне Диска).
///
/// Из очереди убираются ТОЛЬКО успешно удалённые пути; упавшие остаются
/// и будут повторены при следующей синхронизации — ноль потерь (R-024).
class PhotoTrashService {
  PhotoTrashService(this._box);

  final Box<String> _box;

  /// Поставить пути в очередь на удаление.
  ///
  /// [deleteNow] = true — удалить при ближайшей синхронизации;
  /// иначе — отложено до [deleteAfter] (по умолчанию +30 дней).
  Future<void> enqueueDelete(
    String id,
    List<String> yandexPaths, {
    bool deleteNow = true,
    DateTime? deleteAfter,
  }) async {
    if (yandexPaths.isEmpty) return;
    final entry = {
      'id': id,
      'paths': yandexPaths,
      'now': deleteNow,
      'deleteAfter':
          (deleteAfter ?? DateTime.now().add(const Duration(days: 30)))
              .toIso8601String(),
    };
    await _box.put(id, jsonEncode(entry));
  }

  /// Обработать очередь: удалить через [deleteFn] пути, чей срок настал
  /// (помеченные «сейчас» или [DateTime.now] >= deleteAfter).
  ///
  /// Из записи вычёркиваются только успешные пути; если остались неудачные —
  /// запись сохраняется для повтора. Возвращает число удалённых путей.
  Future<int> processTrash(
    Future<void> Function(String yandexPath) deleteFn,
  ) async {
    var deleted = 0;
    final now = DateTime.now();

    for (final key in _box.keys.toList()) {
      final raw = _box.get(key);
      if (raw == null) continue;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _box.delete(key); // битая запись — не удаление, чистим
        continue;
      }
      final entry = Map<String, dynamic>.from(decoded);

      final due = entry['now'] == true ||
          now.isAfter(
            DateTime.tryParse(entry['deleteAfter'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
      if (!due) continue;

      final paths = List<String>.from(entry['paths'] as List? ?? const []);
      final failed = <String>[];
      for (final p in paths) {
        try {
          await deleteFn(p);
          deleted++;
        } catch (e) {
          AppLogger.warning(
            'Корзина: не удалось удалить $p (повтор позже): $e',
            tag: 'PHOTO_TRASH',
          );
          failed.add(p);
        }
      }

      if (failed.isEmpty) {
        await _box.delete(key);
      } else {
        entry['paths'] = failed;
        await _box.put(key, jsonEncode(entry));
      }
    }
    return deleted;
  }

  /// Число записей в очереди (для тестов/диагностики).
  int get pendingCount => _box.length;
}
