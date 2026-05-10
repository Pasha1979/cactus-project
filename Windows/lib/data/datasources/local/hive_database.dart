import 'package:hive_flutter/hive_flutter.dart';
import '../../models/plant_dto.dart';
import '../../models/qr_code_dto.dart';
import '../../models/note_dto.dart';
import '../../models/wintering_log_entry_dto.dart';
import '../../models/gbif_occurrence_dto.dart';

class HiveDatabase {
  static const String _plantsBoxName = 'plants_box';
  static const String _qrCodesBoxName = 'qr_codes_box';
  static const String _notesBoxName = 'notes_box';
  static const String _winteringLogsBoxName = 'wintering_logs_box';
  static const String _gbifCacheBoxName = 'gbif_cache_box';

  static Box<PlantDto>? _plantsBox;
  static Box<QRCodeDto>? _qrCodesBox;
  static Box<NoteDto>? _notesBox;
  static Box<WinteringLogEntryDto>? _winteringLogsBox;
  static Box<GbifOccurrenceDto>? _gbifCacheBox;

  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// Инициализация Hive базы данных
  /// Безопасна при повторном вызове (idempotent)
  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    if (_isInitializing) {
      // Ждём завершения текущей инициализации
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }

    _isInitializing = true;
    try {
      await Hive.initFlutter();

      // Регистрация адаптеров с защитой от повторной регистрации
      _safeRegisterAdapter(PlantDtoAdapter());
      _safeRegisterAdapter(QRCodeDtoAdapter());
      _safeRegisterAdapter(NoteDtoAdapter());
      _safeRegisterAdapter(WinteringLogEntryDtoAdapter());
      _safeRegisterAdapter(GbifOccurrenceDtoAdapter());

      // Открытие коробок
      _plantsBox = await Hive.openBox<PlantDto>(_plantsBoxName);
      _qrCodesBox = await Hive.openBox<QRCodeDto>(_qrCodesBoxName);
      _notesBox = await Hive.openBox<NoteDto>(_notesBoxName);
      _winteringLogsBox = await Hive.openBox<WinteringLogEntryDto>(_winteringLogsBoxName);
      _gbifCacheBox = await Hive.openBox<GbifOccurrenceDto>(_gbifCacheBoxName);

      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }

  /// Безопасная регистрация адаптера (игнорирует повторную регистрацию)
  static void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
    try {
      Hive.registerAdapter(adapter);
    } on HiveError catch (e) {
      if (e.message.contains('already a TypeAdapter')) {
        // Адаптер уже зарегистрирован — это нормально при hot-restart
        return;
      }
      rethrow;
    }
  }

  /// Получить коробку растений
  static Box<PlantDto> get plantsBox {
    if (_plantsBox == null) {
      throw Exception('Hive not initialized. Call initialize() first.');
    }
    return _plantsBox!;
  }

  /// Получить коробку QR кодов
  static Box<QRCodeDto> get qrCodesBox {
    if (_qrCodesBox == null) {
      throw Exception('Hive not initialized. Call initialize() first.');
    }
    return _qrCodesBox!;
  }

  /// Получить коробку заметок
  static Box<NoteDto> get notesBox {
    if (_notesBox == null) {
      throw Exception('Hive not initialized. Call initialize() first.');
    }
    return _notesBox!;
  }

  /// Получить коробку логов зимовки
  static Box<WinteringLogEntryDto> get winteringLogsBox {
    if (_winteringLogsBox == null) {
      throw Exception('Hive not initialized. Call initialize() first.');
    }
    return _winteringLogsBox!;
  }

  /// Получить коробку GBIF кэша
  static Box<GbifOccurrenceDto> get gbifCacheBox {
    if (_gbifCacheBox == null) {
      throw Exception('Hive not initialized. Call initialize() first.');
    }
    return _gbifCacheBox!;
  }

  /// Закрыть все коробки и сбросить состояние
  static Future<void> close() async {
    await _plantsBox?.close();
    await _qrCodesBox?.close();
    await _notesBox?.close();
    await _winteringLogsBox?.close();
    await _gbifCacheBox?.close();

    _plantsBox = null;
    _qrCodesBox = null;
    _notesBox = null;
    _winteringLogsBox = null;
    _gbifCacheBox = null;
    _isInitialized = false;
  }

  /// Очистить все данные (для тестирования)
  static Future<void> clearAll() async {
    await _plantsBox?.clear();
    await _qrCodesBox?.clear();
    await _notesBox?.clear();
    await _winteringLogsBox?.clear();
    await _gbifCacheBox?.clear();
  }
}
