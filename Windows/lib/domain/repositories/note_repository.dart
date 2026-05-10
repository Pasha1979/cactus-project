import '../../models/plant.dart';

/// Репозиторий для работы с заметками
abstract class NoteRepository {
  /// Получить заметки для растения
  Future<List<Note>> getNotes(String plantId);

  /// Добавить заметку
  Future<void> addNote(String plantId, Note note);

  /// Удалить заметку
  Future<void> deleteNote(String plantId, String noteId);
}
