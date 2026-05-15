import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/api_config.dart';
import '../../../../models/gbif_occurrence.dart';
import '../../../../models/plant.dart';
import '../widgets/geography_section.dart';
import '../widgets/empty_gbif_state.dart';
import '../widgets/stat_card.dart';

class DistributionTab extends StatefulWidget {

  const DistributionTab({
    super.key,
    required this.plant,
    required this.onRefreshGbif,
  });
  final Plant plant;
  final Future<void> Function(BuildContext, Plant) onRefreshGbif;

  @override
  State<DistributionTab> createState() => _DistributionTabState();
}

class _DistributionTabState extends State<DistributionTab> {
  ValueKey? _mapKey;

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок и кнопка обновления
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Распространение вида',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              IconButton(
                onPressed: () => widget.onRefreshGbif(context, plant),
                icon: const Icon(Icons.refresh),
                tooltip: 'Обновить данные GBIF',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Страна с флагом
          GeographySection(plant: plant),
          const SizedBox(height: 16),

          // Ареал обитания
          if (plant.habitat != null && plant.habitat!.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.terrain, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Ареал обитания',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      plant.habitat!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // GBIF статистика
          if (plant.gbifOccurrences.isNotEmpty || plant.gbifPhotoUrls.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Данные GBIF',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Точки наблюдения',
                            value: plant.gbifOccurrences.length.toString(),
                            icon: Icons.location_on,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            title: 'Фото из природы',
                            value: plant.gbifPhotoUrls.length.toString(),
                            icon: Icons.photo_camera,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (plant.lastGbifUpdate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Обновлено: ${_formatDate(plant.lastGbifUpdate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Интерактивная карта с occurrence точками GBIF
          if (plant.gbifOccurrences.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: SizedBox(
                height: 400,
                width: double.infinity,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Точки наблюдения GBIF: ${plant.gbifOccurrences.length}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _resetMapView(plant),
                                icon: const Icon(Icons.center_focus_strong),
                                tooltip: 'Центрировать карту',
                                iconSize: 20,
                              ),
                              IconButton(
                                onPressed: () => _showFullMapDialog(plant),
                                icon: const Icon(Icons.fullscreen),
                                tooltip: 'Полноэкранная карта',
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildGbifMap(plant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Фото из природы GBIF
          if (plant.gbifPhotoUrls.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.photo_camera, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Фото из природы (GBIF)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: plant.gbifPhotoUrls.length,
                        itemBuilder: (context, index) {
                          final photoUrl = plant.gbifPhotoUrls[index];
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Пустое состояние - если нет GBIF данных
          if (plant.gbifOccurrences.isEmpty && plant.gbifPhotoUrls.isEmpty)
            EmptyGbifState(
              plant: plant,
              onRefresh: () => widget.onRefreshGbif(context, plant),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // === МЕТОДЫ ИНТЕРАКТИВНОЙ КАРТЫ GBIF ===

  Widget _buildGbifMap(Plant plant) {
    if (plant.gbifOccurrences.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Text('Нет точек наблюдения'),
        ),
      );
    }

    final centerPoint = _calculateMapCenter(plant.gbifOccurrences);

    return FlutterMap(
      key: _mapKey,
      options: MapOptions(
        initialCenter: centerPoint,
        initialZoom: 4.0,
        minZoom: 2.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: ApiConstants.openStreetMapTileUrl,
          userAgentPackageName: 'com.pavel.mycactus',
          maxZoom: 19,
        ),
        MarkerLayer(
          markers: plant.gbifOccurrences.map((occurrence) {
            return _buildOccurrenceMarker(occurrence);
          }).toList(),
        ),
        if (plant.gbifOccurrences.length > 3)
          PolygonLayer(
            polygons: [_buildOccurrencePolygon(plant.gbifOccurrences)],
          ),
      ],
    );
  }

  LatLng _calculateMapCenter(List<GbifOccurrence> occurrences) {
    if (occurrences.isEmpty) {
      return const LatLng(0.0, 0.0);
    }

    double totalLat = 0.0;
    double totalLng = 0.0;
    int validPoints = 0;

    for (final occurrence in occurrences) {
      if (occurrence.hasValidCoordinates) {
        totalLat += occurrence.latitude;
        totalLng += occurrence.longitude;
        validPoints++;
      }
    }

    if (validPoints == 0) {
      return const LatLng(0.0, 0.0);
    }

    return LatLng(totalLat / validPoints, totalLng / validPoints);
  }

  Marker _buildOccurrenceMarker(GbifOccurrence occurrence) {
    return Marker(
      point: LatLng(occurrence.latitude, occurrence.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showOccurrenceDetails(occurrence),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 204),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 77),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Polygon _buildOccurrencePolygon(List<GbifOccurrence> occurrences) {
    final validPoints = occurrences
        .where((occ) => occ.hasValidCoordinates)
        .map((occ) => LatLng(occ.latitude, occ.longitude))
        .toList();

    if (validPoints.length < 3) {
      if (validPoints.length == 2) {
        final lat1 = validPoints[0].latitude;
        final lat2 = validPoints[1].latitude;
        final lng1 = validPoints[0].longitude;
        final lng2 = validPoints[1].longitude;

        return Polygon(
          points: [
            LatLng(lat1, lng1),
            LatLng(lat1, lng2),
            LatLng(lat2, lng2),
            LatLng(lat2, lng1),
          ],
          color: Colors.green.withValues(alpha: 51),
          borderStrokeWidth: 2,
          borderColor: Colors.green.withValues(alpha: 153),
        );
      }
      if (validPoints.length == 1) {
        final lat = validPoints[0].latitude;
        final lng = validPoints[0].longitude;
        const delta = 0.5;

        return Polygon(
          points: [
            LatLng(lat + delta, lng + delta),
            LatLng(lat + delta, lng - delta),
            LatLng(lat - delta, lng - delta),
            LatLng(lat - delta, lng + delta),
          ],
          color: Colors.green.withValues(alpha: 51),
          borderStrokeWidth: 2,
          borderColor: Colors.green.withValues(alpha: 153),
        );
      }
    }

    final hullPoints = _calculateConvexHull(validPoints);

    return Polygon(
      points: hullPoints,
      color: Colors.green.withValues(alpha: 51),
      borderStrokeWidth: 2,
      borderColor: Colors.green.withValues(alpha: 153),
    );
  }

  List<LatLng> _calculateConvexHull(List<LatLng> points) {
    if (points.length < 3) return points;

    final sortedPoints = List<LatLng>.from(points);
    sortedPoints.sort((a, b) {
      if (a.latitude != b.latitude) {
        return a.latitude.compareTo(b.latitude);
      }
      return a.longitude.compareTo(b.longitude);
    });

    final List<LatLng> lower = [];
    for (final point in sortedPoints) {
      while (lower.length >= 2 && _crossProduct(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) {
        lower.removeLast();
      }
      lower.add(point);
    }

    final List<LatLng> upper = [];
    for (final point in sortedPoints.reversed) {
      while (upper.length >= 2 && _crossProduct(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) {
        upper.removeLast();
      }
      upper.add(point);
    }

    lower.removeLast();
    upper.removeLast();

    return [...lower, ...upper];
  }

  double _crossProduct(LatLng o, LatLng a, LatLng b) {
    return (a.latitude - o.latitude) * (b.longitude - o.longitude) -
        (a.longitude - o.longitude) * (b.latitude - o.latitude);
  }

  void _showOccurrenceDetails(GbifOccurrence occurrence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Точка наблюдения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (occurrence.country.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.flag, size: 16),
                  const SizedBox(width: 4),
                  Text('Страна: ${occurrence.country}'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (occurrence.locality != null && occurrence.locality!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_city, size: 16),
                  const SizedBox(width: 4),
                  Text('Местность: ${occurrence.locality}'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (occurrence.habitat != null && occurrence.habitat!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.terrain, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Ареал: ${occurrence.habitat}')),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Text('Координаты: ${occurrence.latitude.toStringAsFixed(4)}, ${occurrence.longitude.toStringAsFixed(4)}'),
              ],
            ),
            if (occurrence.year != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text('Год: ${occurrence.year}'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openInExternalMap(occurrence.latitude, occurrence.longitude);
            },
            child: const Text('Открыть в картах'),
          ),
        ],
      ),
    );
  }

  void _openInExternalMap(double latitude, double longitude) {
    final url = ApiConstants.openStreetMapUrl
        .replaceAll('{lat}', latitude.toString())
        .replaceAll('{lon}', longitude.toString());
    launchUrl(Uri.parse(url));
  }

  void _resetMapView(Plant plant) {
    setState(() {
      _mapKey = ValueKey(DateTime.now().millisecondsSinceEpoch);
    });
  }

  void _showFullMapDialog(Plant plant) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Карта распространения: ${plant.latinName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildGbifMap(plant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
