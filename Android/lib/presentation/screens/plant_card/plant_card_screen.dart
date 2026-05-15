import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/logger/app_logger.dart';
import '../../../models/gbif_occurrence.dart';
import '../../../models/plant.dart';
import '../../providers/providers.dart';
import '../../../theme/cactus_theme.dart';
import '../../../services/api/gbif_service.dart';
import '../../../services/api/llifle_service.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widgets/image_selection_dialog.dart';
import '../../../widgets/qr_code_widget.dart';
import 'tabs/overview_tab.dart';
import 'tabs/care_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/gallery_tab.dart';
import 'tabs/distribution_tab.dart';
import 'tabs/seedlings_tab.dart';

class PlantCardScreen extends StatefulWidget {

  const PlantCardScreen({
    super.key,
    required this.plant,
  });
  final Plant plant;

  @override
  State<PlantCardScreen> createState() => _PlantCardScreenState();
}

class _PlantCardScreenState extends State<PlantCardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  Future<String>? _weatherFuture;

  @override
  void initState() {
    super.initState();
    final isBatch = widget.plant.isBatch;
    _tabController = TabController(length: isBatch ? 6 : 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _weatherFuture ??= context.read<WeatherProvider>()
        .getWeatherAdvice(widget.plant);
  }

  @override
  void didUpdateWidget(PlantCardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIsBatch = oldWidget.plant.isBatch;
    final newIsBatch = widget.plant.isBatch;
    if (oldIsBatch != newIsBatch) {
      final newLength = newIsBatch ? 6 : 5;
      if (_tabController.length != newLength) {
        _tabController.dispose();
        _tabController = TabController(length: newLength, vsync: this);
      }
    }
    if (oldWidget.plant.permanentId != widget.plant.permanentId) {
      _weatherFuture = context.read<WeatherProvider>()
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
    return Consumer<PlantCrudProvider>(
      builder: (context, plantCrud, child) {
        final updatedPlant = plantCrud.plants.firstWhere(
          (p) => p.permanentId == widget.plant.permanentId,
          orElse: () => widget.plant,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(updatedPlant.latinName),
            elevation: 0,
            actions: [
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
              ? null
              : FloatingActionButton(
                  onPressed: () async {
                    if (!context.mounted) return;
                    final result = await context.push<Plant>(
                      '/plant/${updatedPlant.permanentId}/edit',
                      extra: updatedPlant,
                    );
                    if (result != null && context.mounted) {
                      context.read<PlantCrudProvider>()
                          .updatePlant(updatedPlant.permanentId, result);
                      context.read<PlantCrudProvider>()
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
                          OverviewTab(plant: updatedPlant),
                          SeedlingsTab(
                            batch: updatedPlant,
                            onSeedlingTap: (ctx, seedling) {
                              ctx.push(
                                '/plant/${seedling.permanentId}',
                                extra: seedling,
                              );
                            },
                          ),
                          CareTab(
                            plant: updatedPlant,
                            weatherFuture: _weatherFuture,
                            onWatering: () => _markWateringToday(updatedPlant),
                            onFertilization: () => _planFertilization(updatedPlant),
                            onRepotting: () => _planRepotting(updatedPlant),
                            onFlowering: () => _markFlowering(updatedPlant),
                          ),
                          HistoryTab(
                            plant: updatedPlant,
                            onNotesChanged: () => setState(() {}),
                          ),
                          GalleryTab(
                            plant: updatedPlant,
                            onShowFullPhoto: _showFullPhoto,
                            onShowPhotoOptions: _showPhotoOptions,
                            onUploadPhoto: _uploadUserPhoto,
                            onRefreshLlifle: _refreshLliflePhotos,
                          ),
                          DistributionTab(
                            plant: updatedPlant,
                            onRefreshGbif: _refreshGbifData,
                          ),
                        ]
                      : [
                          OverviewTab(plant: updatedPlant),
                          CareTab(
                            plant: updatedPlant,
                            weatherFuture: _weatherFuture,
                            onWatering: () => _markWateringToday(updatedPlant),
                            onFertilization: () => _planFertilization(updatedPlant),
                            onRepotting: () => _planRepotting(updatedPlant),
                            onFlowering: () => _markFlowering(updatedPlant),
                          ),
                          HistoryTab(
                            plant: updatedPlant,
                            onNotesChanged: () => setState(() {}),
                          ),
                          GalleryTab(
                            plant: updatedPlant,
                            onShowFullPhoto: _showFullPhoto,
                            onShowPhotoOptions: _showPhotoOptions,
                            onUploadPhoto: _uploadUserPhoto,
                            onRefreshLlifle: _refreshLliflePhotos,
                          ),
                          DistributionTab(
                            plant: updatedPlant,
                            onRefreshGbif: _refreshGbifData,
                          ),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // === PHOTO HEADER ===
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
                      CactusColors.accentTerracotta.withValues(alpha: 191),
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
              if (plant.country != null && plant.country!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (plant.countryFlag != null)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          child: CachedNetworkImage(
                            imageUrl: plant.countryFlag!,
                            width: 20,
                            height: 14,
                            placeholder: (_, __) => const SizedBox(width: 20, height: 14),
                            errorWidget: (_, __, ___) => const SizedBox(width: 20, height: 14),
                          ),
                        ),
                      Text(
                        plant.country!,
                        style: TextStyle(
                          fontSize: Responsive.isMobile(context) ? 13 : 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black54),
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
                    Shadow(blurRadius: 10, color: Colors.black54),
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
      backgroundColor: CactusColors.sandLight.withValues(alpha: 230),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: CactusColors.accentTerracotta.withValues(alpha: 77)),
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


  // === QUICK ACTIONS ===
  void _markWateringToday(Plant plant) {
    if (!mounted) return;
    final provider = context.read<PlantCrudProvider>();
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
                plant.permanentId, wateringDate,);
            provider.savePlants();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Полив отменён'), backgroundColor: Colors.grey,),
            );
          },
        ),
      ),
    );
  }

  void _planFertilization(Plant plant) async {
    if (!mounted) return;
    final provider = context.read<PlantCrudProvider>();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (!mounted || selectedDate == null) return;

    final oldFertilization = plant.lastFertilization;

    provider.markAsFertilized(plant.permanentId, date: selectedDate);
    provider.savePlants();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Удобрение отмечено: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Отменить',
          textColor: Colors.white,
          onPressed: () {
            if (oldFertilization != null) {
              provider.markAsFertilized(plant.permanentId,
                  date: oldFertilization,);
            } else {
              final updated = plant.copyWith(
                  lastFertilization: null, plannedFertilizationDate: null,);
              provider.updatePlant(plant.permanentId, updated);
            }
            provider.savePlants();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Удобрение отменено'),
                  backgroundColor: Colors.grey,),
            );
          },
        ),
      ),
    );
  }

  void _planRepotting(Plant plant) async {
    if (!mounted) return;
    final provider = context.read<PlantCrudProvider>();

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
            'Пересадка запланирована на ${DateFormat('dd.MM.yyyy').format(selectedDate)}',),
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
                  backgroundColor: Colors.grey,),
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена'),),
        ],
      ),
    );

    if (!mounted || event == null) return;

    final provider = context.read<PlantCrudProvider>();
    final floweringDate = DateTime.now();

    provider.addFloweringEvent(plant.permanentId, floweringDate, event);
    provider.savePlants();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            event == 'bloomed' ? 'Отмечено цветение' : 'Отмечено увядание',),
        backgroundColor: event == 'bloomed' ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Отменить',
          textColor: Colors.white,
          onPressed: () {
            final updatedHistory =
                List<FloweringRecord>.from(plant.floweringHistory)
                  ..removeLast();
            final updatedPlant =
                plant.copyWith(floweringHistory: updatedHistory);
            provider.updatePlant(plant.permanentId, updatedPlant);
            provider.savePlants();
            setState(() {});

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Запись цветения отменена'),
                  backgroundColor: Colors.grey,),
            );
          },
        ),
      ),
    );
  }

  // === PHOTO ACTIONS ===
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
              final provider = context.read<PlantCrudProvider>();

              final isLliflePhoto = plant.lliflePhotoUrls.contains(photoUrl);
              final isUserPhoto = plant.userPhotos.contains(photoUrl);

              if (isLliflePhoto && isUserPhoto) {
                provider.removeUserPhoto(plant.permanentId, photoUrl);
              } else if (isLliflePhoto) {
                provider.removeLliflePhoto(plant.permanentId, photoUrl);
              } else if (isUserPhoto) {
                provider.removeUserPhoto(plant.permanentId, photoUrl);
              } else {
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

  void _setAsMainPhoto(BuildContext context, Plant plant, String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сделать главным?'),
        content: const Text(
            'Это фото будет отображаться в шапке карточки растения.',),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final provider = context.read<PlantCrudProvider>();
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

  void _showFullPhoto(
      BuildContext context, Plant plant, String photoUrl, bool isNetwork,) {
    final isMain =
        plant.userPhotos.isNotEmpty && plant.userPhotos.first == photoUrl;

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
      barrierColor: Colors.black.withValues(alpha: 242),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
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
                            color: Colors.white,),
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.red,
                            size: 100,),
                      )
                    : Image.file(
                        File(photoUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.red,
                            size: 100,),
                      ),
              ),
            ),
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 191),
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
            Positioned(
              top: 40,
              right: 40,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 179),
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
                            color: Colors.white70, fontSize: 15,),
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

  Future<void> _uploadUserPhoto(BuildContext context, Plant plant) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<PlantCrudProvider>();
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
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _refreshLliflePhotos(BuildContext context, Plant plant) async {
    await _selectAdultImage(plant);
  }

  Future<void> _selectAdultImage(Plant plant) async {
    final plantData = await LlifleService().fetchPlantData(plant.latinName);
    if (!mounted) return;
    if (plantData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось найти фото на Llifle')),
      );
      return;
    }

    List<String> adultPhotoUrls =
        List<String>.from(plantData['photoUrls'] ?? []);

    adultPhotoUrls = adultPhotoUrls
        .where((url) => url.isNotEmpty && url.contains('llifle.com'))
        .map((url) {
          var cleanUrl = url
              .replaceAll(
                  'https://llifle.comphotos/', 'https://llifle.com/photos/',)
              .replaceAll('+', '_')
              .replaceAll('_m.jpg', '_l.jpg')
              .replaceAll('_s.jpg', '_l.jpg');
          return Uri.encodeFull(cleanUrl);
        })
        .where((url) {
          try {
            final uri = Uri.parse(url);
            return uri.hasScheme && uri.hasAuthority &&
                   url.contains('llifle.com/photos/') &&
                   url.endsWith('.jpg');
          } catch (e) {
            return false;
          }
        })
        .toSet()
        .toList();

    if (adultPhotoUrls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото не найдены')),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => ImageSelectionDialog(
          imageUrls: adultPhotoUrls,
          onSelect: (selectedUrl) async {
            final provider = context.read<PlantCrudProvider>();
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

  // === GBIF REFRESH ===
  Future<void> _refreshGbifData(BuildContext context, Plant plant) async {
    if (!mounted) return;

    try {
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

      await GbifService().clearGbifCache(plant.latinName);

      final updatedData = await LlifleService().fetchPlantData(plant.latinName)
          .timeout(const Duration(seconds: 30));

      if (updatedData != null && context.mounted) {
        final provider = context.read<PlantCrudProvider>();

        List<String> gbifPhotoUrls = [];
        List<GbifOccurrence> gbifOccurrences = [];

        if (updatedData['gbifPhotoUrls'] != null) {
          try {
            final photoData = updatedData['gbifPhotoUrls'] as List<dynamic>?;
            gbifPhotoUrls = photoData
                ?.where((e) => e != null && e.toString().isNotEmpty)
                .map((e) => e.toString().trim())
                .where((url) => url.startsWith('http'))
                .toList() ?? [];
          } catch (e) {
            AppLogger.error('Ошибка обработки GBIF фото: $e', tag: 'PLANT_CARD');
          }
        }

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
            AppLogger.error('Ошибка обработки GBIF occurrences: $e', tag: 'PLANT_CARD');
          }
        }

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

        provider.updatePlant(plant.permanentId, updatedPlant);
        await provider.savePlants();

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
      if (context.mounted) {
        String errorMessage = 'Ошибка обновления';

        if (e.toString().contains('SocketException')) {
          errorMessage = 'Ошибка сети: проверьте подключение к интернету';
        } else if (e.toString().contains('TimeoutException')) {
          errorMessage = 'Превышено время ожидания: попробуйте ещё раз';
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

  // === QR CODE DIALOGS ===
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
              final provider = context.read<PlantCrudProvider>();
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
                      context.push(
                        '/print/settings',
                        extra: [plant],
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
