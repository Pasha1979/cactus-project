import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_cactus/services/yandex_disk_service.dart';

/// Тесты path-based загрузки (этап 3.2, R-004/R-055):
/// адрес файла на Диске — внутренний путь, НЕ публичная ссылка.
void main() {
  // pm3: путь версии паспорта — внутренний, не https
  test('pm3: passportPhotoPath — внутренний путь, не URL', () {
    final p = YandexDiskService.passportPhotoPath('pp1', 'v1', 'jpg');
    expect(p, '/MyCactus/photos/pp1_v1.jpg');
    expect(p.startsWith('/MyCactus/photos/'), isTrue);
    expect(p.startsWith('http'), isFalse);
    expect(p.contains('https://'), isFalse);
  });

  // pm4: результат — только путь, без public_url и publish
  test('pm4: нет public/publish ни в пути, ни в коде сервисов', () {
    final p = YandexDiskService.passportPhotoPath('pp1', 'v1');
    expect(p.contains('public'), isFalse);
    expect(p.contains('publish'), isFalse);
    expect(p.contains('url'), isFalse);

    // Механическая гарантия: в коде сервисов нет publish/public_url/get_public
    final serviceSrc =
        File('lib/services/yandex_disk_service.dart').readAsStringSync();
    final syncSrc =
        File('lib/services/photo_sync_service.dart').readAsStringSync();
    for (final src in [serviceSrc, syncSrc]) {
      final codeOnly =
          src.split('\n').where((l) => !l.trimLeft().startsWith('//')).join();
      expect(codeOnly.contains('publish'), isFalse);
      expect(codeOnly.contains('public_url'), isFalse);
      expect(codeOnly.contains('get_public'), isFalse);
    }
  });
}
