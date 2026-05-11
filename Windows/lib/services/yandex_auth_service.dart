import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/api_config.dart';
import '../core/config/app_constants.dart';

/// Сервис аутентификации Яндекс.Диск (OAuth2)
///
/// Отвечает за:
/// - OAuth2 авторизацию (flow + callback)
/// - Хранение/загрузку токенов (FlutterSecureStorage)
/// - Тихое подключение (silent reconnect)
/// - Отключение (logout)
class YandexAuthService {
  final FlutterSecureStorage _storage;

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

  YandexAuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

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
          print('✅ Токены успешно загружены и Яндекс.Диск подключён');
        } else {
          _isConnected = false;
          print('⚠️ Токены не найдены (ещё не было авторизации)');
        }
      }
    } catch (e) {
      if (e.toString().contains('BadPaddingException') ||
          e.toString().contains('BAD_DECRYPT')) {
        print('🔥 Обнаружен BadPaddingException после пересборки APK');

        final prefs = await SharedPreferences.getInstance();
        final alreadyCleaned =
            prefs.getBool('tokens_cleaned_after_rebuild') ?? false;

        if (!alreadyCleaned) {
          print(
              '🧹 Очищаем повреждённые токены (только один раз после пересборки)');
          await _storage.deleteAll();
          await _storage.delete(key: 'yandex_access_token');
          await _storage.delete(key: 'yandex_refresh_token');

          await prefs.setBool('tokens_cleaned_after_rebuild', true);
          print('✅ Токены очищены. Следующий запуск будет нормальным.');
        } else {
          print(
              '✅ Токены уже были очищены ранее — оставляем _isConnected = false');
        }

        _isConnected = false;
        _yandexClient = null;
        _currentStorageType = null;
      } else {
        print('❌ Неизвестная ошибка загрузки токенов: $e');
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

      print('Открываем авторизацию: $authorizationUrl');

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
                'Авторизуйтесь в браузере.\nПосле этого САМОСТОЯТЕЛЬНО закройте браузер и вернитесь в приложение.'),
            duration: Duration(seconds: 15),
          ),
        );
      }

      // Android: ждём deep link (handleDeepLink вызывается системой)
      if (Platform.isAndroid) {
        print('Браузер открыт. Ожидаем deep link от системы...');
        return;
      }

      // Windows: запускаем локальный сервер
      final code = await _startLocalServer();
      if (code != null) {
        await handleYandexCallback(grant, code);
      }
    } catch (e) {
      print('Ошибка авторизации: $e');
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
      oauth2.AuthorizationCodeGrant grant, String code) async {
    print('Обмен кода на токен...');

    try {
      _yandexClient = await grant.handleAuthorizationResponse({
        'code': code,
        'redirect_uri': _yandexRedirectUri,
      });

      print('Токен успешно получен');

      await _storage.write(
          key: 'yandex_access_token',
          value: _yandexClient!.credentials.accessToken);
      await _storage.write(
          key: 'yandex_refresh_token',
          value: _yandexClient!.credentials.refreshToken!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.cloudStorageType, 'yandex');
      await prefs.setBool(PrefsKeys.hasSeenWelcome, true);
      await prefs.setBool('remember_me', true);

      _currentStorageType = 'yandex';
      _isConnected = true;

      print('✅ Авторизация успешно завершена и токены сохранены');
    } catch (e) {
      print('Ошибка при обмене кода на токен: $e');
      rethrow;
    }
  }

  /// Обработка deep link для Android
  Future<void> handleDeepLink(Uri uri) async {
    print('🔄 handleDeepLink вызван с URI: $uri');

    if (uri.scheme == 'mycactus' && uri.host == 'callback') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        print('✅ Получен authorization code: $code');

        if (_currentGrant == null) {
          print('⚠️ _currentGrant == null — создаём новый grant');
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
          print('✅ Grant очищен после успешной авторизации');
        } catch (e, stack) {
          print('❌ Ошибка обработки callback: $e');
          print(stack);
          _currentGrant = null;
        }
      } else {
        print('⚠️ В deep link нет параметра code');
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
        print('✅ Тихое подключение к Яндекс.Диску успешно');
      } catch (e) {
        print('Ошибка тихого подключения: $e');
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
      print('Локальный сервер запущен на http://localhost:8080');

      String? code;
      await for (var request in server) {
        final uri = request.uri;
        print('Получен запрос: $uri');

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
            print('Ошибка от Yandex: ${uri.queryParameters['error']}');
          }
          request.response
            ..statusCode = 400
            ..write('Ошибка: код авторизации не получен.')
            ..close();
        }
      }
      return code;
    } catch (e) {
      print('Ошибка запуска локального сервера: $e');
      rethrow;
    } finally {
      await server?.close(force: true);
      print('Локальный сервер закрыт');
    }
  }
}
