import 'dart:convert';

/// Модель для хранения метаданных о созданном PDF-файле с QR-этикетками
class QRCodeFile {

  QRCodeFile({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.plantIds,
    required this.pageFormat,
    required this.orientation,
    required this.labelWidthCm,
    required this.labelHeightCm,
  });

  factory QRCodeFile.fromJson(Map<String, dynamic> json) {
    return QRCodeFile(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      filePath: json['filePath'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String) ?? DateTime(1970, 1, 1),
      plantIds: List<String>.from(json['plantIds'] as List),
      pageFormat: json['pageFormat'] as String,
      orientation: json['orientation'] as String,
      labelWidthCm: (json['labelWidthCm'] as num).toDouble(),
      labelHeightCm: (json['labelHeightCm'] as num).toDouble(),
    );
  }
  final String id;
  String fileName;
  final String filePath;
  final DateTime createdAt;
  final List<String> plantIds;
  final String pageFormat;
  final String orientation;
  final double labelWidthCm;
  final double labelHeightCm;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'plantIds': plantIds,
      'pageFormat': pageFormat,
      'orientation': orientation,
      'labelWidthCm': labelWidthCm,
      'labelHeightCm': labelHeightCm,
    };
  }

  static String encodeList(List<QRCodeFile> files) {
    return jsonEncode(files.map((f) => f.toJson()).toList());
  }

  static List<QRCodeFile> decodeList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((item) => QRCodeFile.fromJson(item as Map<String, dynamic>)).toList();
  }
}
