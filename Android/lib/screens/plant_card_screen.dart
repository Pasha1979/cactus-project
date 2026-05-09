import 'dart:async';
import 'package:flutter/material.dart';
import '../models/plant.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/llifle_utils.dart';
import '../utils/gbif_utils.dart';
import '../screens/plant_statistics_screen.dart';
import '../screens/edit_plant_screen.dart';
import '../widgets/notes_bottom_sheet.dart';
import '../widgets/image_selection_dialog.dart';
import '../widgets/qr_code_widget.dart';
import '../screens/print_settings_screen.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../theme/cactus_theme.dart';
import '../utils/responsive_helper.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class PlantCardScreen extends StatefulWidget {
  final Plant plant;

  const PlantCardScreen({
    super.key,
    required this.plant,
  });

  @override
  State<PlantCardScreen> createState() => _PlantCardScreenState();
}

class _PlantCardScreenState extends State<PlantCardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0; // ←←← ДОБАВЬТЕ ЭТУ СТРОКУ
  ValueKey? _mapKey; // Ключ для обновления карты
  Future<String>? _weatherFuture; // Кэш Future для вкладки Уход

  @override
  void initState() {
    super.initState();
    final isBatch = widget.plant.isBatch;
    _tabController = TabController(length: isBatch ? 6 : 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _weatherFuture ??= Provider.of<PlantProvider>(context, listen: false)
        .getWeatherAdvice(widget.plant);
  }

  @override
  void didUpdateWidget(PlantCardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем TabController если изменилось состояние isBatch
    final oldIsBatch = oldWidget.plant.isBatch;
    final newIsBatch = widget.plant.isBatch;
    if (oldIsBatch != newIsBatch) {
      final newLength = newIsBatch ? 6 : 5;
      if (_tabController.length != newLength) {
        _tabController.dispose();
        _tabController = TabController(length: newLength, vsync: this);
      }
    }
    // Обновляем future если открылось другое растение
    if (oldWidget.plant.permanentId != widget.plant.permanentId) {
      _weatherFuture = Provider.of<PlantProvider>(context, listen: false)
          .getWeatherAdvice(widget.plant);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        final updatedPlant = plantProvider.plants.firstWhere(
          (p) => p.permanentId == widget.plant.permanentId,
          orElse: () => widget.plant,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(updatedPlant.latinName),
            elevation: 0,
            actions: [
              // Кнопка создания/просмотра QR кода
              if (updatedPlant.qrCode == null)
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  tooltip: 'Создать QR код',
                  onPressed: () {
                    _showCreateQRCodeDialog(context, updatedPlant);
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Показать QR код',
                  onPressed: () {
                    _showQRCodeDialog(context, updatedPlant);
                  },
                ),
            ],
          ),
          floatingActionButton: _currentTabIndex == 3
              ? null // На вкладке "Галерея" кнопки редактирования нет
              : FloatingActionButton(
                  onPressed: () async {
                    if (!context.mounted) return;
                    final result = await Navigator.push<Plant>(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => EditPlantScreen(plant: updatedPlant),
                      ),
                    );
                    if (result != null && context.mounted) {
                      Provider.of<PlantProvider>(context, listen: false)
                          .updatePlant(updatedPlant.permanentId, result);
                      Provider.of<PlantProvider>(context, listen: false)
                          .savePlants();
                    }
                  },
                  tooltip: 'Редактировать растение',
                  child: const Icon(Icons.edit),
                ),
          body: Column(
            children: [
              _buildPhotoHeader(context, updatedPlant),
              TabBar(
                controller: _tabController,
                labelColor: Colors.green.shade700,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.green,
                onTap: (index) {
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
                tabs: updatedPlant.isBatch
                    ? const [
                        Tab(icon: Icon(Icons.visibility), text: 'Обзор'),
                        Tab(icon: Icon(Icons.spa), text: 'Сеянцы'),
                        Tab(icon: Icon(Icons.local_florist), text: 'Уход'),
                        Tab(icon: Icon(Icons.history), text: 'История'),
                        Tab(icon: Icon(Icons.photo_library), text: 'Галерея'),
                        Tab(icon: Icon(Icons.public), text: 'Распространение'),
                      ]
                    : const [
                        Tab(icon: Icon(Icons.visibility), text: 'Обзор'),
                        Tab(icon: Icon(Icons.local_florist), text: 'Уход'),
                        Tab(icon: Icon(Icons.history), text: 'История'),
                        Tab(icon: Icon(Icons.photo_library), text: 'Галерея'),
                        Tab(icon: Icon(Icons.public), text: 'Распространение'),
                      ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: updatedPlant.isBatch
                      ? [
                          _buildOverviewTab(context, updatedPlant),
                          _buildSeedlingsTab(context, updatedPlant),
                          _buildCareTab(context, updatedPlant),
                          _buildHistoryTab(context, updatedPlant),
                          _buildGalleryTab(context, updatedPlant),
                          _buildDistributionTab(context, updatedPlant),
                        ]
                      : [
                          _buildOverviewTab(context, updatedPlant),
                          _buildCareTab(context, updatedPlant),
                          _buildHistoryTab(context, updatedPlant),
                          _buildGalleryTab(context, updatedPlant),
                          _buildDistributionTab(context, updatedPlant),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Адаптивная шапка с фото — улучшенная версия
  Widget _buildPhotoHeader(BuildContext context, Plant plant) {
    final mainPhoto = plant.userPhotos.isNotEmpty
        ? plant.userPhotos.first
        : (plant.lliflePhotoUrls.isNotEmpty
            ? plant.lliflePhotoUrls.first
            : null);

    final headerHeight = Responsive.isMobile(context) ? 220.0 : 280.0;

    return Stack(
      children: [
        if (mainPhoto != null)
          Hero(
            tag: 'photo_${plant.permanentId}',
            child: Container(
              height: headerHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: mainPhoto.startsWith('http')
                      ? CachedNetworkImageProvider(mainPhoto)
                      : FileImage(File(mainPhoto)) as ImageProvider,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      CactusColors.accentTerracotta.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          Container(height: headerHeight, color: CactusColors.sandLight),
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Компактная информация о стране с флагом
              if (plant.country != null && plant.country!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (plant.countryFlag != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          child: Image.network(
                            plant.countryFlag!,
                            width: 20,
                            height: 14,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.flag, size: 16, color: Colors.white70),
                          ),
                        ),
                      Text(
                        plant.country!,
                        style: TextStyle(
                          fontSize: Responsive.isMobile(context) ? 13 : 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black54)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                plant.latinName,
                style: TextStyle(
                  fontSize: Responsive.isMobile(context) ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [
                    Shadow(blurRadius: 10, color: Colors.black54)
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusIndicator(plant),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildChip(Icons.calendar_today, '${plant.age} лет'),
                  _buildChip(Icons.numbers, plant.displayId),
                  _buildChip(Icons.water_drop, plant.lastWateringText),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18, color: CactusColors.primaryGreen),
      label: Text(label, style: const TextStyle(fontSize: 13.5)),
      backgroundColor: CactusColors.sandBeige,
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  // === ВКЛАДКА 1: ОБЗОР ===
  Widget _buildOverviewTab(BuildContext context, Plant plant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGeographySection(context, plant),
          const SizedBox(height: 16),
          _buildDescriptionSection(context, plant),
          const SizedBox(height: 16),
          _buildSynonymsSection(plant),

          const SizedBox(height: 24),

          const SizedBox(height: 12),

          // Кнопка Преобразовать в партию (только если живых >= 2 и это не витрина)
          if (!plant.isBatch && plant.getCurrentAliveCount >= 2)
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Преобразовать в партию?'),
                      content: Text(
                        'Создать партию с ${plant.getCurrentAliveCount} сеянцами?\n\n'
                        'Каждый сеянец получит свой ID (${plant.displayId}-1, ${plant.displayId}-2 и т.д.) '
                        'и сможет отслеживаться отдельно.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Создать',
                              style: TextStyle(color: Colors.green)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await Provider.of<PlantProvider>(context, listen: false)
                        .convertToBatch(plant.permanentId, context);
                  }
                },
                icon: const Icon(Icons.group_add),
                label: Text('Преобразовать в партию (${plant.getCurrentAliveCount} шт.)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          // Индикатор что это витрина
          if (plant.isBatch)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Витрина-партия: ${plant.childrenIds.length} сеянцев',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // === ВКЛАДКА 2: УХОД (безопасная версия — только существующие методы) ===
  Widget _buildCareTab(BuildContext context, Plant plant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок вкладки
          Row(
            children: [
              const Icon(Icons.spa, size: 32, color: Colors.green),
              const SizedBox(width: 12),
              const Text(
                'Уход за растением',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1. Погода и рекомендация на сегодня
          FutureBuilder<String>(
            future: _weatherFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final advice = snapshot.data ?? 'Нет данных о погоде';
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wb_sunny, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Сегодня',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        advice,
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 2. Основные рекомендации по уходу
          const Text(
            'Основные рекомендации',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildCareTipsSection(context, plant),
          const SizedBox(height: 32),

          // 3. Быстрые действия (с отменой и визуальной обратной связью)
          const Text(
            'Быстрые действия',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            children: [
              _buildActionCard(
                icon: Icons.water_drop,
                title: 'Полить сегодня',
                color: Colors.blue,
                onTap: () => _markWateringToday(plant),
              ),
              _buildActionCard(
                icon: Icons.science,
                title: 'Удобрить',
                color: Colors.purple,
                onTap: () => _planFertilization(plant),
              ),
              _buildActionCard(
                icon: Icons.yard,
                title: 'Пересадить',
                color: Colors.brown,
                onTap: () => _planRepotting(plant),
              ),
              _buildActionCard(
                icon: Icons.local_florist,
                title: 'Отметить цветение',
                color: Colors.pink,
                onTap: () => _markFlowering(plant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Вкладка История
  Widget _buildHistoryTab(BuildContext context, Plant plant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_note, color: Colors.green),
            title: const Text('Заметки'),
            subtitle: Text('${plant.notes.length} заметок'),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => NotesBottomSheet(plant: plant),
              ).then((_) => setState(() {}));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.purple),
            title: const Text('Подробная статистика'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlantStatisticsScreen(plant: plant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === ВКЛАДКА 4: ГАЛЕРЕЯ (простая и надёжная версия) ===
  Widget _buildGalleryTab(BuildContext context, Plant plant) {
    return StatefulBuilder(
      builder: (context, setGalleryState) {
        // Текущее состояние фильтра - внутри StatefulBuilder
        String currentFilter = 'all';

        // Функция для обновления фильтра и фото
        void updateFilter(String newFilter) {
          setGalleryState(() {
            currentFilter = newFilter;
          });
        }

        // Функция для получения отфильтрованных фото
        List<String> getDisplayedPhotos() {
          if (currentFilter == 'my') {
            return List.from(plant.userPhotos);
          } else if (currentFilter == 'llifle') {
            return List.from(plant.lliflePhotoUrls);
          } else if (currentFilter == 'gbif') {
            return List.from(plant.gbifPhotoUrls);
          } else {
            // Объединяем все фото: пользовательские, Llifle и GBIF
            return [...plant.userPhotos, ...plant.lliflePhotoUrls, ...plant.gbifPhotoUrls];
          }
        }

        final displayedPhotos = getDisplayedPhotos();
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
                        color: Colors.grey),
                  ),
                ),

                // Фильтры
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterChip(Icons.photo_library, 'Все', 'all',
                          currentFilter, () => updateFilter('all'), plant),
                      const SizedBox(width: 10),
                      _buildFilterChip(Icons.camera_alt, 'Мои', 'my',
                          currentFilter, () => updateFilter('my'), plant),
                      const SizedBox(width: 10),
                      _buildFilterChip(Icons.cloud, 'С Llifle', 'llifle',
                          currentFilter, () => updateFilter('llifle'), plant),
                      const SizedBox(width: 10),
                      _buildFilterChip(Icons.photo_camera, 'GBIF', 'gbif',
                          currentFilter, () => updateFilter('gbif'), plant),
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
                                  size: 80, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('В этом фильтре нет фото',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey)),
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

                              return GestureDetector(
                                onTap: () {
                                  if (isNetwork &&
                                      photo.startsWith('https://')) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) async {
                                      final provider =
                                          Provider.of<PlantProvider>(context,
                                              listen: false);
                                      await provider.ensureLocalPhotosExist();
                                    });
                                  }
                                  _showFullPhoto(
                                      context, plant, photo, isNetwork);
                                },
                                onLongPress: () =>
                                    _showPhotoOptions(context, plant, photo),
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
                                                      CircularProgressIndicator()),
                                              errorWidget: (_, __, ___) =>
                                                  const Icon(Icons.broken_image,
                                                      color: Colors.red,
                                                      size: 48),
                                            )
                                          : Image.file(
                                              File(photo),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.broken_image,
                                                      color: Colors.red,
                                                      size: 48),
                                            ),
                                      if (isMainPhoto)
                                        const Positioned(
                                          top: 12,
                                          right: 12,
                                          child: Icon(Icons.star,
                                              color: Colors.amber, size: 32),
                                        ),
                                    ],
                                  ),
                                ),
                              );
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
                onPressed: () => _uploadUserPhoto(context, plant),
                tooltip: 'Добавить своё фото',
                backgroundColor: Colors.green,
                elevation: 6,
                child: const Icon(Icons.add_a_photo),
              ),
            ),

            Positioned(
              bottom: 30,
              left: 140, // сдвинули правее, чтобы не накладывалась
              child: FloatingActionButton.small(
                heroTag: 'fab_llifle_${plant.permanentId}',
                onPressed: () => _refreshLliflePhotos(context, plant),
                tooltip: 'Загрузить ещё фото с Llifle',
                backgroundColor: Colors.orange,
                child: const Icon(Icons.cloud_download),
              ),
            ),
          ],
        );
      },
    );
  }

  // === ВКЛАДКА 5: РАСПРОСТРАНЕНИЕ (GBIF данные) ===
  Widget _buildDistributionTab(BuildContext context, Plant plant) {
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
                onPressed: () => _refreshGbifData(context, plant),
                icon: const Icon(Icons.refresh),
                tooltip: 'Обновить данные GBIF',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Страна с флагом
          _buildCountryInfo(plant),
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
                          child: _buildStatCard(
                            context,
                            'Точки наблюдения',
                            plant.gbifOccurrences.length.toString(),
                            Icons.location_on,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Фото из природы',
                            plant.gbifPhotoUrls.length.toString(),
                            Icons.photo_camera,
                            Colors.green,
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
                    // Заголовок карты с элементами управления
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
                                onPressed: () => _resetMapView(context, plant),
                                icon: const Icon(Icons.center_focus_strong),
                                tooltip: 'Центрировать карту',
                                iconSize: 20,
                              ),
                              IconButton(
                                onPressed: () => _showFullMapDialog(context, plant),
                                icon: const Icon(Icons.fullscreen),
                                tooltip: 'Полноэкранная карта',
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Карта
                    Expanded(
                      child: _buildGbifMap(context, plant),
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
            _buildEmptyGbifState(context, plant),
            
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Информация о стране с флагом (замена для отсутствующего _buildCountryRow)
  Widget _buildCountryInfo(Plant plant) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.public, color: Colors.blue.shade600, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Страна происхождения',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (plant.countryFlag != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: Image.network(
                            plant.countryFlag!,
                            width: 24,
                            height: 16,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.flag, size: 20),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          plant.country?.isNotEmpty == true ? plant.country! : 'Не указана',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Пустое состояние для отсутствия GBIF данных
  Widget _buildEmptyGbifState(BuildContext context, Plant plant) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade50,
              Colors.grey.shade100.withValues(alpha: 0.5),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.public_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет данных GBIF',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Нажмите кнопку обновления,\nчтобы загрузить данные из природы',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _refreshGbifData(context, plant),
              icon: const Icon(Icons.refresh),
              label: const Text('Загрузить данные'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный метод для карточки статистики
  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Форматирование даты
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
           '${date.month.toString().padLeft(2, '0')}.'
           '${date.year}';
  }

  // Обновление GBIF данных с улучшенной безопасностью и обработкой ошибок
  Future<void> _refreshGbifData(BuildContext context, Plant plant) async {
    // Проверяем начальное состояние
    if (!mounted) return;
    
    try {
      // Показываем индикатор загрузки
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 8),
                Text('Обновление данных GBIF...'),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Очищаем кэш для этого растения
      await clearGbifCache(plant.latinName);
      
      // Получаем обновленные данные с таймаутом
      final updatedData = await fetchPlantData(plant.latinName)
          .timeout(const Duration(seconds: 30));
      
      if (updatedData != null && context.mounted) {
        // Обновляем растение новыми данными
        final provider = Provider.of<PlantProvider>(context, listen: false);
        
        // Безопасная конвертация GBIF данных с валидацией
        List<String> gbifPhotoUrls = [];
        List<GbifOccurrence> gbifOccurrences = [];
        
        // Обработка GBIF фото с валидацией
        if (updatedData['gbifPhotoUrls'] != null) {
          try {
            final photoData = updatedData['gbifPhotoUrls'] as List<dynamic>?;
            gbifPhotoUrls = photoData
                ?.where((e) => e != null && e.toString().isNotEmpty)
                .map((e) => e.toString().trim())
                .where((url) => url.startsWith('http'))
                .toList() ?? [];
          } catch (e) {
            print('Ошибка обработки GBIF фото: $e');
          }
        }
        
        // Обработка GBIF occurrences с валидацией
        if (updatedData['gbifOccurrences'] != null) {
          try {
            final occurrenceData = updatedData['gbifOccurrences'] as List<dynamic>?;
            gbifOccurrences = occurrenceData
                ?.where((e) => e != null)
                .map((e) {
                  if (e is GbifOccurrence) {
                    return e.hasValidCoordinates ? e : null;
                  } else if (e is Map<String, dynamic>) {
                    final occ = GbifOccurrence.fromJson(e);
                    return occ.hasValidCoordinates ? occ : null;
                  } else {
                    // Пробуем создать occurrence из сериализованных данных
                    try {
                      final map = Map<String, dynamic>.from(e as Map);
                      final occ = GbifOccurrence.fromJson(map);
                      return occ.hasValidCoordinates ? occ : null;
                    } catch (_) {
                      return null;
                    }
                  }
                })
                .where((occ) => occ != null)
                .cast<GbifOccurrence>()
                .toList() ?? [];
          } catch (e) {
            print('Ошибка обработки GBIF occurrences: $e');
          }
        }
        
        // Создаем обновленное растение с безопасными проверками
        final updatedPlant = plant.copyWith(
          country: updatedData['country']?.toString().trim() ?? plant.country,
          habitat: updatedData['habitat']?.toString().trim() ?? plant.habitat,
          synonyms: updatedData['synonyms']?.toString().trim() ?? plant.synonyms,
          gbifPhotoUrls: gbifPhotoUrls,
          gbifOccurrences: gbifOccurrences,
          lastGbifUpdate: updatedData['lastGbifUpdate'] != null
              ? DateTime.tryParse(updatedData['lastGbifUpdate'].toString())
              : DateTime.now(),
        );
        
        // Обновляем в Provider
        provider.updatePlant(plant.permanentId, updatedPlant);
        await provider.savePlants();
        
        // Обновляем UI с проверкой mounted
        if (mounted) {
          setState(() {});
          
          final occurrenceCount = updatedData['gbifOccurrenceCount'] ?? gbifOccurrences.length;
          final photoCount = updatedData['gbifPhotoCount'] ?? gbifPhotoUrls.length;
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Данные обновлены: $occurrenceCount точек, $photoCount фото'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (context.mounted) {
        // Данные не получены
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Данные GBIF не найдены для этого растения'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Обработка ошибок с детальной информацией
      if (context.mounted) {
        String errorMessage = 'Ошибка обновления';
        
        if (e.toString().contains('SocketException')) {
          errorMessage = 'Ошибка сети: проверьте подключение к интернету';
        } else if (e.toString().contains('TimeoutException')) {
          errorMessage = 'Превышено время ожидания: попробуйте еще раз';
        } else if (e.toString().contains('HTTP')) {
          errorMessage = 'Ошибка сервера GBIF: сервис временно недоступен';
        } else {
          errorMessage = 'Ошибка обновления: ${e.toString().substring(0, 50)}...';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Повторить',
              textColor: Colors.white,
              onPressed: () => _refreshGbifData(context, plant),
            ),
          ),
        );
      }
    }
  }

  // === МЕТОДЫ ИНТЕРАКТИВНОЙ КАРТЫ GBIF ===
  
  // Основной виджет карты с occurrence точками
  Widget _buildGbifMap(BuildContext context, Plant plant) {
    if (plant.gbifOccurrences.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Text('Нет точек наблюдения'),
        ),
      );
    }

    // Вычисляем центр карты на основе всех occurrence точек
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
        // OpenStreetMap тайлы
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pavel.mycactus',
          maxZoom: 19,
        ),
        // Слой с маркерами occurrence точек
        MarkerLayer(
          markers: plant.gbifOccurrences.map((occurrence) {
            return _buildOccurrenceMarker(context, occurrence);
          }).toList(),
        ),
        // Слой с полигонами для визуализации ареала (опционально)
        if (plant.gbifOccurrences.length > 3)
          PolygonLayer(
            polygons: [_buildOccurrencePolygon(plant.gbifOccurrences)],
          ),
      ],
    );
  }

  // Расчет центра карты на основе occurrence точек
  LatLng _calculateMapCenter(List<GbifOccurrence> occurrences) {
    if (occurrences.isEmpty) {
      return const LatLng(0.0, 0.0); // Центр мира по умолчанию
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

  // Создание маркера для occurrence точки
  Marker _buildOccurrenceMarker(BuildContext context, GbifOccurrence occurrence) {
    return Marker(
      point: LatLng(occurrence.latitude, occurrence.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showOccurrenceDetails(context, occurrence),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
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

  // Построение полигона для визуализации ареала (выпуклая оболочка)
  Polygon _buildOccurrencePolygon(List<GbifOccurrence> occurrences) {
    final validPoints = occurrences
        .where((occ) => occ.hasValidCoordinates)
        .map((occ) => LatLng(occ.latitude, occ.longitude))
        .toList();

    if (validPoints.length < 3) {
      // Создаем простой прямоугольник для 2 точек
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
          color: Colors.green.withValues(alpha: 0.2),
          borderStrokeWidth: 2,
          borderColor: Colors.green.withValues(alpha: 0.6),
        );
      }
      // Для 1 точки создаем маленький квадрат
      if (validPoints.length == 1) {
        final lat = validPoints[0].latitude;
        final lng = validPoints[0].longitude;
        final delta = 0.5; // ~50км
        
        return Polygon(
          points: [
            LatLng(lat + delta, lng + delta),
            LatLng(lat + delta, lng - delta),
            LatLng(lat - delta, lng - delta),
            LatLng(lat - delta, lng + delta),
          ],
          color: Colors.green.withValues(alpha: 0.2),
          borderStrokeWidth: 2,
          borderColor: Colors.green.withValues(alpha: 0.6),
        );
      }
    }

    // Для 3+ точек создаем выпуклую оболочку
    final hullPoints = _calculateConvexHull(validPoints);
    
    return Polygon(
      points: hullPoints,
      color: Colors.green.withValues(alpha: 0.2),
      borderStrokeWidth: 2,
      borderColor: Colors.green.withValues(alpha: 0.6),
    );
  }

  // Вычисление выпуклой оболочки (алгоритм Грэхема)
  List<LatLng> _calculateConvexHull(List<LatLng> points) {
    if (points.length < 3) return points;
    
    // Сортировка по x, затем по y
    final sortedPoints = List<LatLng>.from(points);
    sortedPoints.sort((a, b) {
      if (a.latitude != b.latitude) {
        return a.latitude.compareTo(b.latitude);
      }
      return a.longitude.compareTo(b.longitude);
    });

    // Построение нижней оболочки
    final List<LatLng> lower = [];
    for (final point in sortedPoints) {
      while (lower.length >= 2 && _crossProduct(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) {
        lower.removeLast();
      }
      lower.add(point);
    }

    // Построение верхней оболочки
    final List<LatLng> upper = [];
    for (final point in sortedPoints.reversed) {
      while (upper.length >= 2 && _crossProduct(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) {
        upper.removeLast();
      }
      upper.add(point);
    }

    // Объединение (удаление последней точки каждой, так как она дублируется)
    lower.removeLast();
    upper.removeLast();
    
    return [...lower, ...upper];
  }

  // Векторное произведение для определения поворота
  double _crossProduct(LatLng o, LatLng a, LatLng b) {
    return (a.latitude - o.latitude) * (b.longitude - o.longitude) -
           (a.longitude - o.longitude) * (b.latitude - o.latitude);
  }

  // Показ деталей occurrence точки
  void _showOccurrenceDetails(BuildContext context, GbifOccurrence occurrence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Точка наблюдения'),
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

  // Открытие координат во внешнем приложении карт
  void _openInExternalMap(double latitude, double longitude) {
    final url = 'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=15/$latitude/$longitude';
    launchUrl(Uri.parse(url));
  }

  // Сброс вида карты к центру
  void _resetMapView(BuildContext context, Plant plant) {
    if (!mounted) return;
    setState(() {
      // Перестраиваем карту для обновления центра
      _mapKey = ValueKey(DateTime.now().millisecondsSinceEpoch);
    });
  }

  // Полноэкранная карта
  void _showFullMapDialog(BuildContext context, Plant plant) {
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
                  child: _buildGbifMap(context, plant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
  // Вспомогательный чип с иконкой
  Widget _buildFilterChip(
    IconData icon,
    String label,
    String value,
    String currentFilter,
    VoidCallback onTap,
    Plant plant,
  ) {
    final isSelected = currentFilter == value;

    return FilterChip(
      avatar: Icon(icon,
          size: 18, color: isSelected ? Colors.white : Colors.grey[700]),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        onTap();
      },
      backgroundColor: Colors.grey[200],
      selectedColor: CactusColors.accentTerracotta.withValues(alpha: 0.8),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      elevation: isSelected ? 2 : 0,
    );
  }

  void _setAsMainPhoto(BuildContext context, Plant plant, String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сделать главным?'),
        content: const Text(
            'Это фото будет отображаться в шапке карточки растения.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final provider =
                  Provider.of<PlantProvider>(context, listen: false);
              final userPhotos = List<String>.from(plant.userPhotos);
              userPhotos.remove(photoUrl);
              userPhotos.insert(0, photoUrl);

              final updatedPlant = plant.copyWith(userPhotos: userPhotos);
              provider.updatePlant(plant.permanentId, updatedPlant);
              provider.savePlants();

              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Сделать главным'),
          ),
        ],
      ),
    );
  }

  // Показываем меню при долгом нажатии на своё фото
  void _showPhotoOptions(BuildContext context, Plant plant, String photoUrl) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('Сделать главным фото'),
            onTap: () {
              Navigator.pop(ctx);
              _setAsMainPhoto(context, plant, photoUrl);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Удалить фото'),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDeletePhoto(context, plant, photoUrl);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Подтверждение удаления
  void _confirmDeletePhoto(BuildContext context, Plant plant, String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить фото?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final provider =
                  Provider.of<PlantProvider>(context, listen: false);
              
              // Определяем тип фото и вызываем правильный метод удаления
              final isLliflePhoto = plant.lliflePhotoUrls.contains(photoUrl);
              final isUserPhoto = plant.userPhotos.contains(photoUrl);
              
              if (isLliflePhoto && isUserPhoto) {
                // Если фото в обоих списках, приоритет - userPhotos (локальные файлы)
                provider.removeUserPhoto(plant.permanentId, photoUrl);
              } else if (isLliflePhoto) {
                provider.removeLliflePhoto(plant.permanentId, photoUrl);
              } else if (isUserPhoto) {
                provider.removeUserPhoto(plant.permanentId, photoUrl);
              } else {
                // Фото не найдено - показываем ошибку
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Фото не найдено в галерее'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                Navigator.pop(ctx);
                return;
              }

              Navigator.pop(ctx);
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showFullPhoto(
      BuildContext context, Plant plant, String photoUrl, bool isNetwork) {
    final isMain =
        plant.userPhotos.isNotEmpty && plant.userPhotos.first == photoUrl;

    // Определяем дату добавления
    String dateText = 'Дата неизвестна';
    if (!isNetwork && photoUrl.isNotEmpty) {
      try {
        final file = File(photoUrl);
        if (file.existsSync()) {
          final lastModified = file.lastModifiedSync();
          dateText =
              'Добавлено: ${lastModified.day.toString().padLeft(2, '0')}.'
              '${lastModified.month.toString().padLeft(2, '0')}.'
              '${lastModified.year}';
        }
      } catch (_) {
        dateText = 'Дата неизвестна';
      }
    } else {
      dateText = 'Фото из облака / Llifle';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Зум и панорамирование мышкой
            Center(
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 8.0,
                child: isNetwork
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const CircularProgressIndicator(
                            color: Colors.white),
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.red,
                            size: 100),
                      )
                    : Image.file(
                        File(photoUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.red,
                            size: 100),
                      ),
              ),
            ),

            // Название растения и ID — сверху по центру
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        plant.latinName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        plant.displayId,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Кнопка закрытия
            Positioned(
              top: 40,
              right: 40,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // Информация снизу
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMain) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 28),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        isMain ? 'Главное фото' : 'Обычное фото',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        dateText,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // === РАБОЧИЕ БЫСТРЫЕ ДЕЙСТВИЯ С ОТМЕНОЙ ===

  void _markWateringToday(Plant plant) {
    if (!mounted) return;
    final provider = Provider.of<PlantProvider>(context, listen: false);
    final wateringDate = DateTime.now();

    provider.addIndividualWateringDate(plant.permanentId, wateringDate);
    provider.savePlants();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Растение ${plant.latinName} полито сегодня'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Отменить',
          textColor: Colors.white,
          onPressed: () {
            provider.removeIndividualWateringDate(
                plant.permanentId, wateringDate);
            provider.savePlants();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Полив отменён'), backgroundColor: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  void _planFertilization(Plant plant) async {
    if (!mounted) return;
    final provider = Provider.of<PlantProvider>(context, listen: false);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (!mounted || selectedDate == null) return;

    final oldFertilization = plant.lastFertilization; // для возможной отмены

    provider.markAsFertilized(plant.permanentId, date: selectedDate);
    provider.savePlants();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Удобрение отмечено: ${DateFormat('dd.MM.yyyy').format(selectedDate)}'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Отменить',
          textColor: Colors.white,
          onPressed: () {
            if (oldFertilization != null) {
              provider.markAsFertilized(plant.permanentId,
                  date: oldFertilization);
            } else {
              // Если не было предыдущей даты — просто сбрасываем
              final updated = plant.copyWith(
                  lastFertilization: null, plannedFertilizationDate: null);
              provider.updatePlant(plant.permanentId, updated);
            }
            provider.savePlants();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Удобрение отменено'),
                  backgroundColor: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  void _planRepotting(Plant plant) async {
    if (!mounted) return;
    final provider = Provider.of<PlantProvider>(context, listen: false);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: plant.plannedTransplantDate ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (!mounted || selectedDate == null) return;

    final oldPlanned = plant.plannedTransplantDate;

    final updatedPlant = plant.copyWith(plannedTransplantDate: selectedDate);
    provider.updatePlant(plant.permanentId, updatedPlant);
    provider.savePlants();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Пересадка запланирована на ${DateFormat('dd.MM.yyyy').format(selectedDate)}'),
        backgroundColor: Colors.brown,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Отменить',
          textColor: Colors.white,
          onPressed: () {
            final revertPlant =
                plant.copyWith(plannedTransplantDate: oldPlanned);
            provider.updatePlant(plant.permanentId, revertPlant);
            provider.savePlants();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Планирование пересадки отменено'),
                  backgroundColor: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  void _markFlowering(Plant plant) async {
    if (!mounted) return;

    final event = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отметить цветение'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.local_florist),
              label: const Text('Расцвело'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, 'bloomed'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.wb_sunny),
              label: const Text('Завяло'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, 'wilted'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ],
      ),
    );

    if (!mounted || event == null) return;

    final provider = Provider.of<PlantProvider>(context, listen: false);
    final floweringDate = DateTime.now();

    provider.addFloweringEvent(plant.permanentId, floweringDate, event);
    provider.savePlants();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            event == 'bloomed' ? 'Отмечено цветение' : 'Отмечено увядание'),
        backgroundColor: event == 'bloomed' ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Отменить',
          textColor: Colors.white,
          onPressed: () {
            // Удаляем последнюю запись цветения (простой способ отмены)
            final updatedHistory =
                List<FloweringRecord>.from(plant.floweringHistory)
                  ..removeLast(); // удаляем последнюю добавленную
            final updatedPlant =
                plant.copyWith(floweringHistory: updatedHistory);
            provider.updatePlant(plant.permanentId, updatedPlant);
            provider.savePlants();
            setState(() {});

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Запись цветения отменена'),
                  backgroundColor: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  
  Widget _buildStatusIndicator(Plant plant) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(plant.status).withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        plant.statusText,
        style: TextStyle(
          color: _getStatusColor(plant.status),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGeographySection(BuildContext context, Plant plant) {
    final habitatText = plant.habitat ?? 'Не указано';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.map, color: Colors.green),
        title: const Text(
          'Естественный ареал',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.grey),
          onPressed: () async {
            final result = await Navigator.push<Plant>(
              context,
              MaterialPageRoute(
                builder: (ctx) => EditPlantScreen(plant: plant),
              ),
            );
            if (result != null && context.mounted) {
              Provider.of<PlantProvider>(context, listen: false)
                  .updatePlant(plant.permanentId, result);
              Provider.of<PlantProvider>(context, listen: false).savePlants();
            }
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              habitatText,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectAdultImage(Plant plant) async {
    final plantData = await fetchPlantData(plant.latinName);
    if (!mounted) return;
    if (plantData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось найти фото на Llifle')),
      );
      return;
    }

    List<String> adultPhotoUrls =
        List<String>.from(plantData['photoUrls'] ?? []);

    // === УЛУЧШЕННАЯ: Фильтрация и очистка ссылок ===
    adultPhotoUrls = adultPhotoUrls
        .where((url) => url.isNotEmpty && url.contains('llifle.com'))
        .map((url) {
          var cleanUrl = url
              .replaceAll(
                  'https://llifle.comphotos/', 'https://llifle.com/photos/')
              .replaceAll('+', '_')
              .replaceAll('_m.jpg', '_l.jpg')
              .replaceAll('_s.jpg', '_l.jpg'); // Добавляем замену маленьких фото
          return Uri.encodeFull(cleanUrl);
        })
        .where((url) {
          // Дополнительная валидация URL
          try {
            final uri = Uri.parse(url);
            return uri.hasScheme && uri.hasAuthority && 
                   url.contains('llifle.com/photos/') && 
                   url.endsWith('.jpg');
          } catch (e) {
            return false;
          }
        })
        .toSet() // Убираем дубликаты
        .toList();

    if (adultPhotoUrls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото не найдены')),
        );
      }
      return;
    }

    // Показываем диалог с отфильтрованными фото
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => ImageSelectionDialog(
          imageUrls: adultPhotoUrls,
          onSelect: (selectedUrl) async {
            final provider = Provider.of<PlantProvider>(context, listen: false);
            await provider.addLliflePhoto(plant.permanentId, selectedUrl);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Фото с Llifle добавлено')),
              );
            }
          },
        ),
      );
    }
  }

  Widget _buildDescriptionSection(BuildContext context, Plant plant) {
    final descriptionText = plant.description ?? 'Добавьте описание...';
    final descriptionList = descriptionText.split('\n');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.description, color: Colors.green),
        title: const Text(
          'Описание',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.grey),
          onPressed: () async {
            final result = await Navigator.push<Plant>(
              context,
              MaterialPageRoute(
                builder: (ctx) => EditPlantScreen(plant: plant),
              ),
            );
            if (result != null && context.mounted) {
              Provider.of<PlantProvider>(context, listen: false)
                  .updatePlant(plant.permanentId, result);
              Provider.of<PlantProvider>(context, listen: false).savePlants();
            }
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: descriptionList.length == 1
                ? Text(
                    descriptionText,
                    style: const TextStyle(fontSize: 16),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: descriptionList
                        .map((desc) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                desc,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynonymsSection(Plant plant) {
    final synonymsText = plant.synonyms ?? 'Синонимы не указаны';
    final synonymsList = synonymsText.split('\n');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.bookmark, color: Colors.green),
        title: const Text(
          'Синонимы',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: synonymsList.length == 1
                ? Text(
                    synonymsText,
                    style: const TextStyle(fontSize: 16),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: synonymsList
                        .map((synonym) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                synonym,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareTipsSection(BuildContext context, Plant plant) {
    final careTipsText = plant.careTips ?? 'Особенности ухода не указаны';
    final careTipsList = careTipsText.split('\n');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.lightbulb, color: Colors.green),
        title: const Text(
          'Особенности ухода',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.grey),
          onPressed: () async {
            final result = await Navigator.push<Plant>(
              context,
              MaterialPageRoute(
                builder: (ctx) => EditPlantScreen(plant: plant),
              ),
            );
            if (result != null && context.mounted) {
              Provider.of<PlantProvider>(context, listen: false)
                  .updatePlant(plant.permanentId, result);
              Provider.of<PlantProvider>(context, listen: false).savePlants();
            }
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: careTipsList.length == 1
                ? Text(
                    careTipsText,
                    style: const TextStyle(fontSize: 16),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: careTipsList
                        .map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                tip,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isActive = true, // Новое: можно ли нажать
    String? activeTitle, // Новое: альтернативный текст после действия
  }) {
    final displayTitle = activeTitle ?? title;
    final displayColor = isActive ? color : Colors.grey;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: isActive ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: displayColor),
              const SizedBox(height: 16),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: displayColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadUserPhoto(BuildContext context, Plant plant) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<PlantProvider>(context, listen: false);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          final path = file.path!;
          await provider.addUserPhoto(plant.permanentId, path);
        }
        if (!mounted) return;
        setState(() {}); // просто обновляем экран
      }
    } catch (e) {
      print('Ошибка загрузки фото: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_collection':
        return Colors.amber;
      case 'growing':
        return Colors.lightGreen;
      case 'dead':
        return Colors.red;
      case 'failed':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String getWateringTextFromDate(DateTime date) {
    return _formatDate(date);
  }

  // Обновление фото с Llifle - теперь вызывает выбор фото
  Future<void> _refreshLliflePhotos(BuildContext context, Plant plant) async {
    await _selectAdultImage(plant);
  }

  // === ВКЛАДКА СЕЯНЦЫ (для витрин-партий) ===
  Widget _buildSeedlingsTab(BuildContext context, Plant batch) {
    return Consumer<PlantProvider>(
      builder: (context, provider, child) {
        final seedlings = provider.getBatchSeedlings(batch.permanentId);

        if (seedlings.isEmpty) {
          return const Center(
            child: Text(
              'Нет сеянцев в этой партии',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: seedlings.length,
          itemBuilder: (context, index) {
            final seedling = seedlings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: _buildSeedlingPhoto(seedling),
                title: Text('${seedling.displayId} — ${seedling.latinName}'),
                subtitle: Text('Статус: ${seedling.statusText}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Кнопка смены статуса
                    _buildStatusButton(context, provider, seedling),
                    // Кнопка удаления
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить сеянец?'),
                            content: Text('Удалить ${seedling.displayId}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Удалить',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await provider.removeSeedlingFromBatch(
                            batch.permanentId,
                            seedling.permanentId,
                            context,
                          );
                        }
                      },
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  // Открываем карточку сеянца
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlantCardScreen(plant: seedling),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // Построение миниатюры фото сеянца (с проверкой http vs file)
  Widget _buildSeedlingPhoto(Plant seedling) {
    if (seedling.userPhotos.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.spa, color: Colors.grey),
      );
    }

    final photoUrl = seedling.userPhotos.first;
    final isNetworkPhoto = photoUrl.startsWith('http') || photoUrl.startsWith('https');

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isNetworkPhoto
          ? CachedNetworkImage(
              imageUrl: photoUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(Icons.hourglass_empty, color: Colors.grey),
              ),
              errorWidget: (context, url, error) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 40),
              ),
            )
          : Image.file(
              File(photoUrl),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 40),
              ),
            ),
    );
  }

  // Кнопка смены статуса сеянца
  Widget _buildStatusButton(BuildContext context, PlantProvider provider, Plant seedling) {
    // Определяем цвет по статусу
    Color statusColor;
    switch (seedling.status) {
      case 'growing':
        statusColor = Colors.orange;
        break;
      case 'in_collection':
        statusColor = Colors.green;
        break;
      case 'dead':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.blue;
    }

    return PopupMenuButton<String>(
      tooltip: 'Изменить статус',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withAlpha(26), // 0.1 * 255 = 25.5 -> 26
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.fiber_manual_record,
          color: statusColor,
          size: 20,
        ),
      ),
      onSelected: (String newStatus) async {
        // Обновляем статус сеянца
        final updatedSeedling = seedling.copyWith(status: newStatus);
        provider.updatePlant(seedling.permanentId, updatedSeedling);

        // Показываем уведомление
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус ${seedling.displayId} изменён на: ${_getStatusText(newStatus)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'growing',
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text('Растёт'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'in_collection',
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text('В коллекции'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'dead',
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text('Погиб'),
            ],
          ),
        ),
      ],
    );
  }

  // Вспомогательный метод для получения текста статуса
  String _getStatusText(String status) {
    switch (status) {
      case 'growing':
        return 'Растёт';
      case 'in_collection':
        return 'В коллекции';
      case 'dead':
        return 'Погиб';
      default:
        return status;
    }
  }

  // === МЕТОДЫ ДЛЯ QR КОДОВ ===

  /// Показывает диалог создания QR кода
  void _showCreateQRCodeDialog(BuildContext context, Plant plant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать QR код?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Создать QR код для растения:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              plant.latinName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${plant.displayId}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            const Text(
              'QR код будет содержать ID и название растения. Вы сможете распечатать его на этикетке.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final provider = Provider.of<PlantProvider>(context, listen: false);
              provider.createQRCode(plant.permanentId);
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('QR код для ${plant.latinName} создан'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.qr_code),
            label: const Text('Создать'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  /// Показывает диалог с QR кодом
  void _showQRCodeDialog(BuildContext context, Plant plant) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                plant.latinName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'ID: ${plant.displayId}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              QRCodeWidget(
                plant: plant,
                size: 250,
                showName: false,
              ),
              const SizedBox(height: 16),
              const Text(
                'Отсканируйте для быстрого поиска растения',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => PrintSettingsScreen(
                            plantsToPrint: [plant],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Печать'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    label: const Text('Закрыть'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

