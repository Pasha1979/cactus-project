import 'package:uuid/uuid.dart';
import 'gbif_occurrence.dart';
import 'qr_code.dart';

class Plant {
  String permanentId;
  String displayId; // Не final — нужно менять для сеянцев в системе партий
  final String latinName;
  final String status;
  final int year;
  final int customNumber;
  final String category;
  final int seedsCount;
  final int germinatedCount;
  final List<String> userPhotos;
  final DateTime? lastFertilization;
  final DateTime? plannedFertilizationDate;
  final List<String> lliflePhotoUrls;

  // === НОВОЕ ПОЛЕ ДЛЯ РАЗРЕШЕНИЯ КОНФЛИКТОВ ===
  DateTime? lastModified;

  String? fieldNumber;
  String? seller;
  int? harvestYear;
  String? country;
  String? habitat;
  String? description;
  String? synonyms;
  String? careTips;
  String? floweringPeriod;
  String? countryFlag;
  List<DateTime> wateringDates;
  List<DateTime> customWateringDates;
  bool hasUnreadNotification;
  DateTime? lastRepotting;
  DateTime? plannedTransplantDate;
  List<GerminationRecord> germinationHistory;
  final List<FloweringRecord> floweringHistory;
  List<Note> notes;

  // === GBIF ПОЛЯ (дополняющий источник данных) ===
  final List<String> gbifPhotoUrls;
  final List<GbifOccurrence> gbifOccurrences;
  final DateTime? lastGbifUpdate;

  // === ПОЛЯ ДЛЯ СИСТЕМЫ ПАРТИЙ ===
  int? aliveCount;                    // null = авторасчёт, иначе ручное значение
  bool isBatch;                       // true если это витрина-партия
  List<String> childrenIds;           // ID сеянцев (для витрины)
  String? parentId;                   // ID витрины (для сеянца)

  // === ПОЛЕ ДЛЯ QR КОДА ===
  QRCode? qrCode;                     // QR код растения (null если не создан)

  static const statusOrder = {
    'sown': 0,
    'growing': 1,
    'in_collection': 2,
    'dead': 3,
    'failed': 4,
  };

  Plant({
    String? permanentId,
    String? displayId,
    required this.latinName,
    required this.status,
    required this.year,
    required this.customNumber,
    required this.category,
    this.country,
    this.habitat,
    this.description,
    this.synonyms,
    this.careTips,
    this.floweringPeriod,
    this.countryFlag,
    this.seedsCount = 0,
    this.germinatedCount = 0,
    this.lastFertilization,
    this.plannedFertilizationDate,
    List<DateTime>? wateringDates,
    List<DateTime>? customWateringDates,
    this.hasUnreadNotification = false,
    this.lastRepotting,
    this.plannedTransplantDate,
    List<GerminationRecord>? germinationHistory,
    List<FloweringRecord>? floweringHistory,
    this.notes = const [],
    this.userPhotos = const [],
    this.lliflePhotoUrls = const [],
    this.fieldNumber,
    this.seller,
    this.harvestYear,
    DateTime? lastModified, // ← НОВОЕ
    // GBIF поля с инициализацией по умолчанию
    this.gbifPhotoUrls = const [],
    this.gbifOccurrences = const [],
    this.lastGbifUpdate,
    // Поля для системы партий
    this.aliveCount,
    this.isBatch = false,
    List<String>? childrenIds,
    this.parentId,
    // Поле для QR кода
    this.qrCode,
  })  : permanentId = permanentId ?? const Uuid().v4(),
        displayId = displayId ?? Plant.generateDisplayId(year, customNumber, category),
        wateringDates = wateringDates ?? [],
        customWateringDates = customWateringDates ?? [],
        germinationHistory = germinationHistory ?? [],
        floweringHistory = floweringHistory ?? [],
        lastModified =
            lastModified ?? DateTime.now(), // ← Автоматически ставим время
        childrenIds = childrenIds ?? [];

  int get statusPriority => statusOrder[status] ?? 5;

  // === ГЕТТЕР ДЛЯ СИСТЕМЫ ПАРТИЙ ===
  // Возвращает aliveCount если задано вручную, иначе авторасчёт
  int get getCurrentAliveCount {
    if (aliveCount != null) return aliveCount!;
    // Авторасчёт: взошло - погибло
    final totalGerminated = germinationHistory.fold<int>(
      0, (sum, record) => sum + record.germinatedCount);
    final totalDead = germinationHistory.fold<int>(
      0, (sum, record) => sum + record.deadCount);
    return totalGerminated - totalDead;
  }

