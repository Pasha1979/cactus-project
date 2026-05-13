/// Модель данных о местонахождении (occurrence) из GBIF.
///
/// Используется как часть доменной модели [Plant].
class GbifOccurrence {

  GbifOccurrence({
    required this.latitude,
    required this.longitude,
    required this.country,
    this.locality,
    this.habitat,
    this.coordinateUncertainty,
    this.year,
    this.month,
    this.day,
  });

  factory GbifOccurrence.fromJson(Map<String, dynamic> json) {
    return GbifOccurrence(
      latitude: (json['decimalLatitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['decimalLongitude'] as num?)?.toDouble() ?? 0.0,
      country: json['country'] as String? ?? '',
      locality: json['locality'] as String?,
      habitat: json['habitat'] as String?,
      coordinateUncertainty: json['coordinateUncertaintyInMeters'] as String?,
      year: json['year'] as String?,
      month: json['month'] as String?,
      day: json['day'] as String?,
    );
  }
  final double latitude;
  final double longitude;
  final String country;
  final String? locality;
  final String? habitat;
  final String? coordinateUncertainty;
  final String? year;
  final String? month;
  final String? day;

  Map<String, dynamic> toJson() {
    return {
      'decimalLatitude': latitude,
      'decimalLongitude': longitude,
      'country': country,
      'locality': locality,
      'habitat': habitat,
      'coordinateUncertaintyInMeters': coordinateUncertainty,
      'year': year,
      'month': month,
      'day': day,
    };
  }

  bool get hasValidCoordinates =>
      latitude != 0.0 &&
      longitude != 0.0 &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
