import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'plant_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart'; // ← для Provider.of
import '../main.dart'; // ← для navigatorKey
import 'package:uuid/uuid.dart';

class CloudStorageProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  oauth2.Client? _yandexClient;
  bool _isConnected = false;
  String? _currentStorageType;
  bool _isAuthorizing = false;
  DateTime? _lastCloudUpdate;
  oauth2.AuthorizationCodeGrant?
      _currentGrant; // Для сохранения состояния авторизации

  static const String _yandexClientId = '066c5dd1fda94c15ac2dc248cdb0f1e8';
  static const String _yandexClientSecret = 'c624749917a34e6a8579e5ff2685f0f7';
  static const String _yandexRedirectUri = 'mycactus://callback';
  static const String _yandexAuthEndpoint =
      'https://oauth.yandex.com/authorize';
  static const String _yandexTokenEndpoint = 'https://oauth.yandex.com/token';
  static const String _yandexApiBaseUrl =
      'https://cloud-api.yandex.net/v1/disk';

  bool get isConnected => _isConnected;
  bool get isSyncing => false; // TODO: реализовать флаг синхронизации
  String? get currentStorageType => _currentStorageType;
  DateTime? get lastCloudUpdate => _lastCloudUpdate;
  Future<void> handleDeepLink(Uri uri) async {
    print('🔄 handleDeepLink вызван с URI: $uri');

    if (uri.scheme == 'mycactus' && uri.host == 'callback') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        print('✅ Получен authorization code: $code');

        if (_currentGrant == null) {
          print(
              '⚠️ _currentGrant == null — критическая ошибка, создаём новый grant');
          _currentGrant = oauth2.AuthorizationCodeGrant(
            _yandexClientId,
            Uri.parse(_yandexAuthEndpoint),
            Uri.parse(_yandexTokenEndpoint),
            secret: _yandexClientSecret,
          );
        }

        try {
          await handleYandexCallback(_currentGrant!, code);

          // Полная перезагрузка данных после успешной авторизации
          if (_isConnected) {
            final context = navigatorKey.currentContext;
            if (context != null && context.mounted) {
              final plantProvider =
                  Provider.of<PlantProvider>(context, listen: false);
              await loadDataFromCloud(plantProvider);
              print('🔄 Полная синхронизация после авторизации выполнена');
            }
          }

          // Очищаем grant после успешного использования
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

  CloudStorageProvider() {
    loadCredentials();
  }

  Future<void> loadCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentStorageType = prefs.getString('cloud_storage_type');

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
          await _createAppFolders();
          await fetchLastCloudUpdate();
          print('✅ Токены успешно загружены и Яндекс.Диск подключён');
        } else {
          _isConnected = false;
          print('⚠️ Токены не найдены (ещё не было авторизации)');
        }
      }
      notifyListeners();
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

      notifyListeners();
    }
  }

