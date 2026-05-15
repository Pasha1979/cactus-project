import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../core/logger/app_logger.dart';
import 'yandex_auth_service.dart';

/// Сервис для низкоуровневых операций с Яндекс.Диск API
///
/// Отвечает за:
/// - Создание папок
/// - Загрузку/скачивание файлов
/// - CRUD операции с ресурсами на диске
class YandexDiskService {

  YandexDiskService(this._authService);
  static const String _yandexApiBaseUrl =
      'https://cloud-api.yandex.net/v1/disk';

  final YandexAuthService _authService;

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
      AppLogger.api('Создание папки /MyCactus...', tag: 'YANDEX_DISK');
      final myCactusResponse =
          await dio.put('$_yandexApiBaseUrl/resources?path=/MyCactus');
      AppLogger.api('Ответ создания /MyCactus: ${myCactusResponse.statusCode}', tag: 'YANDEX_DISK');

      final checkPhotosResponse = await dio.get(
        '$_yandexApiBaseUrl/resources?path=/MyCactus/photos',
      );
      if (checkPhotosResponse.statusCode != 200) {
        AppLogger.api('Папка /MyCactus/photos не существует, создаем...', tag: 'YANDEX_DISK');
        final photosResponse = await dio.put(
          '$_yandexApiBaseUrl/resources?path=/MyCactus/photos',
        );
        AppLogger.api('Ответ создания /MyCactus/photos: ${photosResponse.statusCode}', tag: 'YANDEX_DISK');
      } else {
        AppLogger.api('Папка /MyCactus/photos уже существует', tag: 'YANDEX_DISK');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        AppLogger.warning('Папка уже существует, продолжаем...', tag: 'YANDEX_DISK');
      } else {
        AppLogger.error('Ошибка создания папок: $e', tag: 'YANDEX_DISK');
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

    AppLogger.api('✅ plant_provider.json успешно загружен в облако', tag: 'YANDEX_DISK');
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
    }),);

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
          'Ошибка создания пустого plant_provider.json: ${putResponse.statusCode}',);
    }
    AppLogger.api('Создан пустой файл plant_provider.json', tag: 'YANDEX_DISK');
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

      AppLogger.api('✅ Фото загружено в облако: $fileUrl', tag: 'YANDEX_DISK');
      return fileUrl ?? '';
    } catch (e) {
      AppLogger.error('❌ Ошибка загрузки фото $filePath: $e', tag: 'YANDEX_DISK');
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
          AppLogger.error('Ошибка получения file URL для $cloudPath: $e', tag: 'YANDEX_DISK');
          continue;
        }
      }
      return fileUrls;
    } catch (e) {
      AppLogger.error('Ошибка при загрузке списка файлов из облака: $e', tag: 'YANDEX_DISK');
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
            '$_yandexApiBaseUrl/resources?path=$cloudPath&permanently=true',);
        AppLogger.api('✅ Файл удален с Яндекс.Диска: $cloudPath', tag: 'YANDEX_DISK');
      } else {
        AppLogger.warning('⚠️ Не удалось извлечь путь из URL: $fileUrl', tag: 'YANDEX_DISK');
      }
    } catch (e) {
      AppLogger.error('❌ Ошибка удаления файла с диска: $e', tag: 'YANDEX_DISK');
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
        AppLogger.warning('⚠️ Ошибка запроса файла: $e', tag: 'YANDEX_DISK');
      }
    } catch (e) {
        AppLogger.warning('⚠️ Неизвестная ошибка запроса файла: $e', tag: 'YANDEX_DISK');
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
      AppLogger.error('❌ Не удалось получить дату папки: $e', tag: 'YANDEX_DISK');
    }
    return null;
  }

  // ==================== ВЕРСИОНИРОВАНИЕ БЭКАПОВ ====================

  /// Загружает бэкап с уникальным именем (версионирование).
  ///
  /// Создаёт файл в папке `/MyCactus/backups/` с именем вида
  /// `plant_backup_20260515_1230.json`.
  Future<String> uploadVersionedBackup(List<int> data, String fileName) async {
    if (!_authService.isConnected) throw Exception('Нет подключения');

    final dio = _createDio();

    // Убедиться, что папка backups существует
    try {
      await dio.put('$_yandexApiBaseUrl/resources?path=/MyCactus/backups');
    } on DioException catch (e) {
      if (e.response?.statusCode != 409) {
        AppLogger.error('Ошибка создания /MyCactus/backups: $e', tag: 'YANDEX_DISK');
      }
    }

    final cloudPath = '/MyCactus/backups/$fileName';

    final uploadResponse = await dio.get(
      '$_yandexApiBaseUrl/resources/upload?path=$cloudPath&overwrite=true',
    );
    final uploadUrl = uploadResponse.data['href'];

    final putResponse = await http.put(
      Uri.parse(uploadUrl),
      body: data,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );

    if (putResponse.statusCode != 201 && putResponse.statusCode != 200) {
      throw Exception('Ошибка загрузки версии бэкапа: ${putResponse.statusCode}');
    }

    AppLogger.api('✅ Версионный бэкап загружен: $cloudPath', tag: 'YANDEX_DISK');
    return cloudPath;
  }

  /// Возвращает список файлов бэкапов из папки `/MyCactus/backups/`.
  ///
  /// Файлы отсортированы по дате (новые первыми).
  Future<List<Map<String, dynamic>>> listVersionedBackups() async {
    if (!_authService.isConnected) return [];

    final dio = _createDio();
    try {
      final response = await dio.get(
        '$_yandexApiBaseUrl/resources?path=/MyCactus/backups&limit=100&sort=-modified',
      );

      if (response.statusCode != 200) return [];

      final items = response.data['_embedded']?['items'] as List<dynamic>?;
      if (items == null) return [];

      return items
          .where(
            (item) =>
                item['type'] == 'file' &&
                (item['name'] as String).endsWith('.json'),
          )
          .map(
            (item) => {
              'name': item['name'] as String,
              'path': item['path'] as String,
              'modified': item['modified'] as String?,
              'size': item['size'] as int? ?? 0,
            },
          )
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      AppLogger.error('Ошибка получения списка бэкапов: $e', tag: 'YANDEX_DISK');
      return [];
    }
  }

  /// Удаляет файл с Яндекс.Диска.
  Future<void> deleteCloudFile(String cloudPath) async {
    if (!_authService.isConnected) throw Exception('Нет подключения');

    final dio = _createDio();
    try {
      await dio.delete(
        '$_yandexApiBaseUrl/resources?path=$cloudPath&permanently=true',
      );
      AppLogger.api('🗑️ Удалён файл: $cloudPath', tag: 'YANDEX_DISK');
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        throw Exception('Ошибка удаления файла $cloudPath: $e');
      }
    }
  }
}
