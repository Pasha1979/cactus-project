import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_constants.dart';
import '../../models/plant.dart';

/// Провайдер для управления фотографиями растений
///
/// Отвечает за:
/// - Добавление/удаление фото пользователя
/// - Управление Llifle фото
/// - Adult images
/// - Локальный кэш облачных фото
class PhotoProvider with ChangeNotifier {
  // TODO: подключить PhotoRepository через DI когда будет готов
  // final PhotoRepository _repository = sl<PhotoRepository>();

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
      debugPrint('✅ PhotoProvider loaded: ${_adultImages.length} adult images');
    } catch (e) {
      debugPrint('❌ PhotoProvider load error: $e');
      _adultImages = {};
    }
  }

  Future<void> _saveAdultImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.adultImages, jsonEncode(_adultImages));
    } catch (e) {
      debugPrint('❌ PhotoProvider save error: $e');
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
    await sourceFile.copy(newPath);
    return newPath;
  }

  Future<void> _deletePhotoFromStorage(String photoPath) async {
    final file = File(photoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
