import '../../domain/repositories/wintering_repository.dart';
import '../datasources/local/wintering_local_datasource.dart';
import '../models/wintering_log_entry_dto.dart';

/// Реализация WinteringRepository с использованием Hive
class WinteringRepositoryImpl implements WinteringRepository {
  final WinteringLocalDataSource _localDataSource;

  WinteringRepositoryImpl(this._localDataSource);

  @override
  Future<Map<String, dynamic>> getWinteringSettings() async {
    final entries = await _localDataSource.getAllEntries();
    return {
      'entries': entries
          .map((e) => {
                'date': e.date.toIso8601String(),
                'description': e.description,
              },)
          .toList(),
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> saveWinteringSettings(Map<String, dynamic> settings) async {
    final entries = settings['entries'] as List<dynamic>?;
    if (entries != null) {
      for (final entry in entries) {
        final dto = WinteringLogEntryDto(
          date: DateTime.tryParse(entry['date'] as String) ?? DateTime(1970, 1, 1),
          description: entry['description'] as String,
        );
        await _localDataSource.saveEntry(dto);
      }
    }
  }
}
