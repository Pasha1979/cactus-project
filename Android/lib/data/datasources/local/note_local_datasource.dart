import 'package:hive/hive.dart';
import '../../../data/models/note_dto.dart';

/// Локальный источник данных для заметок (Hive)
class NoteLocalDataSource {
  final Box<NoteDto> _noteBox;

  NoteLocalDataSource(this._noteBox);

  /// Получить все заметки
  Future<List<NoteDto>> getAllNotes() async {
    return _noteBox.values.toList();
  }

  /// Получить заметку по ID
  Future<NoteDto?> getNoteById(String id) async {
    return _noteBox.get(id);
  }

  /// Получить заметки по plantId
  Future<List<NoteDto>> getNotesByPlantId(String plantId) async {
    return _noteBox.values
        .where((note) => note.id.startsWith(plantId))
        .toList();
  }

  /// Сохранить заметку
  Future<void> saveNote(NoteDto note) async {
    await _noteBox.put(note.id, note);
  }

  /// Удалить заметку
  Future<void> deleteNote(String id) async {
    await _noteBox.delete(id);
  }

  /// Очистить все данные
  Future<void> clearAll() async {
    await _noteBox.clear();
  }
}
