import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_cactus/core/update_checker.dart';

UpdateChecker _checker(http.Client client) =>
    UpdateChecker(client: client, versionUrl: 'https://example.com/v');

http.Response _json(Map<String, dynamic> body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  // u1: версия релиза совпадает с текущей → isNewer = false
  test('u1: текущая версия == tag_name → isNewer = false', () async {
    final client = MockClient((_) async => _json({
          'tag_name': 'v1.2.0',
          'body': '- строки изменений',
        }));
    final result = await _checker(client).checkForUpdates(
      currentVersion: '1.2.0',
    );

    expect(result.isNewer, isFalse);
    expect(result.latestVersion, '1.2.0');
    expect(result.error, isNull);
  });

  // u2: релиз новее → isNewer = true + releaseNotes из body
  test('u2: tag_name новее → isNewer + releaseNotes', () async {
    final client = MockClient((_) async => _json({
          'tag_name': '1.3.0',
          'body': '- Единая база\n- Фото-паспорта',
        }));
    final result = await _checker(client).checkForUpdates(
      currentVersion: '1.2.0',
    );

    expect(result.isNewer, isTrue);
    expect(result.latestVersion, '1.3.0');
    expect(result.releaseNotes, contains('Единая база'));
    expect(result.releaseNotes, contains('Фото-паспорта'));
  });

  // u3: ошибка сети → безопасный fallback без краша
  test('u3: ошибка сети → isNewer = false, error заполнен', () async {
    final client = MockClient((_) async => throw Exception('no network'));
    final result = await _checker(client).checkForUpdates(
      currentVersion: '1.2.0',
    );

    expect(result.isNewer, isFalse);
    expect(result.error, isNotNull);
  });

  // u4/f7: 404 (релизов нет) → isNewer = false, БЕЗ ошибки (M1)
  test('u4: 404 → isNewer = false без error', () async {
    final client = MockClient((_) async => http.Response('not found', 404));
    final result = await _checker(client).checkForUpdates();

    expect(result.isNewer, isFalse);
    expect(result.error, isNull);
  });
}
