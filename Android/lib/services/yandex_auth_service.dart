import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/api_config.dart';
import '../core/config/app_constants.dart';
import '../core/logger/app_logger.dart';

/// Сервис аутентификации Яндекс.Диск (OAuth2)
///
/// Отвечает за:
/// - OAuth2 авторизацию (flow + callback)
/// - Хранение/загрузку токенов (FlutterSecureStorage)
/// - Тихое подключение (silent reconnect)
/// - Отключение (logout)
class YandexAuthService {

  YandexAuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    _initDeepLinkHandler();
  }
  final FlutterSecureStorage _storage;

  void _initDeepLinkHandler() {
    if (!Platform.isAndroid) return;

    const channel = MethodChannel('deep_link');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'deepLink') {
        final url = call.arguments as String;
        AppLogger.api('📨 Получен deep link из MainActivity: $url', tag: 'YANDEX_AUTH');

        if (_currentGrant != null && url.contains('code=')) {
          final uri = Uri.parse(url);
          final code = uri.queryParameters['code'];
          if (code != null) {
            await handleYandexCallback(_currentGrant!, code);
          }
        }
      }
    });
  }

  oauth2.Client? _yandexClient;
  oauth2.AuthorizationCodeGrant? _currentGrant;
  bool _isConnected = false;
  bool _isAuthorizing = false;
  String? _currentStorageType;

  static const String _yandexClientId = ApiConstants.yandexClientId;
  static const String _yandexClientSecret = ApiConstants.yandexClientSecret;
  static const String _yandexRedirectUri = ApiConstants.yandexRedirectUri;
  static const String _yandexAuthEndpoint = ApiConstants.yandexAuthEndpoint;
  static const String _yandexTokenEndpoint = ApiConstants.yandexTokenEndpoint;

  bool get isConnected => _isConnected;
  bool get isAuthorizing => _isAuthorizing;
  String? get currentStorageType => _currentStorageType;
  oauth2.Client? get yandexClient => _yandexClient;

  // ==================== ЗАГРУЗКА ТОКЕНОВ ====================

  Future<void> loadCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentStorageType = prefs.getString(PrefsKeys.cloudStorageType);

      if (_currentStorageType == 'yandex') {
        final accessToken = await _storage.read(key: 'yandex_access_token');
        final refreshToken = await _storage.read(key: 'yandex_refresh_token');

        if (accessToken != null && refreshToken != null) {
          final credentials = oauth2.Credentials(
            accessToken,
            refreshToken: refreshToken,
            tokenEndpoint: Uri.parse(_yandexTokenEndpoint),
          );

          _yandexClient = oauth2.Client(
            credentials,
            identifier: _yandexClientId,
            secret: _yandexClientSecret,
            httpClient: http.Client(),
          );

          _isConnected = true;
          AppLogger.api('✅ Токены успешно загружены и Яндекс.Диск подключён', tag: 'YANDEX_AUTH');
        } else {
          _isConnected = false;
          AppLogger.warning('⚠️ Токены не найдены (ещё не было авторизации)', tag: 'YANDEX_AUTH');
        }
      }
    } catch (e) {
      if (e.toString().contains('BadPaddingException') ||
          e.toString().contains('BAD_DECRYPT')) {
        AppLogger.error('🔥 Обнаружен BadPaddingException после пересборки APK', tag: 'YANDEX_AUTH');

        final prefs = await SharedPreferences.getInstance();
        final alreadyCleaned =
            prefs.getBool('tokens_cleaned_after_rebuild') ?? false;

        if (!alreadyCleaned) {
          AppLogger.api('🧹 Очищаем повреждённые токены (только один раз после пересборки)', tag: 'YANDEX_AUTH');
          await _storage.deleteAll();
          await _storage.delete(key: 'yandex_access_token');
          await _storage.delete(key: 'yandex_refresh_token');

          await prefs.setBool('tokens_cleaned_after_rebuild', true);
          AppLogger.api('✅ Токены очищены. Следующий запуск будет нормальным.', tag: 'YANDEX_AUTH');
        } else {
          AppLogger.api('✅ Токены уже были очищены ранее — оставляем _isConnected = false', tag: 'YANDEX_AUTH');
        }

        _isConnected = false;
        _yandexClient = null;
        _currentStorageType = null;
      } else {
        AppLogger.error('❌ Неизвестная ошибка загрузки токенов: $e', tag: 'YANDEX_AUTH');
        _isConnected = false;
      }
    }
  }

  // ==================== АВТОРИЗАЦИЯ ====================

  Future<void> connectToYandexDisk(BuildContext context) async {
    if (_isAuthorizing) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Авторизация уже выполняется...')),
        );
      }
      return;
    }

    _isAuthorizing = true;

    try {
      _currentGrant = null;

      final grant = oauth2.AuthorizationCodeGrant(
        _yandexClientId,
        Uri.parse(_yandexAuthEndpoint),
        Uri.parse(_yandexTokenEndpoint),
        secret: _yandexClientSecret,
        httpClient: http.Client(),
      );

      _currentGrant = grant;

      final redirectUri = Platform.isAndroid
          ? Uri.parse(_yandexRedirectUri)
          : Uri.parse('http://localhost:8080');

      final authorizationUrl = grant.getAuthorizationUrl(
        redirectUri,
        scopes: ['cloud_api:disk.read', 'cloud_api:disk.write'],
      );

      AppLogger.api('Открываем авторизацию: $authorizationUrl', tag: 'YANDEX_AUTH');

      final launched = await launchUrl(
        authorizationUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть браузер')),
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Авторизуйтесь в браузере.\nПосле этого САМОСТОЯТЕЛЬНО закройте браузер и вернитесь в приложение.',),
            duration: Duration(seconds: 15),
          ),
        );
      }

      // Android: ждём deep link (handleDeepLink вызывается системой)
      if (Platform.isAndroid) {
        AppLogger.api('Браузер открыт. Ожидаем deep link от системы...', tag: 'YANDEX_AUTH');
        return;
      }

      // Windows: запускаем локальный сервер
      final code = await _startLocalServer();
      if (code != null) {
        await handleYandexCallback(grant, code);
      }
    } catch (e) {
      AppLogger.error('Ошибка авторизации: $e', tag: 'YANDEX_AUTH');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      _isAuthorizing = false;
    }
  }

  Future<void> handleYandexCallback(
      oauth2.AuthorizationCodeGrant grant, String code,) async {
    AppLogger.api('Обмен кода на токен...', tag: 'YANDEX_AUTH');

    try {
      _yandexClient = await grant.handleAuthorizationResponse({
        'code': code,
        'redirect_uri': _yandexRedirectUri,
      });

      AppLogger.api('Токен успешно получен', tag: 'YANDEX_AUTH');

      await _storage.write(
          key: 'yandex_access_token',
          value: _yandexClient!.credentials.accessToken,);
      await _storage.write(
          key: 'yandex_refresh_token',
          value: _yandexClient!.credentials.refreshToken!,);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.cloudStorageType, 'yandex');
      await prefs.setBool(PrefsKeys.hasSeenWelcome, true);
      await prefs.setBool('remember_me', true);

      _currentStorageType = 'yandex';
      _isConnected = true;

      AppLogger.api('✅ Авторизация успешно завершена и токены сохранены', tag: 'YANDEX_AUTH');
    } catch (e) {
      AppLogger.error('Ошибка при обмене кода на токен: $e', tag: 'YANDEX_AUTH');
      rethrow;
    }
  }

  /// Обработка deep link для Android
  Future<void> handleDeepLink(Uri uri) async {
    AppLogger.api('🔄 handleDeepLink вызван с URI: $uri', tag: 'YANDEX_AUTH');

    if (uri.scheme == 'mycactus' && uri.host == 'callback') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        AppLogger.api('✅ Получен authorization code: $code', tag: 'YANDEX_AUTH');

        if (_currentGrant == null) {
          AppLogger.warning('⚠️ _currentGrant == null — создаём новый grant', tag: 'YANDEX_AUTH');
          _currentGrant = oauth2.AuthorizationCodeGrant(
            _yandexClientId,
            Uri.parse(_yandexAuthEndpoint),
            Uri.parse(_yandexTokenEndpoint),
            secret: _yandexClientSecret,
          );
        }

        try {
          await handleYandexCallback(_currentGrant!, code);
          _currentGrant = null;
          AppLogger.api('✅ Grant очищен после успешной авторизации', tag: 'YANDEX_AUTH');
        } catch (e, stack) {
          AppLogger.error('❌ Ошибка обработки callback: $e', tag: 'YANDEX_AUTH');
          AppLogger.error(stack.toString(), tag: 'YANDEX_AUTH');
          _currentGrant = null;
        }
      } else {
        AppLogger.warning('⚠️ В deep link нет параметра code', tag: 'YANDEX_AUTH');
      }
    }
  }

  // ==================== ТИХОЕ ПОДКЛЮЧЕНИЕ ====================

  Future<void> connectToYandexDiskSilently() async {
    if (_isConnected) return;

    final accessToken = await _storage.read(key: 'yandex_access_token');
    final refreshToken = await _storage.read(key: 'yandex_refresh_token');

    if (accessToken != null && refreshToken != null) {
      try {
        final credentials = oauth2.Credentials(
          accessToken,
          refreshToken: refreshToken,
          tokenEndpoint: Uri.parse(_yandexTokenEndpoint),
        );

        _yandexClient = oauth2.Client(
          credentials,
          identifier: _yandexClientId,
          secret: _yandexClientSecret,
          httpClient: http.Client(),
        );

        _isConnected = true;
        _currentStorageType = 'yandex';
        AppLogger.api('✅ Тихое подключение к Яндекс.Диску успешно', tag: 'YANDEX_AUTH');
      } catch (e) {
        AppLogger.error('Ошибка тихого подключения: $e', tag: 'YANDEX_AUTH');
        _isConnected = false;
      }
    }
  }

  // ==================== ОТКЛЮЧЕНИЕ ====================

  Future<void> disconnect() async {
    await _storage.delete(key: 'yandex_access_token');
    await _storage.delete(key: 'yandex_refresh_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.cloudStorageType);
    _yandexClient?.close();
    _yandexClient = null;
    _isConnected = false;
    _currentStorageType = null;
  }

  // ==================== WINDOWS ЛОКАЛЬНЫЙ СЕРВЕР ====================

  Future<String?> _startLocalServer() async {
    HttpServer? server;
    try {
      server = await HttpServer.bind('localhost', 8080);
      AppLogger.api('Локальный сервер запущен на http://localhost:8080', tag: 'YANDEX_AUTH');

      String? code;
      await for (var request in server) {
        final uri = request.uri;
        AppLogger.api('Получен запрос: $uri', tag: 'YANDEX_AUTH');

        if (uri.queryParameters.containsKey('code')) {
          code = uri.queryParameters['code'];
          request.response
            ..statusCode = 200
            ..headers.add('Access-Control-Allow-Origin', '*')
            ..headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            ..headers
                .add('Access-Control-Allow-Headers', 'Origin, Content-Type')
            ..write('Авторизация завершена. Можете закрыть это окно.')
            ..close();
          break;
        } else {
          if (uri.queryParameters.containsKey('error')) {
            AppLogger.error('Ошибка от Yandex: ${uri.queryParameters['error']}', tag: 'YANDEX_AUTH');
          }
          request.response
            ..statusCode = 400
            ..write('Ошибка: код авторизации не получен.')
            ..close();
        }
      }
      return code;
    } catch (e) {
      AppLogger.error('Ошибка запуска локального сервера: $e', tag: 'YANDEX_AUTH');
      rethrow;
    } finally {
      await server?.close(force: true);
      AppLogger.api('Локальный сервер закрыт', tag: 'YANDEX_AUTH');
    }
  }
}
