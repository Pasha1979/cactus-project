import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import 'yandex_auth_service.dart';

/// Сервис для низкоуровневых операций с Яндекс.Диск API
///
/// Отвечает за:
/// - Создание папок
/// - Загрузку/скачивание файлов
/// - CRUD операции с ресурсами на диске
class YandexDiskService {
  static const String _yandexApiBaseUrl =
      'https://cloud-api.yandex.net/v1/disk';

  final YandexAuthService _authService;

  YandexDiskService(this._authService);

  Dio _createDio() {
    final dio = Dio();
    final client = _authService.yandexClient;
    if (client != null) {
      dio.options.headers['Authorization'] =
          'OAuth ${client.credentials.accessToken}';
    }
    return dio;
  }

  // ==================== ПАПКИ ====================

  Future<void> createAppFolders() async {
    if (!_authService.isConnected) return;

    final dio = _createDio();
    try {
      print('Создание папки /MyCactus...');
      final myCactusResponse =
          await dio.put('$_yandexApiBaseUrl/resources?path=/MyCactus');
      print('Ответ создания /MyCactus: ${myCactusResponse.statusCode}');

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

  // ==================== UPLOAD / DOWNLOAD ====================

  /// Загружает JSON-данные в облако как plant_provider.json
  Future<void> uploadJsonFile(List<int> data) async {
    if (!_authService.isConnected) throw Exception('Нет подключения');

    final dio = _createDio();

    final uploadResponse = await dio.get(
      '$_yandexApiBaseUrl/resources/upload?path=/MyCactus/plant_provider.json&overwrite=true',
    );
    final uploadUrl = uploadResponse.data['href'];

    final putResponse = await http.put(
      Uri.parse(uploadUrl),
      body: data,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );

    if (putResponse.statusCode != 201 && putResponse.statusCode != 200) {
      throw Exception('Ошибка загрузки в облако: ${putResponse.statusCode}');
    }

    print('✅ plant_provider.json успешно загружен в облако');
  }

  /// Скачивает plant_provider.json из облака
  Future<Map<String, dynamic>> downloadJsonFile() async {
    if (!_authService.isConnected) throw Exception('Нет подключения');

    final dio = _createDio();

    final downloadResponse = await dio.get(
      '$_yandexApiBaseUrl/resources/download?path=/MyCactus/plant_provider.json',
    );
    final downloadUrl = downloadResponse.data['href'];
    final fileResponse = await http.get(Uri.parse(downloadUrl));

    return jsonDecode(utf8.decode(fileResponse.bodyBytes))
        as Map<String, dynamic>;
  }

  /// Создаёт пустой plant_provider.json в облаке
  Future<void> createEmptyPlantProviderFile() async {
    if (!_authService.isConnected) throw Exception('Нет подключения');

    final dio = _createDio();

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
  }

  // ==================== ФОТО ====================

  Future<String> uploadPhoto(String filePath) async {
    if (!_authService.isConnected) {
      throw Exception('Нет подключения к Яндекс.Диску');
    }

    final dio = _createDio();
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Файл не существует: $filePath');

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
    if (!_authService.isConnected) return [];

    final dio = _createDio();

    try {
      final response = await dio.get(
        '$_yandexApiBaseUrl/resources?path=/MyCactus/photos',
      );
      if (response.statusCode != 200) return [];

      final items = response.data['_embedded']['items'] as List<dynamic>?;
      if (items == null) return [];

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

  Future<void> deletePhoto(String fileUrl) async {
    if (!_authService.isConnected) {
      throw Exception('Нет подключения к Яндекс.Диску');
    }

    final dio = _createDio();

    try {
      final cloudPath = _extractPathFromUrl(fileUrl);
      if (cloudPath != null) {
        await dio.delete(
            '$_yandexApiBaseUrl/resources?path=$cloudPath&permanently=true');
        print('✅ Файл удален с Яндекс.Диска: $cloudPath');
      } else {
        print('⚠️ Не удалось извлечь путь из URL: $fileUrl');
      }
    } catch (e) {
      print('❌ Ошибка удаления файла с диска: $e');
      rethrow;
    }
  }

  String? _extractPathFromUrl(String fileUrl) {
    try {
      final uri = Uri.parse(fileUrl);
      return uri.queryParameters['path'];
    } catch (e) {
      return null;
    }
  }

  // ==================== ДАТА МОДИФИКАЦИИ ====================

  Future<DateTime?> getFileModifiedDate(String filePath) async {
    if (!_authService.isConnected) return null;

    final dio = _createDio();
    try {
      final response = await dio.get(
        '$_yandexApiBaseUrl/resources?path=$filePath',
      );
      if (response.statusCode == 200) {
        final modified = response.data['modified'] as String?;
        return DateTime.tryParse(modified ?? '');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        print('⚠️ Ошибка запроса файла: $e');
      }
    } catch (e) {
      print('⚠️ Неизвестная ошибка запроса файла: $e');
    }
    return null;
  }

  Future<DateTime?> getFolderModifiedDate(String folderPath) async {
    if (!_authService.isConnected) return null;

    final dio = _createDio();
    try {
      final response = await dio.get(
        '$_yandexApiBaseUrl/resources?path=$folderPath',
      );
      if (response.statusCode == 200) {
        final modified = response.data['modified'] as String?;
        return DateTime.tryParse(modified ?? '');
      }
    } catch (e) {
      print('❌ Не удалось получить дату папки: $e');
    }
    return null;
  }
}
