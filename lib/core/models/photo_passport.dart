/// Фото-паспорт растения (этап 3, R-004/R-005/R-054).
///
/// Паспорт хранит версии одного «слота» фото: замена фотографии —
/// это новая [PhotoVersion] в том же паспорте, а не перезапись.
/// Адрес файла — путь на Яндекс.Диске (НЕ публичная ссылка).
library;

/// Одна версия фотографии внутри паспорта.
class PhotoVersion {
  const PhotoVersion({
    required this.versionId,
    required this.yandexFilePath,
    required this.createdAt,
    required this.sizeBytes,
    this.localCachePath,
  });

  factory PhotoVersion.fromJson(Map<String, dynamic> json) => PhotoVersion(
        versionId: json['versionId'] as String,
        yandexFilePath: json['yandexFilePath'] as String,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        localCachePath: json['localCachePath'] as String?,
      );

  /// Уникальный ID версии (uuid).
  final String versionId;

  /// Путь файла на Яндекс.Диске (например /MyCactus/photos/x.jpg) —
  /// НЕ публичная ссылка (R-004).
  final String yandexFilePath;

  /// Когда версия создана.
  final DateTime createdAt;

  /// Размер файла в байтах.
  final int sizeBytes;

  /// Локальный кэш-файл (null — не скачан/освобождён).
  final String? localCachePath;

  PhotoVersion copyWith({String? localCachePath, bool clearCache = false}) =>
      PhotoVersion(
        versionId: versionId,
        yandexFilePath: yandexFilePath,
        createdAt: createdAt,
        sizeBytes: sizeBytes,
        localCachePath: clearCache ? null : (localCachePath ?? this.localCachePath),
      );

  Map<String, dynamic> toJson() => {
        'versionId': versionId,
        'yandexFilePath': yandexFilePath,
        'createdAt': createdAt.toIso8601String(),
        'sizeBytes': sizeBytes,
        'localCachePath': localCachePath,
      };
}

/// Паспорт: набор версий одного фото + флаги жизненного цикла.
class PhotoPassport {
  PhotoPassport({
    required this.passportId,
    required this.plantId,
    List<PhotoVersion>? versions,
    this.isArchived = false,
    this.isDeleted = false,
  }) : versions = versions ?? [];

  factory PhotoPassport.fromJson(Map<String, dynamic> json) => PhotoPassport(
        passportId: json['passportId'] as String,
        plantId: json['plantId'] as String,
        versions: (json['versions'] as List<dynamic>?)
                ?.map((e) => PhotoVersion.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        isArchived: json['isArchived'] as bool? ?? false,
        isDeleted: json['isDeleted'] as bool? ?? false,
      );

  /// Уникальный ID паспорта (uuid).
  final String passportId;

  /// permanentId растения-владельца.
  final String plantId;

  /// Версии фото (хронологически).
  final List<PhotoVersion> versions;

  /// В архиве — не показывается активным, но не удалён.
  bool isArchived;

  /// Помечен «удалить везде» — файл с Диска трогать пока НЕЛЬЗЯ (R-005/R-054).
  bool isDeleted;

  PhotoPassport copyWith({
    List<PhotoVersion>? versions,
    bool? isArchived,
    bool? isDeleted,
  }) =>
      PhotoPassport(
        passportId: passportId,
        plantId: plantId,
        versions: versions ?? this.versions,
        isArchived: isArchived ?? this.isArchived,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  Map<String, dynamic> toJson() => {
        'passportId': passportId,
        'plantId': plantId,
        'versions': versions.map((v) => v.toJson()).toList(),
        'isArchived': isArchived,
        'isDeleted': isDeleted,
      };
}
