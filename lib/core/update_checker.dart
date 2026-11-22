import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config/app_constants.dart';
import 'logger/app_logger.dart';

/// Результат проверки обновлений (R-022, этап 4.1, аудит 4.2 — M1).
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.isNewer,
    this.latestVersion = '',
    this.releaseNotes = '',
    this.error,
  });

  /// Доступна версия новее установленной.
  final bool isNewer;

  /// Версия последнего релиза (tag_name без префикса 'v').
  final String latestVersion;

  /// Список изменений (body релиза).
  final String releaseNotes;

  /// Текст ошибки, если проверка не удалась (сеть/парсинг).
  final String? error;
}

/// Проверка обновлений через GitHub Releases API (R-022, аудит 4.2 M1).
///
/// Читается `releases/latest`: tag_name = версия, body = releaseNotes.
/// 404 (релизов ещё нет) → isNewer = false, без краха.
/// Raw main-файл больше НЕ используется — он создавал ложные
/// «обновления» до публикации релиза (docs/LATEST_VERSION.txt остаётся
/// как документация релиза).
class UpdateChecker {
  UpdateChecker({http.Client? client, String? versionUrl})
      : _client = client ?? http.Client(),
        _versionUrl = versionUrl ?? defaultVersionUrl;

  static const String defaultVersionUrl =
      'https://api.github.com/repos/Pasha1979/cactus-project/'
      'releases/latest';

  /// Страница релизов — кнопка «Скачать» в диалоге обновления.
  static const String releasesUrl =
      'https://github.com/Pasha1979/cactus-project/releases';

  final http.Client _client;
  final String _versionUrl;

  /// Сравнивает версию последнего релиза с [currentVersion] (по умолчанию —
  /// [AppConstants.appVersion]). При любой ошибке возвращает
  /// безопасный результат (isNewer = false, error заполнен).
  Future<UpdateCheckResult> checkForUpdates({
    String currentVersion = AppConstants.appVersion,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(_versionUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      // Релизов ещё нет — это не ошибка (M1).
      if (response.statusCode == 404) {
        return const UpdateCheckResult(isNewer: false);
      }
      if (response.statusCode != 200) {
        return UpdateCheckResult(
          isNewer: false,
          error: 'HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        return const UpdateCheckResult(
          isNewer: false,
          error: 'Неожиданный формат ответа',
        );
      }
      final json = Map<String, dynamic>.from(decoded);
      final latest =
          (json['tag_name'] as String? ?? '').replaceFirst('v', '');
      if (latest.isEmpty) {
        return const UpdateCheckResult(
          isNewer: false,
          error: 'В ответе нет tag_name',
        );
      }
      return UpdateCheckResult(
        isNewer: _isNewer(latest, currentVersion),
        latestVersion: latest,
        releaseNotes: json['body'] as String? ?? '',
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