// === ОКОНЧАТЕЛЬНЫЙ fetchLastCloudUpdate() ===
  Future<void> fetchLastCloudUpdate() async {
    if (!_isConnected || _yandexClient == null) {
      _lastCloudUpdate = null;
      return;
    }

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    DateTime? cloudDateFromServer;

    try {
      // 1. Пытаемся получить дату файла
      final fileResponse = await dio.get(
        '$_yandexApiBaseUrl/resources?path=/MyCactus/plant_provider.json',
      );

      if (fileResponse.statusCode == 200) {
        final modified = fileResponse.data['modified'] as String?;
        cloudDateFromServer = DateTime.tryParse(modified ?? '');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        print('⚠️ Ошибка запроса файла: $e');
      }
    } catch (e) {
      print('⚠️ Неизвестная ошибка запроса файла: $e');
    }

    // 2. Если получили дату с сервера — сравниваем с текущей _lastCloudUpdate
    if (cloudDateFromServer != null) {
      if (_lastCloudUpdate == null ||
          cloudDateFromServer.isAfter(_lastCloudUpdate!)) {
        _lastCloudUpdate = cloudDateFromServer;
        print('✅ Дата обновлена из ФАЙЛА: $_lastCloudUpdate');
      } else {
        print(
            'ℹ️ Дата с сервера ($cloudDateFromServer) не новее текущей ($_lastCloudUpdate) — оставляем текущую');
      }
    } else {
      // 3. Fallback на папку, если файл не найден
      try {
        final folderResponse = await dio.get(
          '$_yandexApiBaseUrl/resources?path=/MyCactus',
        );
        if (folderResponse.statusCode == 200) {
          final modified = folderResponse.data['modified'] as String?;
          final folderDate = DateTime.tryParse(modified ?? '');
          if (folderDate != null &&
              (_lastCloudUpdate == null ||
                  folderDate.isAfter(_lastCloudUpdate!))) {
            _lastCloudUpdate = folderDate;
            print('⚠️ Файл не дал дату, взята дата папки: $_lastCloudUpdate');
          }
        }
      } catch (e) {
        print('❌ Не удалось получить дату папки: $e');
      }
    }

    if (_lastCloudUpdate == null) {
      print('⚠️ Не удалось получить дату ни файла, ни папки');
    }
  }

  Future<String?> _startLocalServer() async {
    HttpServer? server;
    try {
      server = await HttpServer.bind('localhost', 8080);
      print('Локальный сервер запущен на http://localhost:8080');

      String? code;
      await for (var request in server) {
        final uri = request.uri;
        print('Получен запрос: $uri');
        print('Параметры запроса: ${uri.queryParameters}');

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
            print(
                'Описание ошибки: ${uri.queryParameters['error_description']}');
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
      _currentGrant = null; // Очищаем предыдущий grant

      final grant = oauth2.AuthorizationCodeGrant(
        _yandexClientId,
        Uri.parse(_yandexAuthEndpoint),
        Uri.parse(_yandexTokenEndpoint),
        secret: _yandexClientSecret,
        httpClient: http.Client(),
      );

      _currentGrant = grant;

      final redirectUri = Platform.isAndroid
          ? Uri.parse(_yandexRedirectUri) // mycactus://callback
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

      // Сохраняем токены
      await _storage.write(
          key: 'yandex_access_token',
          value: _yandexClient!.credentials.accessToken);
      await _storage.write(
          key: 'yandex_refresh_token',
          value: _yandexClient!.credentials.refreshToken!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cloud_storage_type', 'yandex');
      await prefs.setBool('has_seen_welcome', true);
      await prefs.setBool(
          'remember_me', true); // ← важно для следующего запуска

      _currentStorageType = 'yandex';
      _isConnected = true;

      await _createAppFolders();
      notifyListeners();

      print('✅ Авторизация успешно завершена и токены сохранены');
    } catch (e) {
      print('Ошибка при обмене кода на токен: $e');
      rethrow;
    }
  }

  Future<void> _createAppFolders() async {
    if (!_isConnected || _yandexClient == null) return;

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';
    try {
      // Создаем папку /MyCactus
      print('Создание папки /MyCactus...');
      final myCactusResponse =
          await dio.put('$_yandexApiBaseUrl/resources?path=/MyCactus');
      print('Ответ создания /MyCactus: ${myCactusResponse.statusCode}');

      // Проверяем существование /MyCactus/photos
      print('Проверка существования /MyCactus/photos...');
      final checkPhotosResponse = await dio.get(
        '$_yandexApiBaseUrl/resources?path=/MyCactus/photos',
      );
      if (checkPhotosResponse.statusCode != 200) {
        print('Папка /MyCactus/photos не существует, создаем...');
        final photosResponse = await dio.put(
          '$_yandexApiBaseUrl/resources?path=/MyCactus/photos',
        );
        print('Ответ создания /MyCactus/photos: ${photosResponse.statusCode}');
      } else {
        print('Папка /MyCactus/photos уже существует');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        print('Папка уже существует, продолжаем...');
      } else {
        print('Ошибка создания папок: $e');
        throw Exception('Не удалось создать папки на Яндекс.Диске: $e');
      }
    }
  }

  Future<void> syncData(PlantProvider plantProvider) async {
    if (!_isConnected || _yandexClient == null) {
      print('Синхронизация невозможна: нет подключения');
      return;
    }

    try {
      await fetchLastCloudUpdate();
      final localUpdate = plantProvider.lastLocalUpdate;
      final cloudUpdate = lastCloudUpdate;

      final timeTolerance = const Duration(seconds: 2);

      if (cloudUpdate != null &&
          (localUpdate == null ||
              cloudUpdate.isAfter(localUpdate.add(timeTolerance)))) {
        print('☁️ Облако новее → загружаем из облака');
        await plantProvider.createLocalBackup();
        await loadDataFromCloud(plantProvider);
        await plantProvider.savePlants();
        return;
      }

      if (plantProvider.plants.isNotEmpty) {
        print('📤 Локальные данные новее → отправляем в облако');
        await _uploadToCloud(plantProvider);
        await fetchLastCloudUpdate();
      } else if (cloudUpdate != null) {
        print('📥 Локально пусто → загружаем из облака');
        await plantProvider.createLocalBackup();
        await loadDataFromCloud(plantProvider);
        await plantProvider.savePlants();
      }

      print('✅ Синхронизация успешно завершена');
    } catch (e) {
      print('❌ Ошибка синхронизации: $e');
    }
  }

  Future<void> _uploadToCloud(PlantProvider plantProvider) async {
    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    final now = DateTime.now().toUtc();
    plantProvider.setLastLocalUpdate(now);

    final plantProviderData = utf8.encode(jsonEncode(plantProvider.toJson()));

    try {
      final uploadResponse = await dio.get(
        '$_yandexApiBaseUrl/resources/upload?path=/MyCactus/plant_provider.json&overwrite=true',
      );
      final uploadUrl = uploadResponse.data['href'];

      final putResponse = await http.put(
        Uri.parse(uploadUrl),
        body: plantProviderData,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );

      if (putResponse.statusCode != 201 && putResponse.statusCode != 200) {
        throw Exception('Ошибка загрузки в облако: ${putResponse.statusCode}');
      }

      print('✅ plant_provider.json успешно загружен в облако. Дата: $now');
      _lastCloudUpdate = now;
    } catch (e) {
      print('❌ Ошибка загрузки plant_provider.json: $e');
      rethrow;
    }

    await syncUserPhotos(plantProvider);
  }

  Future<void> loadFromCloud(BuildContext context) async {
    if (!context.mounted) return;
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    await loadDataFromCloud(plantProvider);
  }

  Future<void> loadDataFromCloud(PlantProvider plantProvider) async {
    if (!_isConnected || _yandexClient == null) return;

    await plantProvider.createLocalBackup();

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    try {
      final downloadResponse = await dio.get(
        '$_yandexApiBaseUrl/resources/download?path=/MyCactus/plant_provider.json',
      );
      final downloadUrl = downloadResponse.data['href'];
      final fileResponse = await http.get(Uri.parse(downloadUrl));
      final data = jsonDecode(utf8.decode(fileResponse.bodyBytes));

      print('📥 Загружено из облака: ${data['plants']?.length ?? 0} растений');

      plantProvider.loadFromCloudJson(data);
      plantProvider.notifyListeners();

      await fetchLastCloudUpdate();
      if (_lastCloudUpdate != null) {
        plantProvider.setLastLocalUpdate(_lastCloudUpdate!);
      }

      await plantProvider.ensureLocalPhotosExist();
      await plantProvider.cleanupLocalPhotosAfterCloudLoad();
      await _cleanDuplicatePhotos(plantProvider);

      print('✅ Данные загружены из облака + фото обработаны');
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        await _createEmptyPlantProviderFile(dio);
      } else {
        print('❌ Ошибка загрузки из облака: $e');
      }
    }
  }

  Future<void> _createEmptyPlantProviderFile(Dio dio) async {
    try {
      final emptyData = utf8.encode(jsonEncode({
        'plants': [],
        'globalWateringDates': [],
        'adultImages': {},
        'lastLocalUpdate': null,
        'winteringStartDate': null,
        'winteringEndDate': null,
        'winteringTemperature': null,
        'winteringLogEntries': [],
      }));
      final uploadResponse = await dio.get(
        '$_yandexApiBaseUrl/resources/upload?path=/MyCactus/plant_provider.json&overwrite=true',
      );
      final uploadUrl = uploadResponse.data['href'];
      final putResponse = await http.put(
        Uri.parse(uploadUrl),
        body: emptyData,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
      if (putResponse.statusCode != 201) {
        throw Exception(
            'Ошибка создания пустого plant_provider.json: ${putResponse.statusCode}');
      }
      print('Создан пустой файл plant_provider.json');
    } catch (e) {
      print('Ошибка создания пустого файла plant_provider.json: $e');
      rethrow;
    }
  }

  Future<String> uploadPhotoToYandexDisk(String filePath) async {
    if (!_isConnected || _yandexClient == null) {
      throw Exception('Нет подключения к Яндекс.Диску');
    }

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    final file = File(filePath);
    if (!await file.exists()) throw Exception('Файл не существует: $filePath');

    // Уникальное имя — главное исправление от дубликатов
    final uuid = const Uuid();
    final originalName = path.basename(filePath);
    final fileName = '${uuid.v4()}_$originalName';

    final cloudPath = '/MyCactus/photos/$fileName';

    try {
      // Создаём папку, если её нет
      try {
        await dio.get('$_yandexApiBaseUrl/resources?path=/MyCactus/photos');
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 404) {
          await dio.put('$_yandexApiBaseUrl/resources?path=/MyCactus/photos');
        }
      }

      final uploadResponse = await dio.get(
        '$_yandexApiBaseUrl/resources/upload?path=$cloudPath&overwrite=true',
      );
      final uploadUrl = uploadResponse.data['href'];

      final fileBytes = await file.readAsBytes();
      await http.put(
        Uri.parse(uploadUrl),
        body: fileBytes,
        headers: {'Content-Type': 'application/octet-stream'},
      );

      await dio.put('$_yandexApiBaseUrl/resources/publish?path=$cloudPath');

      final resourceResponse = await dio.get(
        '$_yandexApiBaseUrl/resources?path=$cloudPath',
      );
      final fileUrl = resourceResponse.data['file'] as String?;

      print('✅ Фото загружено в облако: $fileUrl');
      return fileUrl ?? '';
    } catch (e) {
      print('❌ Ошибка загрузки фото $filePath: $e');
      rethrow;
    }
  }

  Future<List<String>> getCloudPhotos() async {
    if (!_isConnected || _yandexClient == null) {
      return [];
    }

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    try {
      final response = await dio.get(
        '$_yandexApiBaseUrl/resources?path=/MyCactus/photos',
      );
      if (response.statusCode != 200) {
        print(
            'Ошибка получения списка файлов в облаке: ${response.statusCode}');
        return [];
      }

      final items = response.data['_embedded']['items'] as List<dynamic>?;
      if (items == null) {
        return [];
      }

      List<String> fileUrls = [];
      for (var item in items) {
        final cloudPath = item['path'] as String;
        final encodedPath =
            Uri.encodeComponent(cloudPath.replaceFirst('disk:', ''));
        try {
          final resourceResponse = await dio.get(
            '$_yandexApiBaseUrl/resources?path=$encodedPath',
          );
          final fileUrl = resourceResponse.data['file'] as String?;
          if (fileUrl != null) {
            fileUrls.add(fileUrl);
          }
        } catch (e) {
          print('Ошибка получения file URL для $cloudPath: $e');
          continue;
        }
      }
      return fileUrls;
    } catch (e) {
      print('Ошибка при загрузке списка файлов из облака: $e');
      return [];
    }
  }

  Future<void> deletePhotoFromYandexDisk(String fileUrl) async {
    if (!_isConnected || _yandexClient == null) {
      throw Exception('Нет подключения к Яндекс.Диску');
    }

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    try {
      // Извлекаем путь из cloud URL
      final cloudPath = _extractPathFromUrl(fileUrl);
      
      if (cloudPath != null) {
        // Удаляем файл навсегда
        await dio.delete('$_yandexApiBaseUrl/resources?path=$cloudPath&permanently=true');
        print('✅ Файл удален с Яндекс.Диска: $cloudPath');
      } else {
        print('⚠️ Не удалось извлечь путь из URL: $fileUrl');
      }
    } catch (e) {
      print('❌ Ошибка удаления файла с диска: $e');
      rethrow;
    }
  }
  
  /// Извлекает путь из cloud URL
  String? _extractPathFromUrl(String fileUrl) {
    try {
      final uri = Uri.parse(fileUrl);
      // Пример: https://cloud-api.yandex.net/v1/disk/resources/download?path=/MyCactus/photos/uuid_photo.jpg
      final pathParam = uri.queryParameters['path'];
      return pathParam;
    } catch (e) {
      return null;
    }
  }

  Future<void> syncUserPhotos(PlantProvider plantProvider) async {
    if (!_isConnected || _yandexClient == null) {
      print('Синхронизация фото невозможна: нет подключения');
      return;
    }

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    try {
      print('Проверка папки /MyCactus/photos...');
      await dio
          .get('$_yandexApiBaseUrl/resources?path=/MyCactus/photos')
          .catchError((e) async {
        if (e is DioException && e.response?.statusCode == 404) {
          print('Создаём папку /MyCactus/photos...');
          return await dio
              .put('$_yandexApiBaseUrl/resources?path=/MyCactus/photos');
        }
        throw e;
      });

      int uploadedCount = 0;

      for (var plant in plantProvider.plants) {
        final localPhotos = plant.userPhotos
            .where((photo) =>
                !photo.startsWith('https://') && !photo.startsWith('http://'))
            .toList();

        if (localPhotos.isEmpty) continue;

        final updatedPhotos = List<String>.from(plant.userPhotos);

        for (var localPhoto in localPhotos) {
          if ((localPhoto.startsWith('/data/user/0/') && !Platform.isAndroid) ||
              ((localPhoto.startsWith('C:\\') || localPhoto.contains(':\\')) &&
                  Platform.isAndroid)) {
            continue;
          }

          final file = File(localPhoto);
          if (!await file.exists()) continue;

          print('📤 Загружаем фото: $localPhoto');

          try {
            final fileUrl = await uploadPhotoToYandexDisk(localPhoto);

            // Валидируем доступность cloud URL
            if (!await _validateCloudUrl(fileUrl)) {
              print('❌ Cloud URL недоступен: $fileUrl');
              continue;
            }

            final index = updatedPhotos.indexOf(localPhoto);
            if (index != -1) {
              updatedPhotos[index] = fileUrl;
              uploadedCount++;
              print('✅ Фото заменено на cloud URL: $fileUrl');
            }
          } catch (e) {
            print('❌ Ошибка загрузки $localPhoto: $e');
          }
        }

        if (updatedPhotos != plant.userPhotos) {
          final updatedPlant = plant.copyWith(userPhotos: updatedPhotos);
          plantProvider.updatePlant(plant.permanentId, updatedPlant);
        }
      }

      await _cleanDuplicatePhotos(plantProvider); // ← уже есть, хорошо

      print('✅ Синхронизация фото завершена. Загружено: $uploadedCount фото');
      await fetchLastCloudUpdate();
      if (_lastCloudUpdate != null) {
        plantProvider.setLastLocalUpdate(_lastCloudUpdate!);
      }
      
      // === НОВОЕ: Синхронизация удаленных фото ===
      await _syncDeletedPhotos(plantProvider);
      
    } catch (e) {
      print('Ошибка синхронизации пользовательских фото: $e');
    }
  }

// === СИНХРОНИЗАЦИЯ УДАЛЕННЫХ ФОТО ===
  Future<void> _syncDeletedPhotos(PlantProvider plantProvider) async {
    print('🔄 Начинаем синхронизацию удаленных фото...');
    
    // Синхронизация удаленных своих фото
    if (plantProvider.deletedUserPhotos.isNotEmpty) {
      print('🗑️ Удаляем свои фото с облака: ${plantProvider.deletedUserPhotos.length}');
      for (var deletedUrl in plantProvider.deletedUserPhotos) {
        try {
          await deletePhotoFromYandexDisk(deletedUrl);
          print('✅ Своё фото удалено с облака: $deletedUrl');
        } catch (e) {
          print('❌ Ошибка удаления своего фото: $e');
        }
      }
    }
    
    // Синхронизация удаленных Llifle фото
    if (plantProvider.deletedLliflePhotos.isNotEmpty) {
      print('🗑️ Удаляем Llifle фото из данных: ${plantProvider.deletedLliflePhotos.length}');
      for (var deletedUrl in plantProvider.deletedLliflePhotos) {
        try {
          // Llifle фото не удаляем с облака (это внешние URL),
          // только убираем из локальных данных
          print('✅ Llifle фото убрано из данных: $deletedUrl');
        } catch (e) {
          print('❌ Ошибка удаления Llifle фото: $e');
        }
      }
    }
    
    // Очищаем списки удаленных фото
    plantProvider.clearDeletedPhotos();
    print('✅ Синхронизация удаленных фото завершена');
  }

  Future<void> disconnect() async {
    await _storage.delete(key: 'yandex_access_token');
    await _storage.delete(key: 'yandex_refresh_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cloud_storage_type');
    _yandexClient?.close();
    _yandexClient = null;
    _isConnected = false;
    _currentStorageType = null;
    _lastCloudUpdate = null;
    notifyListeners();
  }

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
        await _createAppFolders();
        await fetchLastCloudUpdate();
        notifyListeners();
        print('✅ Тихое подключение к Яндекс.Диску успешно');
      } catch (e) {
        print('Ошибка тихого подключения: $e');
        _isConnected = false;
      }
    }
  }

  // Вызывается после загрузки из облака для полного обновления UI и статистики
  void invalidateAllCaches(PlantProvider plantProvider) {
    print(
        '🔄 CloudStorageProvider → вызываем полный сброс кэшей в PlantProvider');
    plantProvider.invalidateAllCaches();
  }

  Future<void> _cleanDuplicatePhotos(PlantProvider plantProvider) async {
    bool changed = false;

    for (var plant in List.from(plantProvider.plants)) {
      final unique = <String>{};
      final cleaned = <String>[];

      for (var photo in plant.userPhotos) {
        final dedupeKey = _photoDedupKey(photo);
        if (unique.add(dedupeKey)) {
          cleaned.add(photo);
        } else {
          print('🗑️ Удалён дубликат: $photo');
          changed = true;
        }
      }

      if (cleaned.length != plant.userPhotos.length) {
        final updatedPlant = plant.copyWith(userPhotos: cleaned);
        plantProvider.updatePlant(plant.permanentId, updatedPlant);
        changed = true;
      }
    }

    if (changed) {
      await plantProvider.savePlants();
      print('✅ Дублей фото очищено');
    }
  }

  String _photoDedupKey(String photo) {
    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      final uri = Uri.tryParse(photo);
      if (uri != null) {
        return '${uri.scheme}://${uri.host}${uri.path}'.toLowerCase();
      }
    }
    return photo;
  }
  
  /// Валидирует доступность cloud URL
  Future<bool> _validateCloudUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  
  // === ВРЕМЕННО ЗАКОММЕНТИРОВАНО — не используется после унификации ===
  // void _cleanInvalidPhotoUrls(PlantProvider plantProvider) {
  //   bool changed = false;
  //   for (var plant in List.from(plantProvider.plants)) {
  //     final validPhotos = <String>[];
  //     for (var photo in plant.userPhotos) {
  //       if (photo.startsWith('https://')) {
  //         validPhotos.add(photo);
  //       } else {
  //         validPhotos.add(photo);
  //       }
  //     }
  //     if (validPhotos.length != plant.userPhotos.length) {
  //       final updatedPlant = plant.copyWith(userPhotos: validPhotos);
  //       plantProvider.updatePlant(plant.permanentId, updatedPlant);
  //       changed = true;
  //       print('🗑️ Удалена невалидная фото-ссылка у растения ${plant.displayId}');
  //     }
  //   }
  //   if (changed) {
  //     plantProvider.savePlants();
  //     print('✅ Сохранены изменения после очистки фото');
  //   }
  // }
}