  static String generateDisplayId(int year, int number, String category) {
    final yearPart = year.toString().substring(2);
    final numberPart = number.toString().padLeft(3, '0');
    return category == 'purchased'
        ? 'K$yearPart-$numberPart'
        : '$yearPart-$numberPart';
  }

  // === МЕТОД ДЛЯ СИСТЕМЫ ПАРТИЙ ===
  // Генерирует displayId для сеянца на основе ID витрины и номера
  static String generateSeedlingDisplayId(String parentDisplayId, int seedlingNumber) {
    return '$parentDisplayId-$seedlingNumber';
  }

  DateTime? get lastWatering => lastWateringDate;

  Plant copyWith({
    String? displayId,
    String? latinName,
    String? status,
    int? year,
    int? customNumber,
    String? category,
    int? seedsCount,
    int? germinatedCount,
    String? country,
    String? habitat,
    String? description,
    String? synonyms,
    String? careTips,
    String? floweringPeriod,
    String? countryFlag,
    List<DateTime>? wateringDates,
    List<DateTime>? customWateringDates,
    bool? hasUnreadNotification,
    DateTime? lastRepotting,
    DateTime? plannedTransplantDate,
    List<GerminationRecord>? germinationHistory,
    List<FloweringRecord>? floweringHistory,
    List<Note>? notes,
    List<String>? userPhotos,
    DateTime? lastFertilization,
    DateTime? plannedFertilizationDate,
    List<String>? lliflePhotoUrls,
    String? fieldNumber,
    String? seller,
    int? harvestYear,
    DateTime? lastModified,
    // GBIF поля для copyWith
    List<String>? gbifPhotoUrls,
    List<GbifOccurrence>? gbifOccurrences,
    DateTime? lastGbifUpdate,
    // Поля для системы партий
    int? aliveCount,
    bool? isBatch,
    List<String>? childrenIds,
    String? parentId,
    // Поле для QR кода
    QRCode? qrCode,
  }) {
    return Plant(
      latinName: latinName ?? this.latinName,
      status: status ?? this.status,
      year: year ?? this.year,
      customNumber: customNumber ?? this.customNumber,
      category: category ?? this.category,
      seedsCount: seedsCount ?? this.seedsCount,
      germinatedCount: germinatedCount ?? this.germinatedCount,
      country: country ?? this.country,
      habitat: habitat ?? this.habitat,
      description: description ?? this.description,
      synonyms: synonyms ?? this.synonyms,
      careTips: careTips ?? this.careTips,
      floweringPeriod: floweringPeriod ?? this.floweringPeriod,
      countryFlag: countryFlag ?? this.countryFlag,
      wateringDates: wateringDates ?? this.wateringDates,
      customWateringDates: customWateringDates ?? this.customWateringDates,
      hasUnreadNotification:
          hasUnreadNotification ?? this.hasUnreadNotification,
      lastRepotting: lastRepotting ?? this.lastRepotting,
      plannedTransplantDate:
          plannedTransplantDate ?? this.plannedTransplantDate,
      germinationHistory: germinationHistory ?? this.germinationHistory,
      floweringHistory: floweringHistory ?? this.floweringHistory,
      notes: notes ?? this.notes,
      userPhotos: userPhotos ?? this.userPhotos,
      lastFertilization: lastFertilization ?? this.lastFertilization,
      plannedFertilizationDate:
          plannedFertilizationDate ?? this.plannedFertilizationDate,
      lliflePhotoUrls: lliflePhotoUrls ?? this.lliflePhotoUrls,
      fieldNumber: fieldNumber ?? this.fieldNumber,
      seller: seller ?? this.seller,
      harvestYear: harvestYear ?? this.harvestYear,
      lastModified: lastModified ?? this.lastModified ?? DateTime.now(),
      // GBIF поля в возвращаемом объекте
      gbifPhotoUrls: gbifPhotoUrls ?? this.gbifPhotoUrls,
      gbifOccurrences: gbifOccurrences ?? this.gbifOccurrences,
      lastGbifUpdate: lastGbifUpdate ?? this.lastGbifUpdate,
      // Поля для системы партий
      aliveCount: aliveCount ?? this.aliveCount,
      isBatch: isBatch ?? this.isBatch,
      childrenIds: childrenIds ?? this.childrenIds,
      parentId: parentId ?? this.parentId,
      // Поле для QR кода
      qrCode: qrCode ?? this.qrCode,
    )
      ..permanentId = permanentId
      ..displayId = displayId ?? this.displayId;
  }

