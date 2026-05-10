import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_constants.dart';
import '../../models/plant.dart';
import '../../models/qr_code_file.dart';

/// Провайдер для управления QR-кодами
///
/// Отвечает за:
/// - Создание/удаление QR-кодов для растений
/// - Управление файлами QR-этикеток
/// - История сканирований
class QrCodeProvider with ChangeNotifier {
  List<QRCodeFile> _qrCodeFiles = [];
  List<String> _scanHistory = [];

  static const String _qrFilesKey = PrefsKeys.qrCodeFiles;
  static const String _scanHistoryKey = PrefsKeys.qrScanHistory;

  // ==================== ГЕТТЕРЫ ====================
  List<QRCodeFile> get qrCodeFiles => List.unmodifiable(_qrCodeFiles);
  List<String> get scanHistory => List.unmodifiable(_scanHistory);

  // ==================== QR ФАЙЛЫ ====================
  Future<void> loadQRCodeFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_qrFilesKey);
    if (json != null) {
      try {
        _qrCodeFiles = QRCodeFile.decodeList(json);
        _qrCodeFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {
        _qrCodeFiles = [];
      }
    }
    notifyListeners();
  }

  Future<void> saveQRCodeFile(QRCodeFile file) async {
    _qrCodeFiles.add(file);
    _qrCodeFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qrFilesKey, QRCodeFile.encodeList(_qrCodeFiles));
    notifyListeners();
  }

  Future<void> deleteQRCodeFile(String id) async {
    _qrCodeFiles.removeWhere((f) => f.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qrFilesKey, QRCodeFile.encodeList(_qrCodeFiles));
    notifyListeners();
  }

  Future<void> renameQRCodeFile(String id, String newName) async {
    final index = _qrCodeFiles.indexWhere((f) => f.id == id);
    if (index == -1) return;

    final oldFile = _qrCodeFiles[index];
    _qrCodeFiles[index] = QRCodeFile(
      id: oldFile.id,
      fileName: newName,
      filePath: oldFile.filePath,
      createdAt: oldFile.createdAt,
      plantIds: oldFile.plantIds,
      pageFormat: oldFile.pageFormat,
      orientation: oldFile.orientation,
      labelWidthCm: oldFile.labelWidthCm,
      labelHeightCm: oldFile.labelHeightCm,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qrFilesKey, QRCodeFile.encodeList(_qrCodeFiles));
    notifyListeners();
  }

  // ==================== ИСТОРИЯ СКАНИРОВАНИЯ ====================
  Future<void> loadScanHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_scanHistoryKey);
    if (historyJson != null) {
      try {
        _scanHistory = List<String>.from(jsonDecode(historyJson));
      } catch (_) {
        _scanHistory = [];
      }
    }
    notifyListeners();
  }

  Future<void> addToScanHistory(String plantId) async {
    _scanHistory.remove(plantId);
    _scanHistory.insert(0, plantId);
    if (_scanHistory.length > 10) {
      _scanHistory = _scanHistory.sublist(0, 10);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scanHistoryKey, jsonEncode(_scanHistory));
  }

  Future<void> clearScanHistory() async {
    _scanHistory = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scanHistoryKey);
    notifyListeners();
  }

  // ==================== ПОИСК ПО QR ====================
  Plant? findPlantByQRCode(List<Plant> allPlants, String qrData) {
    String? plantId;
    try {
      final decoded = jsonDecode(qrData) as Map<String, dynamic>;
      plantId = decoded['permanentId'] as String? ?? decoded['plantId'] as String?;
    } catch (_) {
      plantId = qrData;
    }
    if (plantId == null) return null;

    try {
      return allPlants.firstWhere((p) => p.permanentId == plantId);
    } catch (_) {
      return null;
    }
  }
}
