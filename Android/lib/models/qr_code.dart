import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Модель для хранения информации о QR коде растения
///
/// QR код содержит данные в формате JSON:
/// {
///   "id": "24-001",
///   "name": "Echinocereus reichenbachii",
///   "permanentId": "uuid-string"
/// }
class QRCode {
  final String plantId;         // displayId (например: "24-001")
  final String plantName;       // латинское название
  final String permanentId;     // permanentId для поиска в базе
  final DateTime createdAt;     // когда создан QR код
  final bool isActive;          // активен ли QR код (false если растение удалено)

  QRCode({
    required this.plantId,
    required this.plantName,
    required this.permanentId,
    required this.createdAt,
    this.isActive = true,
  });

  /// Фабричный конструктор для создания нового QR кода с авто-генерацией UUID
  factory QRCode.createNew({
    required String plantId,
    required String plantName,
  }) {
    return QRCode(
      plantId: plantId,
      plantName: plantName,
      permanentId: const Uuid().v4(),
      createdAt: DateTime.now(),
      isActive: true,
    );
  }

  /// Генерирует строку данных для QR кода (альтернативное имя для совместимости)
  String toQRCodeData() => qrData;

  /// Генерирует строку данных для QR кода
  String get qrData {
    final data = {
      'id': plantId,
      'name': plantName,
      'permanentId': permanentId,
    };
    return jsonEncode(data);
  }

  /// Создает QRCode из строки данных QR кода
  factory QRCode.fromQRData(String qrData) {
    final data = jsonDecode(qrData) as Map<String, dynamic>;
    return QRCode(
      plantId: data['id'] as String,
      plantName: data['name'] as String,
      permanentId: data['permanentId'] as String,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'plantId': plantId,
    'plantName': plantName,
    'permanentId': permanentId,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
  };

  factory QRCode.fromJson(Map<String, dynamic> json) {
    return QRCode(
      plantId: json['plantId'] as String,
      plantName: json['plantName'] as String,
      permanentId: json['permanentId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  QRCode copyWith({
    String? plantId,
    String? plantName,
    String? permanentId,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return QRCode(
      plantId: plantId ?? this.plantId,
      plantName: plantName ?? this.plantName,
      permanentId: permanentId ?? this.permanentId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
