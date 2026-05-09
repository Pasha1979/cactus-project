import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'plant_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class CloudStorageProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  oauth2.Client? _yandexClient;
  bool _isConnected = false;
  bool _isSyncing = false;
  String? _currentStorageType;
  bool _isAuthorizing = false;
  DateTime? _lastCloudUpdate;

  static const String _yandexClientId = '066c5dd1fda94c15ac2dc248cdb0f1e8';
  static const String _yandexClientSecret = 'c624749917a34e6a8579e5ff2685f0f7';
  static const String _yandexRedirectUri = 'http://localhost:8080';
  static const String _yandexAuthEndpoint =
      'https://oauth.yandex.com/authorize';
  static const String _yandexTokenEndpoint = 'https://oauth.yandex.com/token';
  static const String _yandexApiBaseUrl =
      'https://cloud-api.yandex.net/v1/disk';

  bool get isConnected => _isConnected;
  bool get isSyncing => _isSyncing;
  String? get currentStorageType => _currentStorageType;
  DateTime? get lastCloudUpdate => _lastCloudUpdate;

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
          print('✅ Токены загружены, Яндекс.Диск подключён');
        }
      }
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка загрузки токенов: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> fetchLastCloudUpdate() async {
    if (!_isConnected || _yandexClient == null) {
      _lastCloudUpdate = null;
      return;
    }

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    try {
      final fileResponse = await dio.get(
        '$_yandexApiBaseUrl/resources?path=/MyCactus/plant_provider.json',
      );
      if (fileResponse.statusCode == 200) {
        final modified = fileResponse.data['modified'] as String?;
        _lastCloudUpdate = DateTime.tryParse(modified ?? '');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode != 404) {
        print('⚠️ Ошибка получения даты файла: $e');
      }
    }
  }

  // === ТВОЙ СУЩЕСТВУЮЩИЙ МЕТОД _startLocalServer — ОСТАЁТСЯ БЕЗ ИЗМЕНЕНИЙ ===
  Future<String?> _startLocalServer() async {
    HttpServer? server;
    try {
      server = await HttpServer.bind('localhost', 8080);
      print('Локальный сервер запущен на http://localhost:8080');

      String? code;
      await for (var request in server) {
        final uri = request.uri;
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
        } else if (uri.queryParameters.containsKey('error')) {
          print('Ошибка от Yandex: ${uri.queryParameters['error']}');
        }
      }
      return code;
    } catch (e) {
      print('Ошибка запуска локального сервера: $e');
      rethrow;
    } finally {
      await server?.close(force: true);
    }
  }

  // === ТВОЙ МЕТОД connectToYandexDisk — ОСТАЁТСЯ БЕЗ ИЗМЕНЕНИЙ ===
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
      final grant = oauth2.AuthorizationCodeGrant(
        _yandexClientId,
        Uri.parse(_yandexAuthEndpoint),
        Uri.parse(_yandexTokenEndpoint),
        secret: _yandexClientSecret,
        httpClient: http.Client(),
      );

      final authorizationUrl = grant.getAuthorizationUrl(
        Uri.parse(_yandexRedirectUri),
        scopes: ['cloud_api:disk.read', 'cloud_api:disk.write'],
      );

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
                'Авторизуйтесь в браузере.\nПосле этого самостоятельно закройте браузер и вернитесь в приложение.'),
            duration: Duration(seconds: 15),
          ),
        );
      }

      // Для Windows запускаем локальный сервер
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
    try {
      _yandexClient = await grant.handleAuthorizationResponse({
        'code': code,
        'redirect_uri': _yandexRedirectUri,
      });

      await _storage.write(
          key: 'yandex_access_token',
          value: _yandexClient!.credentials.accessToken);
      await _storage.write(
          key: 'yandex_refresh_token',
          value: _yandexClient!.credentials.refreshToken!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cloud_storage_type', 'yandex');
      await prefs.setBool('has_seen_welcome', true);
      await prefs.setBool('remember_me', true);

      _currentStorageType = 'yandex';
      _isConnected = true;

      await _createAppFolders();
      notifyListeners();

      print('✅ Авторизация успешно завершена');
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
      await dio.put('$_yandexApiBaseUrl/resources?path=/MyCactus');
      try {
        await dio.get('$_yandexApiBaseUrl/resources?path=/MyCactus/photos');
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 404) {
          await dio.put('$_yandexApiBaseUrl/resources?path=/MyCactus/photos');
        }
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        // Папка уже существует
      } else {
        print('Ошибка создания папок: $e');
      }
    }
  }

  // ==================== ГЛАВНЫЕ МЕТОДЫ СИНХРОНИЗАЦИИ ====================

  Future<void> syncData(PlantProvider plantProvider) async {
    if (!_isConnected || _yandexClient == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      await fetchLastCloudUpdate();
      final localUpdate = plantProvider.lastLocalUpdate;
      final cloudUpdate = _lastCloudUpdate;

      final timeTolerance = const Duration(seconds: 2);

      if (cloudUpdate != null &&
          (localUpdate == null ||
              cloudUpdate.isAfter(localUpdate.add(timeTolerance)))) {
        await plantProvider.createLocalBackup();
        await loadDataFromCloud(plantProvider);
        await plantProvider.savePlants();
        return;
      }

      if (plantProvider.plants.isNotEmpty) {
        await _uploadToCloud(plantProvider);
      } else if (cloudUpdate != null) {
        await plantProvider.createLocalBackup();
        await loadDataFromCloud(plantProvider);
        await plantProvider.savePlants();
      }
    } catch (e) {
      print('❌ Ошибка синхронизации: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
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

      await http.put(
        Uri.parse(uploadUrl),
        body: plantProviderData,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );

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

      // Загружаем данные
      if (plantProvider.plants.isEmpty) {
        plantProvider.loadFromCloudJson(data);
      } else {
        // Если растения уже есть — используем безопасную замену
        plantProvider.loadFromCloudJson(data);
      }
      plantProvider.notifyListeners();

      await fetchLastCloudUpdate();
      if (_lastCloudUpdate != null) {
        plantProvider.setLastLocalUpdate(_lastCloudUpdate!);
      }

      // КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ — скачиваем фото локально
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
    // ... (оставляем как было)
  }

// === ИСПРАВЛЕННЫЙ uploadPhotoToYandexDisk (гибридный подход) ===
  Future<String> uploadPhotoToYandexDisk(String filePath) async {
    if (!_isConnected || _yandexClient == null) {
      throw Exception('Нет подключения к Яндекс.Диску');
    }

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    final file = File(filePath);
    if (!await file.exists()) throw Exception('Файл не существует: $filePath');

    // === Умное имя: uuid + оригинальное имя (избегаем коллизий) ===
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
    // ... (оставляем как было в твоей версии)
    if (!_isConnected || _yandexClient == null) return [];

    final dio = Dio();
    dio.options.headers['Authorization'] =
        'OAuth ${_yandexClient!.credentials.accessToken}';

    try {
      final response =
          await dio.get('$_yandexApiBaseUrl/resources?path=/MyCactus/photos');
      final items = response.data['_embedded']['items'] as List<dynamic>? ?? [];
      List<String> fileUrls = [];
      for (var item in items) {
        final cloudPath = item['path'] as String;
        final encodedPath =
            Uri.encodeComponent(cloudPath.replaceFirst('disk:', ''));
        try {
          final res =
              await dio.get('$_yandexApiBaseUrl/resources?path=$encodedPath');
          final url = res.data['file'] as String?;
          if (url != null) fileUrls.add(url);
        } catch (_) {}
      }
      return fileUrls;
    } catch (e) {
      return [];
    }
  }

// === ИСПРАВЛЕННАЯ СИНХРОНИЗАЦИЯ ФОТО (гибридный подход) ===
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
          // Пропускаем пути другой платформы
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

      await _cleanDuplicatePhotos(plantProvider);

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

// === УЛУЧШЕННАЯ ОЧИСТКА ДУБЛЕЙ ===
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
          print('🗑️ Удалён дубликат: $photo у растения ${plant.displayId}');
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
  
  /// Удаляет фото с Яндекс.Диска
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

  // Улучшенный метод скачивания фото при загрузке из облака
  Future<void> ensureLocalPhotosExist() async {
    // Этот метод будет вызываться из plant_provider.dart
    // Пока оставляем заглушку — реализуем в plant_provider
    print('ensureLocalPhotosExist вызван из CloudStorageProvider');
  }

  Future<void> connectToYandexDiskSilently() async {
    if (_isConnected) {
      return;
    }

    final accessToken = await _storage.read(key: 'yandex_access_token');
    final refreshToken = await _storage.read(key: 'yandex_refresh_token');

    if (accessToken == null || refreshToken == null) {
      _isConnected = false;
      notifyListeners();
      return;
    }

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
      print('❌ Тихое подключение не удалось: $e');
      _isConnected = false;
      notifyListeners();
    }
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
}
