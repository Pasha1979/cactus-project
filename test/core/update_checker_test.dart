import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_cactus/core/update_checker.dart';

UpdateChecker _checker(http.Client client) =>
    UpdateChecker(client: client, versionUrl: 'https://example.com/v.txt');

http.Response _utf8(String body) => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );

void main() {
  // u1: версия совпадает с удалённой → isNewer = false
  test('u1: текущая версия == удалённой → isNewer = false', () async {
    final client = MockClient((_) async => _utf8(
          '1.2.0\n- строки изменений\n',
        ));
    final result = await _checker(client).checkForUpdates(
      currentVersion: '1.2.0',
    );

    expect(result.isNewer, isFalse);
    expect(result.latestVersion, '1.2.0');
    expect(result.error, isNull);
  });

  // u2: удалённая новее → isNewer = true + releaseNotes
  test('u2: удалённая новее → isNewer + releaseNotes', () async {
    final client = MockClient((_) async => _utf8(
          '1.3.0\n- Единая база\n- Фото-паспорта\n',
        ));
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

  // u4: HTTP 404 → безопасный fallback
  test('u4: HTTP 404 → isNewer = false', () async {
    final client = MockClient((_) async => http.Response('not found', 404));
    final result = await _checker(client).checkForUpdates();

    expect(result.isNewer, isFalse);
    expect(result.error, contains('404'));
  });
}
