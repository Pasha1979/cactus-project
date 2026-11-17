import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_constants.dart';
import '../../core/logger/app_logger.dart';
import '../../models/plant.dart';
import '../../services/image/image_processor.dart';

/// Провайдер для управления фотографиями растений
///
/// Отвечает за:
/// - Добавление/удаление фото пользователя
/// - Управление Llifle фото
/// - Adult images
/// - Локальный кэш облачных фото
///
/// DI: PhotoRepository зарегистрирован в injection_container.dart
class PhotoProvider with ChangeNotifier {

  final Set<String> _deletedUserPhotos = {};
  final Set<String> _deletedLliflePhotos = {};
  bool _needsPhotoSync = false;

  // ==================== ГЕТТЕРЫ ====================
  Set<String> get deletedUserPhotos => Set.unmodifiable(_deletedUserPhotos);
  Set<String> get deletedLliflePhotos => Set.unmodifiable(_deletedLliflePhotos);
  bool get needsPhotoSync => _needsPhotoSync;

  // ==================== USER PHOTOS ====================
  Future<String> addUserPhoto(String originalPath) async {
    final newPath = await _copyPhotoToAppStorage(originalPath);
    _needsPhotoSync = true;
    notifyListeners();
    return newPath;
  }

  Future<void> removeUserPhoto(Plant plant, String photoPath) async {
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      _deletedUserPhotos.add(photoPath);
    }
    await _deletePhotoFromStorage(photoPath);
    _needsPhotoSync = true;
    notifyListeners();
  }

  // ==================== LLIFLE PHOTOS ====================
  void markLliflePhotoAsDeleted(String photoUrl) {
    _deletedLliflePhotos.add(photoUrl);
    _needsPhotoSync = true;
    notifyListeners();
  }

  // ==================== ADULT IMAGES ====================
  Map<String, String?> _adultImages = {};

  String? getAdultImage(String plantId) => _adultImages[plantId];

  Map<String, String?> get adultImages => Map.unmodifiable(_adultImages);

  /// Загрузка adultImages из SharedPreferences
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(PrefsKeys.adultImages);
      if (json != null) {
        final decoded = jsonDecode(json) as Map<String, dynamic>?;
        if (decoded != null) {
          _adultImages = decoded.map((k, v) => MapEntry(k, v as String?));
        }
      } else {
        _adultImages = {};
      }
      notifyListeners();
      AppLogger.api('✅ PhotoProvider loaded: ${_adultImages.length} adult images', tag: 'PHOTO');
    } catch (e) {
      AppLogger.error('❌ PhotoProvider load error: $e', tag: 'PHOTO');
      _adultImages = {};
    }
  }

  Future<void> _saveAdultImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.adultImages, jsonEncode(_adultImages));
    } catch (e) {
      AppLogger.error('❌ PhotoProvider save error: $e', tag: 'PHOTO');
    }
  }

  void updateAdultImage(String plantId, String imageUrl) {
    _adultImages[plantId] = imageUrl;
    _saveAdultImages();
    _needsPhotoSync = true;
    notifyListeners();
  }

  // ==================== СИНХРОНИЗАЦИЯ ====================
  void resetPhotoSyncFlag() {
    _needsPhotoSync = false;
  }

  void markNeedsPhotoSync() {
    _needsPhotoSync = true;
    notifyListeners();
  }

  void clearDeletedPhotos() {
    _deletedUserPhotos.clear();
    _deletedLliflePhotos.clear();
  }

  // ==================== МАССОВЫЕ ОПЕРАЦИИ ====================

  /// Очистить неиспользуемые фото у выбранных растений.
  Future<int> cleanupUnusedPhotosForSelected(
      List<Plant> plants, Set<String> selectedIds,) async {
    final photosDir = await _getPhotosDirectory();
    final dir = Directory(photosDir);
    if (!await dir.exists()) return 0;

    final usedPaths = <String>{};
    for (var plant in plants) {
      if (selectedIds.contains(plant.permanentId)) {
        for (var photo in plant.userPhotos) {
          if (!photo.startsWith('https://')) {
            usedPaths.add(photo);
          }
        }
      }
    }

    int deletedCount = 0;
    final allLocalFiles = await dir.list().toList();
    for (var fileEntity in allLocalFiles) {
      if (fileEntity is File && !usedPaths.contains(fileEntity.path)) {
        try {
          await fileEntity.delete();
          deletedCount++;
        } catch (e) {
          AppLogger.warning('⚠️ Не удалось удалить: ${fileEntity.path}', tag: 'PHOTO');
        }
      }
    }
    return deletedCount;
  }

  /// Удалить все фото у выбранных растений.
  /// Возвращает список plantId, у которых были удалены фото.
  Future<List<String>> deleteAllPhotosForSelected(
      List<Plant> plants, Set<String> selectedIds,) async {
    final updatedIds = <String>[];
    for (var plant in plants) {
      if (selectedIds.contains(plant.permanentId)) {
        for (var photo in plant.userPhotos) {
          await _deletePhotoFromStorage(photo);
        }
        _adultImages.remove(plant.permanentId);
        updatedIds.add(plant.permanentId);
      }
    }
    if (updatedIds.isNotEmpty) {
      _needsPhotoSync = true;
      notifyListeners();
    }
    return updatedIds;
  }

  // ==================== ФАЙЛОВАЯ СИСТЕМА ====================
  Future<String> _getPhotosDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${directory.path}/plant_photos');
    if (!await photosDir.exists()) {
      await photosDir.create();
    }
    return photosDir.path;
  }

  Future<String> _copyPhotoToAppStorage(String originalPath) async {
    final photosDir = await _getPhotosDirectory();
    final baseName = path.basename(originalPath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$baseName';
    final newPath = path.join(photosDir, fileName);
    final sourceFile = File(originalPath);
    if (!await sourceFile.exists()) {
      throw Exception('Исходный файл не существует: $originalPath');
    }
    return ImageProcessor.compressAndSave(
      sourcePath: originalPath,
      targetPath: newPath,
    );
  }

  Future<void> _deletePhotoFromStorage(String photoPath) async {
    final file = File(photoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ==================== CLOUD PHOTO PREFETCH ====================

  bool _isPrefetchingPhotos = false;

  /// Проверить/закэшировать локальные фото после загрузки из облака.
  ///
  /// Скачивает cloud URL (https://...) в локальный кэш для offline-просмотра.
  Future<void> ensureLocalPhotosExist(List<Plant> plants) async {
    if (_isPrefetchingPhotos) {
      AppLogger.api('⏸️ ensureLocalPhotosExist уже выполняется, пропускаем', tag: 'PHOTO');
      return;
    }

    _isPrefetchingPhotos = true;
    try {
      final photosDir = await _getPhotosDirectory();
      int cachedCount = 0;

      AppLogger.api('🔄 ensureLocalPhotosExist запущен для ${plants.length} растений', tag: 'PHOTO');

      for (final plant in plants) {
        for (var photo in plant.userPhotos) {
          if (!photo.startsWith('http://') &&
              !photo.startsWith('https://')) {
            continue;
          }
          try {
            final baseName = path.basename(photo.split('?').first);
            final cacheFileName =
                'cloud_${photo.hashCode.abs()}_$baseName';
            final localPath = path.join(photosDir, cacheFileName);
            final cachedFile = File(localPath);
            if (await cachedFile.exists()) {
              continue;
            }

            if (!await _validateCloudUrl(photo)) {
              AppLogger.warning('⚠️ Cloud URL недоступен, пропускаем: $photo', tag: 'PHOTO');
              continue;
            }

            await _downloadPhotoWithRetry(photo, localPath);
            cachedCount++;
          } catch (e) {
            AppLogger.warning('⚠️ Не удалось закешировать облачное фото $photo: $e', tag: 'PHOTO');
          }
        }
      }

      AppLogger.api('✅ Prefetch завершён, новых закешированных фото: $cachedCount', tag: 'PHOTO');
      await _cleanupOldCache();
    } finally {
      _isPrefetchingPhotos = false;
    }
  }

  Future<void> _downloadPhotoWithRetry(String url, String localPath) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await File(localPath).writeAsBytes(response.bodyBytes);
          return;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (attempt == 2) rethrow;
        AppLogger.warning('🔄 Попытка ${attempt + 1} для скачивания $url не удалась: $e', tag: 'PHOTO');
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
  }

  Future<bool> _validateCloudUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _cleanupOldCache() async {
    try {
      final photosDir = await _getPhotosDirectory();
      final dir = Directory(photosDir);
      if (!await dir.exists()) return;

      final files = await dir.list().toList();
      int deletedCount = 0;

      for (var file in files) {
        if (file is File && file.path.contains('cloud_')) {
          final stat = await file.stat();
          if (DateTime.now().difference(stat.modified).inDays > 30) {
            await file.delete();
            deletedCount++;
            AppLogger.api('🗑️ Удален старый кэш: ${file.path}', tag: 'PHOTO');
          }
        }
      }

      if (deletedCount > 0) {
        AppLogger.api('🧹 Очистка кэша завершена: удалено $deletedCount старых файлов', tag: 'PHOTO');
      }
    } catch (e) {
      AppLogger.warning('⚠️ Ошибка очистки кэша: $e', tag: 'PHOTO');
    }
  }

}
