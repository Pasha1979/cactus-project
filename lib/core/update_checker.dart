import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config/app_constants.dart';
import 'logger/app_logger.dart';

/// Результат проверки обновлений (R-022, этап 4.1).
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.isNewer,
    this.latestVersion = '',
    this.releaseNotes = '',
    this.error,
  });

  /// Доступна версия новее установленной.
  final bool isNewer;

  /// Версия, прочитанная из файла обновлений.
  final String latestVersion;

  /// Список изменений (строки после первой в файле обновлений).
  final String releaseNotes;

  /// Текст ошибки, если проверка не удалась (сеть/парсинг).
  final String? error;
}

/// Проверка обновлений через raw-файл в репозитории (R-022).
///
/// Формат docs/LATEST_VERSION.txt:
/// ```
/// 1.2.0
/// - строка списка изменений
/// - ещё одна строка
/// ```
/// Первая непустая строка — версия, остальное — releaseNotes.
class UpdateChecker {
  UpdateChecker({http.Client? client, String? versionUrl})
      : _client = client ?? http.Client(),
        _versionUrl = versionUrl ?? defaultVersionUrl;

  static const String defaultVersionUrl =
      'https://raw.githubusercontent.com/Pasha1979/cactus-project/'
      'main/docs/LATEST_VERSION.txt';

  /// Страница релизов — кнопка «Скачать» в диалоге обновления.
  static const String releasesUrl =
      'https://github.com/Pasha1979/cactus-project/releases';

  final http.Client _client;
  final String _versionUrl;

  /// Сравнивает удалённую версию с [currentVersion] (по умолчанию —
  /// [AppConstants.appVersion]). При любой ошибке возвращает
  /// безопасный результат (isNewer = false, error заполнен).
  Future<UpdateCheckResult> checkForUpdates({
    String currentVersion = AppConstants.appVersion,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse(_versionUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return UpdateCheckResult(
          isNewer: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
      // bodyBytes + utf8.decode: response.body декодируется как latin1,
      // если сервер не прислал charset — кириллица в заметках сломается.
      final lines = utf8
          .decode(response.bodyBytes)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        return const UpdateCheckResult(
          isNewer: false,
          error: 'Пустой файл версий',
        );
      }
      final latest = lines.first;
      final notes = lines.skip(1).join('\n');
      return UpdateCheckResult(
        isNewer: _isNewer(latest, currentVersion),
        latestVersion: latest,
        releaseNotes: notes,
      );
    } catch (e, st) {
      AppLogger.warning('Проверка обновлений не удалась',
          tag: 'UpdateChecker', error: e, stackTrace: st);
      return UpdateCheckResult(isNewer: false, error: e.toString());
    }
  }

  /// Semver-сравнение: "1.3.0" > "1.2.0". Нечисловые части = 0.
  static bool _isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (r[i] != c[i]) return r[i] > c[i];
    }
    return false;
  }

  static List<int> _parse(String version) {
    final parts = version.split('.');
    return List.generate(
      3,
      (i) => i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0,
      growable: false,
    );
  }
}