  Map<String, dynamic> toJson() => {
        'permanentId': permanentId,
        'displayId': displayId,
        'latinName': latinName,
        'status': status,
        'year': year,
        'customNumber': customNumber,
        'category': category,
        'country': country,
        'habitat': habitat,
        'description': description,
        'synonyms': synonyms,
        'careTips': careTips,
        'floweringPeriod': floweringPeriod,
        'countryFlag': countryFlag,
        'seedsCount': seedsCount,
        'germinatedCount': germinatedCount,
        'wateringDates':
            wateringDates.map((date) => date.toIso8601String()).toList(),
        'customWateringDates':
            customWateringDates.map((date) => date.toIso8601String()).toList(),
        'hasUnreadNotification': hasUnreadNotification,
        'lastRepotting': lastRepotting?.toIso8601String(),
        'plannedTransplantDate': plannedTransplantDate?.toIso8601String(),
        'germinationHistory':
            germinationHistory.map((record) => record.toJson()).toList(),
        'floweringHistory':
            floweringHistory.map((record) => record.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        'userPhotos': userPhotos,
        'lastFertilization': lastFertilization?.toIso8601String(),
        'plannedFertilizationDate': plannedFertilizationDate?.toIso8601String(),
        'lliflePhotoUrls': lliflePhotoUrls,
        'fieldNumber': fieldNumber,
        'seller': seller,
        'harvestYear': harvestYear,
        'lastModified': lastModified?.toIso8601String(), // ← НОВОЕ
        // GBIF поля для сериализации
        'gbifPhotoUrls': gbifPhotoUrls,
        'gbifOccurrences': gbifOccurrences.map((o) => o.toJson()).toList(),
        'lastGbifUpdate': lastGbifUpdate?.toIso8601String(),
        // Поля для системы партий
        'aliveCount': aliveCount,
        'isBatch': isBatch,
        'childrenIds': childrenIds,
        'parentId': parentId,
        // Поле для QR кода
        'qrCode': qrCode?.toJson(),
      };

  factory Plant.fromJson(Map<String, dynamic> json) {
    String status = json['status'].toString().trim().toLowerCase();

    status = switch (status) {
      'failed' => 'failed',
      'sown' => 'sown',
      'growing' => 'growing',
      'in_collection' => 'in_collection',
      'dead' => 'dead',
      'не взошел' => 'failed',
      'посеян' => 'sown',
      'растёт' => 'growing',
      'растет' => 'growing',
      'в коллекции' => 'in_collection',
      'погиб' => 'dead',
      _ => json['status']
    };

    return Plant(
      latinName: json['latinName'],
      status: status,
      year: json['year'],
      customNumber: json['customNumber'],
      category: json['category'],
      fieldNumber: json['fieldNumber'],
      seller: json['seller'],
      harvestYear: json['harvestYear'],
      country: json['country'],
      habitat: json['habitat'],
      description: json['description'],
      synonyms: json['synonyms'],
      careTips: json['careTips'],
      floweringPeriod: json['floweringPeriod'],
      countryFlag: json['countryFlag'],
      seedsCount: json['seedsCount'],
      germinatedCount: json['germinatedCount'],
      wateringDates: (json['wateringDates'] as List<dynamic>?)
              ?.map((dateStr) => DateTime.parse(dateStr as String))
              .toList() ??
          [],
      customWateringDates: (json['customWateringDates'] as List<dynamic>?)
              ?.map((dateStr) => DateTime.parse(dateStr as String))
              .toList() ??
          [],
      hasUnreadNotification: json['hasUnreadNotification'] ?? false,
      lastRepotting: json['lastRepotting'] != null
          ? DateTime.parse(json['lastRepotting'])
          : null,
      plannedTransplantDate: json['plannedTransplantDate'] != null
          ? DateTime.parse(json['plannedTransplantDate'])
          : null,
      germinationHistory: (json['germinationHistory'] as List<dynamic>?)
              ?.map((item) =>
                  GerminationRecord.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      floweringHistory: (json['floweringHistory'] as List<dynamic>?)
              ?.map((item) =>
                  FloweringRecord.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      notes: (json['notes'] as List<dynamic>?)
              ?.map((e) => Note.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      userPhotos: (json['userPhotos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      lastFertilization: json['lastFertilization'] != null
          ? DateTime.parse(json['lastFertilization'])
          : null,
      plannedFertilizationDate: json['plannedFertilizationDate'] != null
          ? DateTime.parse(json['plannedFertilizationDate'])
          : null,
      lliflePhotoUrls: List<String>.from(json['lliflePhotoUrls'] ?? []),
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'])
          : null, // ← НОВОЕ
      // GBIF поля с обратной совместимостью
      gbifPhotoUrls: List<String>.from(json['gbifPhotoUrls'] ?? []),
      gbifOccurrences: (json['gbifOccurrences'] as List<dynamic>?)
              ?.map((e) => GbifOccurrence.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastGbifUpdate: json['lastGbifUpdate'] != null
          ? DateTime.tryParse(json['lastGbifUpdate'])
          : null,
      // Поля для системы партий (обратная совместимость — null если не в JSON)
      aliveCount: json['aliveCount'] as int?,
      isBatch: json['isBatch'] ?? false,
      childrenIds: (json['childrenIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      parentId: json['parentId'] as String?,
      // Поле для QR кода (обратная совместимость — null если не в JSON)
      qrCode: json['qrCode'] != null
          ? QRCode.fromJson(json['qrCode'] as Map<String, dynamic>)
          : null,
    )..permanentId = json['permanentId'];
  }

  String get statusText => switch (status) {
        'sown' => 'Посеян',
        'growing' => 'Растёт',
        'in_collection' => 'В коллекции',
        'dead' => 'Погиб',
        'failed' => 'Не взошел',
        _ => 'Неизвестный статус',
      };

  int get age {
    final currentYear = DateTime.now().year;
    return switch (category) {
      'sown' => currentYear - year,
      'purchased' => currentYear - year + 1,
      _ => 0,
    };
  }

  DateTime? get lastWateringDate {
    if (wateringDates.isEmpty) return null;
    return wateringDates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String get lastWateringText {
    final lastDate = lastWateringDate;
    if (lastDate == null) return 'Не поливался';
    final daysAgo = DateTime.now().difference(lastDate).inDays;
    if (daysAgo == 0) return 'Полит сегодня';
    if (daysAgo == 1) return 'Полит вчера';
    if (daysAgo < 7) return 'Полит $daysAgo дней назад';
    final weeksAgo = (daysAgo / 7).floor();
    return 'Полит $weeksAgo недель назад';
  }

  DateTime? getRecommendedTransplantDate() {
    if (lastRepotting == null) {
      return DateTime.now();
    }

    final ageInYears = age;
    Duration interval;

    if (ageInYears < 1) {
      interval = const Duration(days: 90);
    } else if (ageInYears < 2) {
      interval = const Duration(days: 182);
    } else if (ageInYears < 5) {
      interval = const Duration(days: 365);
    } else if (ageInYears < 10) {
      interval = const Duration(days: 730);
    } else {
      interval = const Duration(days: 1095);
    }

    return lastRepotting!.add(interval);
  }
}

class GerminationRecord {
  final DateTime date;
  final int germinatedCount; // сколько взошло НА ЭТУ ДАТУ
  final int deadCount; // сколько погибло НА ЭТУ ДАТУ (новое поле)

  GerminationRecord({
    required this.date,
    required this.germinatedCount,
    this.deadCount = 0, // по умолчанию 0
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'germinatedCount': germinatedCount,
        'deadCount': deadCount, // добавлено
      };

  factory GerminationRecord.fromJson(Map<String, dynamic> json) {
    return GerminationRecord(
      date: DateTime.parse(json['date']),
      germinatedCount: json['germinatedCount'],
      deadCount: json['deadCount'] ?? 0, // поддержка старых записей
    );
  }
}

class FloweringRecord {
  final DateTime date;
  final String event; // "bloomed" или "wilted"

  FloweringRecord({required this.date, required this.event});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'event': event,
      };

  factory FloweringRecord.fromJson(Map<String, dynamic> json) {
    return FloweringRecord(
      date: DateTime.parse(json['date']),
      event: json['event'],
    );
  }
}

class Note {
  final String id; // уникальный идентификатор
  final String title; // короткая тема/заголовок
  final String text; // основной текст заметки
  final DateTime createdAt; // дата создания

  Note({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      text: json['text'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
