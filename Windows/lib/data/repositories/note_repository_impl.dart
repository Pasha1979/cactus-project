import '../../domain/repositories/note_repository.dart';
import '../../models/plant.dart';
import '../datasources/local/note_local_datasource.dart';
import '../models/note_dto.dart';

/// Реализация NoteRepository с использованием Hive
class NoteRepositoryImpl implements NoteRepository {

  NoteRepositoryImpl(this._localDataSource);
  final NoteLocalDataSource _localDataSource;

  @override
  Future<List<Note>> getNotes(String plantId) async {
    final dtoList = await _localDataSource.getNotesByPlantId(plantId);
    return dtoList.map((dto) => _mapToEntity(dto)).toList();
  }

  @override
  Future<void> addNote(String plantId, Note note) async {
    final dto = _mapToDto(note);
    await _localDataSource.saveNote(dto);
  }

  @override
  Future<void> deleteNote(String plantId, String noteId) async {
    await _localDataSource.deleteNote(noteId);
  }

  Note _mapToEntity(NoteDto dto) {
    return Note(
      id: dto.id,
      title: dto.title,
      text: dto.text,
      createdAt: dto.createdAt,
    );
  }

  NoteDto _mapToDto(Note entity) {
    return NoteDto(
      id: entity.id,
      title: entity.title,
      text: entity.text,
      createdAt: entity.createdAt,
    );
  }
}
