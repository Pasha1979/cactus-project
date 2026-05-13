import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../models/plant.dart';
import '../../../../presentation/providers/providers.dart';
import '../../../../services/image/photo_cache_manager.dart';
import '../../../../theme/cactus_theme.dart';

typedef ShowFullPhotoCallback = void Function(BuildContext, Plant, String, bool);
typedef PhotoOptionsCallback = void Function(BuildContext, Plant, String);
typedef PlantContextCallback = void Function(BuildContext, Plant);

class GalleryTab extends StatefulWidget {
  final Plant plant;
  final ShowFullPhotoCallback onShowFullPhoto;
  final PhotoOptionsCallback onShowPhotoOptions;
  final PlantContextCallback onUploadPhoto;
  final PlantContextCallback onRefreshLlifle;

  const GalleryTab({
    super.key,
    required this.plant,
    required this.onShowFullPhoto,
    required this.onShowPhotoOptions,
    required this.onUploadPhoto,
    required this.onRefreshLlifle,
  });

  @override
  State<GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<GalleryTab> {
  String _currentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _prefetchNetworkPhotos();
  }

  void _prefetchNetworkPhotos() {
    final plant = widget.plant;
    final networkUrls = [
      ...plant.lliflePhotoUrls,
      ...plant.gbifPhotoUrls,
    ].where((url) => url.startsWith('http')).toList();
    if (networkUrls.isNotEmpty) {
      PhotoCacheManager.prefetch(networkUrls);
    }
  }

  List<String> _getDisplayedPhotos() {
    final plant = widget.plant;
    if (_currentFilter == 'my') {
      return List.from(plant.userPhotos);
    } else if (_currentFilter == 'llifle') {
      return List.from(plant.lliflePhotoUrls);
    } else if (_currentFilter == 'gbif') {
      return List.from(plant.gbifPhotoUrls);
    } else {
      return [...plant.userPhotos, ...plant.lliflePhotoUrls, ...plant.gbifPhotoUrls];
    }
  }

  void _updateFilter(String newFilter) {
    setState(() {
      _currentFilter = newFilter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;
    final displayedPhotos = _getDisplayedPhotos();
    final photoCount = displayedPhotos.length;

    return Stack(
      children: [
        Column(
          children: [
            // Счётчик
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Text(
                'Фото: $photoCount',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,),
              ),
            ),

            // Фильтры
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFilterChip(Icons.photo_library, 'Все', 'all'),
                  const SizedBox(width: 10),
                  _buildFilterChip(Icons.camera_alt, 'Мои', 'my'),
                  const SizedBox(width: 10),
                  _buildFilterChip(Icons.cloud, 'С Llifle', 'llifle'),
                  const SizedBox(width: 10),
                  _buildFilterChip(Icons.photo_camera, 'GBIF', 'gbif'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Галерея
            Expanded(
              child: displayedPhotos.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined,
                              size: 80, color: Colors.grey,),
                          SizedBox(height: 16),
                          Text('В этом фильтре нет фото',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey,),),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: displayedPhotos.length,
                        itemBuilder: (context, index) {
                          final photo = displayedPhotos[index];
                          final isNetwork = photo.startsWith('http');
                          final isMainPhoto = plant.userPhotos.isNotEmpty &&
                              plant.userPhotos.first == photo;

                          return RepaintBoundary(
                            child: GestureDetector(
                            onTap: () {
                              if (isNetwork &&
                                  photo.startsWith('https://')) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) async {
                                  final provider =
                                      context.read<PlantCrudProvider>();
                                  await provider.ensureLocalPhotosExist();
                                });
                              }
                              widget.onShowFullPhoto(
                                  context, plant, photo, isNetwork,);
                            },
                            onLongPress: () =>
                                widget.onShowPhotoOptions(context, plant, photo),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  isNetwork
                                      ? CachedNetworkImage(
                                          imageUrl: photo,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => const Center(
                                              child:
                                                  CircularProgressIndicator(),),
                                          errorWidget: (_, __, ___) =>
                                              const Icon(Icons.broken_image,
                                                  color: Colors.red,
                                                  size: 48,),
                                        )
                                      : Image.file(
                                          File(photo),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image,
                                                  color: Colors.red,
                                                  size: 48,),
                                        ),
                                  if (isMainPhoto)
                                    const Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Icon(Icons.star,
                                          color: Colors.amber, size: 32,),
                                    ),
                                ],
                              ),
                            ),
                          ),);
                        },
                      ),
                    ),
            ),
          ],
        ),

        // FAB кнопки
        Positioned(
          bottom: 30,
          right: 30,
          child: FloatingActionButton(
            heroTag: 'fab_add_photo_${plant.permanentId}',
            onPressed: () => widget.onUploadPhoto(context, plant),
            tooltip: 'Добавить своё фото',
            backgroundColor: Colors.green,
            elevation: 6,
            child: const Icon(Icons.add_a_photo),
          ),
        ),

        Positioned(
          bottom: 30,
          left: 140,
          child: FloatingActionButton.small(
            heroTag: 'fab_llifle_${plant.permanentId}',
            onPressed: () => widget.onRefreshLlifle(context, plant),
            tooltip: 'Загрузить ещё фото с Llifle',
            backgroundColor: Colors.orange,
            child: const Icon(Icons.cloud_download),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(IconData icon, String label, String value) {
    final isSelected = _currentFilter == value;

    return FilterChip(
      avatar: Icon(icon,
          size: 18, color: isSelected ? Colors.white : Colors.grey[700],),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        _updateFilter(value);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: CactusColors.accentTerracotta.withValues(alpha: 204),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      elevation: isSelected ? 2 : 0,
    );
  }
}
