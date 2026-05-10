import 'dart:async';
import 'package:flutter/material.dart';
import '../models/plant.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/llifle_utils.dart';
import '../utils/gbif_utils.dart';
import '../screens/plant_statistics_screen.dart';
import '../screens/edit_plant_screen.dart';
import '../widgets/notes_bottom_sheet.dart';
import '../widgets/image_selection_dialog.dart';
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
  int _currentTabIndex = 0; // в†ђв†ђв†ђ Р”РћР‘РђР’Р¬РўР• Р­РўРЈ РЎРўР РћРљРЈ
  ValueKey? _mapKey; // РљР»СЋС‡ РґР»СЏ РѕР±РЅРѕРІР»РµРЅРёСЏ РєР°СЂС‚С‹
  Future<String>? _weatherFuture; // РљСЌС€ Future РґР»СЏ РІРєР»Р°РґРєРё РЈС…РѕРґ

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
    // РћР±РЅРѕРІР»СЏРµРј TabController РµСЃР»Рё РёР·РјРµРЅРёР»РѕСЃСЊ СЃРѕСЃС‚РѕСЏРЅРёРµ isBatch
    final oldIsBatch = oldWidget.plant.isBatch;
    final newIsBatch = widget.plant.isBatch;
    if (oldIsBatch != newIsBatch) {
      final newLength = newIsBatch ? 6 : 5;
      if (_tabController.length != newLength) {
        _tabController.dispose();
        _tabController = TabController(length: newLength, vsync: this);
      }
    }
    // РћР±РЅРѕРІР»СЏРµРј future РµСЃР»Рё РѕС‚РєСЂС‹Р»РѕСЃСЊ РґСЂСѓРіРѕРµ СЂР°СЃС‚РµРЅРёРµ
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
              // РљРЅРѕРїРєР° СЃРѕР·РґР°РЅРёСЏ/РїСЂРѕСЃРјРѕС‚СЂР° QR РєРѕРґР°
              if (updatedPlant.qrCode == null)
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  tooltip: 'РЎРѕР·РґР°С‚СЊ QR РєРѕРґ',
                  onPressed: () {
                    _showCreateQRCodeDialog(context, updatedPlant);
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'РџРѕРєР°Р·Р°С‚СЊ QR РєРѕРґ',
                  onPressed: () {
                    _showQRCodeDialog(context, updatedPlant);
                  },
                ),
            ],
          ),
          floatingActionButton: _currentTabIndex == 3
              ? null // РќР° РІРєР»Р°РґРєРµ "Р“Р°Р»РµСЂРµСЏ" РєРЅРѕРїРєРё СЂРµРґР°РєС‚РёСЂРѕРІР°РЅРёСЏ РЅРµС‚
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
                      context.read<PlantCrudProvider>()
                          .updatePlant(updatedPlant.permanentId, result);
                      context.read<PlantCrudProvider>()
                          .savePlants();
                    }
                  },
                  tooltip: 'Р РµРґР°РєС‚РёСЂРѕРІР°С‚СЊ СЂР°СЃС‚РµРЅРёРµ',
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
                        Tab(icon: Icon(Icons.visibility), text: 'РћР±Р·РѕСЂ'),
                        Tab(icon: Icon(Icons.spa), text: 'РЎРµСЏРЅС†С‹'),
                        Tab(icon: Icon(Icons.local_florist), text: 'РЈС…РѕРґ'),
                        Tab(icon: Icon(Icons.history), text: 'РСЃС‚РѕСЂРёСЏ'),
                        Tab(icon: Icon(Icons.photo_library), text: 'Р“Р°Р»РµСЂРµСЏ'),
                        Tab(icon: Icon(Icons.public), text: 'Р Р°СЃРїСЂРѕСЃС‚СЂР°РЅРµРЅРёРµ'),
                      ]
                    : const [
                        Tab(icon: Icon(Icons.visibility), text: 'РћР±Р·РѕСЂ'),
                        Tab(icon: Icon(Icons.local_florist), text: 'РЈС…РѕРґ'),
                        Tab(icon: Icon(Icons.history), text: 'РСЃС‚РѕСЂРёСЏ'),
                        Tab(icon: Icon(Icons.photo_library), text: 'Р“Р°Р»РµСЂРµСЏ'),
                        Tab(icon: Icon(Icons.public), text: 'Р Р°СЃРїСЂРѕСЃС‚СЂР°РЅРµРЅРёРµ'),
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

  // РђРґР°РїС‚РёРІРЅР°СЏ С€Р°РїРєР° СЃ С„РѕС‚Рѕ вЂ” СѓР»СѓС‡С€РµРЅРЅР°СЏ РІРµСЂСЃРёСЏ
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
              // РљРѕРјРїР°РєС‚РЅР°СЏ РёРЅС„РѕСЂРјР°С†РёСЏ Рѕ СЃС‚СЂР°РЅРµ СЃ С„Р»Р°РіРѕРј
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
                  _buildChip(Icons.calendar_today, '${plant.age} Р»РµС‚'),
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

  // === Р’РљР›РђР”РљРђ 1: РћР‘Р—РћР  ===
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

          // РљРЅРѕРїРєР° РџСЂРµРѕР±СЂР°Р·РѕРІР°С‚СЊ РІ РїР°СЂС‚РёСЋ (С‚РѕР»СЊРєРѕ РµСЃР»Рё Р¶РёРІС‹С… >= 2 Рё СЌС‚Рѕ РЅРµ РІРёС‚СЂРёРЅР°)
          if (!plant.isBatch && plant.getCurrentAliveCount >= 2)
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('РџСЂРµРѕР±СЂР°Р·РѕРІР°С‚СЊ РІ РїР°СЂС‚РёСЋ?'),
                      content: Text(
                        'РЎРѕР·РґР°С‚СЊ РїР°СЂС‚РёСЋ СЃ ${plant.getCurrentAliveCount} СЃРµСЏРЅС†Р°РјРё?\n\n'
                        'РљР°Р¶РґС‹Р№ СЃРµСЏРЅРµС† РїРѕР»СѓС‡РёС‚ СЃРІРѕР№ ID (${plant.displayId}-1, ${plant.displayId}-2 Рё С‚.Рґ.) '
                        'Рё СЃРјРѕР¶РµС‚ РѕС‚СЃР»РµР¶РёРІР°С‚СЊСЃСЏ РѕС‚РґРµР»СЊРЅРѕ.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('РћС‚РјРµРЅР°'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('РЎРѕР·РґР°С‚СЊ',
                              style: TextStyle(color: Colors.green)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    final count = context.read<PlantCrudProvider>()
                        .convertToBatch(plant.permanentId);
                    if (count > 0 && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Создано партию с $count сеянцами')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.group_add),
                label: Text('РџСЂРµРѕР±СЂР°Р·РѕРІР°С‚СЊ РІ РїР°СЂС‚РёСЋ (${plant.getCurrentAliveCount} С€С‚.)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          // РРЅРґРёРєР°С‚РѕСЂ С‡С‚Рѕ СЌС‚Рѕ РІРёС‚СЂРёРЅР°
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
                    'Р’РёС‚СЂРёРЅР°-РїР°СЂС‚РёСЏ: ${plant.childrenIds.length} СЃРµСЏРЅС†РµРІ',
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

  // === Р’РљР›РђР”РљРђ 2: РЈРҐРћР” (Р±РµР·РѕРїР°СЃРЅР°СЏ РІРµСЂСЃРёСЏ вЂ” С‚РѕР»СЊРєРѕ СЃСѓС‰РµСЃС‚РІСѓСЋС‰РёРµ РјРµС‚РѕРґС‹) ===
  Widget _buildCareTab(BuildContext context, Plant plant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Р—Р°РіРѕР»РѕРІРѕРє РІРєР»Р°РґРєРё
          Row(
            children: [
              const Icon(Icons.spa, size: 32, color: Colors.green),
              const SizedBox(width: 12),
              const Text(
                'РЈС…РѕРґ Р·Р° СЂР°СЃС‚РµРЅРёРµРј',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 1. РџРѕРіРѕРґР° Рё СЂРµРєРѕРјРµРЅРґР°С†РёСЏ РЅР° СЃРµРіРѕРґРЅСЏ
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
              final advice = snapshot.data ?? 'РќРµС‚ РґР°РЅРЅС‹С… Рѕ РїРѕРіРѕРґРµ';
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
                          Text('РЎРµРіРѕРґРЅСЏ',
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

          // 2. РћСЃРЅРѕРІРЅС‹Рµ СЂРµРєРѕРјРµРЅРґР°С†РёРё РїРѕ СѓС…РѕРґСѓ
          const Text(
            'РћСЃРЅРѕРІРЅС‹Рµ СЂРµРєРѕРјРµРЅРґР°С†РёРё',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildCareTipsSection(context, plant),
          const SizedBox(height: 32),

          // 3. Р‘С‹СЃС‚СЂС‹Рµ РґРµР№СЃС‚РІРёСЏ (СЃ РѕС‚РјРµРЅРѕР№ Рё РІРёР·СѓР°Р»СЊРЅРѕР№ РѕР±СЂР°С‚РЅРѕР№ СЃРІСЏР·СЊСЋ)
          const Text(
            'Р‘С‹СЃС‚СЂС‹Рµ РґРµР№СЃС‚РІРёСЏ',
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
                title: 'РџРѕР»РёС‚СЊ СЃРµРіРѕРґРЅСЏ',
                color: Colors.blue,
                onTap: () => _markWateringToday(plant),
              ),
              _buildActionCard(
                icon: Icons.science,
                title: 'РЈРґРѕР±СЂРёС‚СЊ',
                color: Colors.purple,
                onTap: () => _planFertilization(plant),
              ),
              _buildActionCard(
                icon: Icons.yard,
                title: 'РџРµСЂРµСЃР°РґРёС‚СЊ',
                color: Colors.brown,
                onTap: () => _planRepotting(plant),
              ),
              _buildActionCard(
                icon: Icons.local_florist,
                title: 'РћС‚РјРµС‚РёС‚СЊ С†РІРµС‚РµРЅРёРµ',
                color: Colors.pink,
                onTap: () => _markFlowering(plant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Р’РєР»Р°РґРєР° РСЃС‚РѕСЂРёСЏ
  Widget _buildHistoryTab(BuildContext context, Plant plant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_note, color: Colors.green),
            title: const Text('Р—Р°РјРµС‚РєРё'),
            subtitle: Text('${plant.notes.length} Р·Р°РјРµС‚РѕРє'),
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
            title: const Text('РџРѕРґСЂРѕР±РЅР°СЏ СЃС‚Р°С‚РёСЃС‚РёРєР°'),
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

  // === Р’РљР›РђР”РљРђ 4: Р“РђР›Р•Р Р•РЇ (РїСЂРѕСЃС‚Р°СЏ Рё РЅР°РґС‘Р¶РЅР°СЏ РІРµСЂСЃРёСЏ) ===
  Widget _buildGalleryTab(BuildContext context, Plant plant) {
    return StatefulBuilder(
      builder: (context, setGalleryState) {
        // РўРµРєСѓС‰РµРµ СЃРѕСЃС‚РѕСЏРЅРёРµ С„РёР»СЊС‚СЂР° - РІРЅСѓС‚СЂРё StatefulBuilder
        String currentFilter = 'all';

        // Р¤СѓРЅРєС†РёСЏ РґР»СЏ РѕР±РЅРѕРІР»РµРЅРёСЏ С„РёР»СЊС‚СЂР° Рё С„РѕС‚Рѕ
        void updateFilter(String newFilter) {
          setGalleryState(() {
            currentFilter = newFilter;
          });
        }

        // Р¤СѓРЅРєС†РёСЏ РґР»СЏ РїРѕР»СѓС‡РµРЅРёСЏ РѕС‚С„РёР»СЊС‚СЂРѕРІР°РЅРЅС‹С… С„РѕС‚Рѕ
        List<String> getDisplayedPhotos() {
          if (currentFilter == 'my') {
            return List.from(plant.userPhotos);
          } else if (currentFilter == 'llifle') {
            return List.from(plant.lliflePhotoUrls);
          } else if (currentFilter == 'gbif') {
            return List.from(plant.gbifPhotoUrls);
          } else {
            // РћР±СЉРµРґРёРЅСЏРµРј РІСЃРµ С„РѕС‚Рѕ: РїРѕР»СЊР·РѕРІР°С‚РµР»СЊСЃРєРёРµ, Llifle Рё GBIF
            return [...plant.userPhotos, ...plant.lliflePhotoUrls, ...plant.gbifPhotoUrls];
          }
        }

        final displayedPhotos = getDisplayedPhotos();
        final photoCount = displayedPhotos.length;

        return Stack(
          children: [
            Column(
              children: [
                // РЎС‡С‘С‚С‡РёРє
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Text(
                    'Р¤РѕС‚Рѕ: $photoCount',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey),
                  ),
                ),

                // Р¤РёР»СЊС‚СЂС‹
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFilterChip(Icons.photo_library, 'Р’СЃРµ', 'all',
                          currentFilter, () => updateFilter('all'), plant),
                      const SizedBox(width: 10),
                      _buildFilterChip(Icons.camera_alt, 'РњРѕРё', 'my',
                          currentFilter, () => updateFilter('my'), plant),
                      const SizedBox(width: 10),
                      _buildFilterChip(Icons.cloud, 'РЎ Llifle', 'llifle',
                          currentFilter, () => updateFilter('llifle'), plant),
                      const SizedBox(width: 10),
                      _buildFilterChip(Icons.photo_camera, 'GBIF', 'gbif',
                          currentFilter, () => updateFilter('gbif'), plant),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Р“Р°Р»РµСЂРµСЏ
                Expanded(
                  child: displayedPhotos.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library_outlined,
                                  size: 80, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Р’ СЌС‚РѕРј С„РёР»СЊС‚СЂРµ РЅРµС‚ С„РѕС‚Рѕ',
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
                                          context.read<PlantCrudProvider>();
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

            // FAB РєРЅРѕРїРєРё
            Positioned(
              bottom: 30,
              right: 30,
              child: FloatingActionButton(
                heroTag: 'fab_add_photo_${plant.permanentId}',
                onPressed: () => _uploadUserPhoto(context, plant),
                tooltip: 'Р”РѕР±Р°РІРёС‚СЊ СЃРІРѕС‘ С„РѕС‚Рѕ',
                backgroundColor: Colors.green,
                elevation: 6,
                child: const Icon(Icons.add_a_photo),
              ),
            ),

            Positioned(
              bottom: 30,
              left: 140, // СЃРґРІРёРЅСѓР»Рё РїСЂР°РІРµРµ, С‡С‚РѕР±С‹ РЅРµ РЅР°РєР»Р°РґС‹РІР°Р»Р°СЃСЊ
              child: FloatingActionButton.small(
                heroTag: 'fab_llifle_${plant.permanentId}',
                onPressed: () => _refreshLliflePhotos(context, plant),
                tooltip: 'Р—Р°РіСЂСѓР·РёС‚СЊ РµС‰С‘ С„РѕС‚Рѕ СЃ Llifle',
                backgroundColor: Colors.orange,
                child: const Icon(Icons.cloud_download),
              ),
            ),
          ],
        );
      },
    );
  }

  // === Р’РљР›РђР”РљРђ 5: Р РђРЎРџР РћРЎРўР РђРќР•РќРР• (GBIF РґР°РЅРЅС‹Рµ) ===
  Widget _buildDistributionTab(BuildContext context, Plant plant) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Р—Р°РіРѕР»РѕРІРѕРє Рё РєРЅРѕРїРєР° РѕР±РЅРѕРІР»РµРЅРёСЏ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Р Р°СЃРїСЂРѕСЃС‚СЂР°РЅРµРЅРёРµ РІРёРґР°',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              IconButton(
                onPressed: () => _refreshGbifData(context, plant),
                icon: const Icon(Icons.refresh),
                tooltip: 'РћР±РЅРѕРІРёС‚СЊ РґР°РЅРЅС‹Рµ GBIF',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // РЎС‚СЂР°РЅР° СЃ С„Р»Р°РіРѕРј
          _buildCountryInfo(plant),
          const SizedBox(height: 16),
          
          // РђСЂРµР°Р» РѕР±РёС‚Р°РЅРёСЏ
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
                          'РђСЂРµР°Р» РѕР±РёС‚Р°РЅРёСЏ',
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
          
          // GBIF СЃС‚Р°С‚РёСЃС‚РёРєР°
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
                          'Р”Р°РЅРЅС‹Рµ GBIF',
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
                            'РўРѕС‡РєРё РЅР°Р±Р»СЋРґРµРЅРёСЏ',
                            plant.gbifOccurrences.length.toString(),
                            Icons.location_on,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Р¤РѕС‚Рѕ РёР· РїСЂРёСЂРѕРґС‹',
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
                        'РћР±РЅРѕРІР»РµРЅРѕ: ${_formatDate(plant.lastGbifUpdate!)}',
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
          
          // РРЅС‚РµСЂР°РєС‚РёРІРЅР°СЏ РєР°СЂС‚Р° СЃ occurrence С‚РѕС‡РєР°РјРё GBIF
          if (plant.gbifOccurrences.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: SizedBox(
                height: 400,
                width: double.infinity,
                child: Column(
                  children: [
                    // Р—Р°РіРѕР»РѕРІРѕРє РєР°СЂС‚С‹ СЃ СЌР»РµРјРµРЅС‚Р°РјРё СѓРїСЂР°РІР»РµРЅРёСЏ
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
                            'РўРѕС‡РєРё РЅР°Р±Р»СЋРґРµРЅРёСЏ GBIF: ${plant.gbifOccurrences.length}',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _resetMapView(context, plant),
                                icon: const Icon(Icons.center_focus_strong),
                                tooltip: 'Р¦РµРЅС‚СЂРёСЂРѕРІР°С‚СЊ РєР°СЂС‚Сѓ',
                                iconSize: 20,
                              ),
                              IconButton(
                                onPressed: () => _showFullMapDialog(context, plant),
                                icon: const Icon(Icons.fullscreen),
                                tooltip: 'РџРѕР»РЅРѕСЌРєСЂР°РЅРЅР°СЏ РєР°СЂС‚Р°',
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // РљР°СЂС‚Р°
                    Expanded(
                      child: _buildGbifMap(context, plant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Р¤РѕС‚Рѕ РёР· РїСЂРёСЂРѕРґС‹ GBIF
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
                          'Р¤РѕС‚Рѕ РёР· РїСЂРёСЂРѕРґС‹ (GBIF)',
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
          
          // РџСѓСЃС‚РѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ - РµСЃР»Рё РЅРµС‚ GBIF РґР°РЅРЅС‹С…
          if (plant.gbifOccurrences.isEmpty && plant.gbifPhotoUrls.isEmpty)
            _buildEmptyGbifState(context, plant),
            
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // РРЅС„РѕСЂРјР°С†РёСЏ Рѕ СЃС‚СЂР°РЅРµ СЃ С„Р»Р°РіРѕРј (Р·Р°РјРµРЅР° РґР»СЏ РѕС‚СЃСѓС‚СЃС‚РІСѓСЋС‰РµРіРѕ _buildCountryRow)
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
                    'РЎС‚СЂР°РЅР° РїСЂРѕРёСЃС…РѕР¶РґРµРЅРёСЏ',
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
                          plant.country?.isNotEmpty == true ? plant.country! : 'РќРµ СѓРєР°Р·Р°РЅР°',
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

  // РџСѓСЃС‚РѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ РґР»СЏ РѕС‚СЃСѓС‚СЃС‚РІРёСЏ GBIF РґР°РЅРЅС‹С…
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
              'РќРµС‚ РґР°РЅРЅС‹С… GBIF',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'РќР°Р¶РјРёС‚Рµ РєРЅРѕРїРєСѓ РѕР±РЅРѕРІР»РµРЅРёСЏ,\nС‡С‚РѕР±С‹ Р·Р°РіСЂСѓР·РёС‚СЊ РґР°РЅРЅС‹Рµ РёР· РїСЂРёСЂРѕРґС‹',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _refreshGbifData(context, plant),
              icon: const Icon(Icons.refresh),
              label: const Text('Р—Р°РіСЂСѓР·РёС‚СЊ РґР°РЅРЅС‹Рµ'),
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

  // Р’СЃРїРѕРјРѕРіР°С‚РµР»СЊРЅС‹Р№ РјРµС‚РѕРґ РґР»СЏ РєР°СЂС‚РѕС‡РєРё СЃС‚Р°С‚РёСЃС‚РёРєРё
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

  // Р¤РѕСЂРјР°С‚РёСЂРѕРІР°РЅРёРµ РґР°С‚С‹
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
           '${date.month.toString().padLeft(2, '0')}.'
           '${date.year}';
  }

  // РћР±РЅРѕРІР»РµРЅРёРµ GBIF РґР°РЅРЅС‹С… СЃ СѓР»СѓС‡С€РµРЅРЅРѕР№ Р±РµР·РѕРїР°СЃРЅРѕСЃС‚СЊСЋ Рё РѕР±СЂР°Р±РѕС‚РєРѕР№ РѕС€РёР±РѕРє
  Future<void> _refreshGbifData(BuildContext context, Plant plant) async {
    // РџСЂРѕРІРµСЂСЏРµРј РЅР°С‡Р°Р»СЊРЅРѕРµ СЃРѕСЃС‚РѕСЏРЅРёРµ
    if (!mounted) return;
    
    try {
      // РџРѕРєР°Р·С‹РІР°РµРј РёРЅРґРёРєР°С‚РѕСЂ Р·Р°РіСЂСѓР·РєРё
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
                Text('РћР±РЅРѕРІР»РµРЅРёРµ РґР°РЅРЅС‹С… GBIF...'),
              ],
            ),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.blue,
          ),
        );
      }

      // РћС‡РёС‰Р°РµРј РєСЌС€ РґР»СЏ СЌС‚РѕРіРѕ СЂР°СЃС‚РµРЅРёСЏ
      await clearGbifCache(plant.latinName);
      
      // РџРѕР»СѓС‡Р°РµРј РѕР±РЅРѕРІР»РµРЅРЅС‹Рµ РґР°РЅРЅС‹Рµ СЃ С‚Р°Р№РјР°СѓС‚РѕРј
      final updatedData = await fetchPlantData(plant.latinName)
          .timeout(const Duration(seconds: 30));
      
      if (updatedData != null && context.mounted) {
        // РћР±РЅРѕРІР»СЏРµРј СЂР°СЃС‚РµРЅРёРµ РЅРѕРІС‹РјРё РґР°РЅРЅС‹РјРё
        final provider = context.read<PlantCrudProvider>();
        
        // Р‘РµР·РѕРїР°СЃРЅР°СЏ РєРѕРЅРІРµСЂС‚Р°С†РёСЏ GBIF РґР°РЅРЅС‹С… СЃ РІР°Р»РёРґР°С†РёРµР№
        List<String> gbifPhotoUrls = [];
        List<GbifOccurrence> gbifOccurrences = [];
        
        // РћР±СЂР°Р±РѕС‚РєР° GBIF С„РѕС‚Рѕ СЃ РІР°Р»РёРґР°С†РёРµР№
        if (updatedData['gbifPhotoUrls'] != null) {
          try {
            final photoData = updatedData['gbifPhotoUrls'] as List<dynamic>?;
            gbifPhotoUrls = photoData
                ?.where((e) => e != null && e.toString().isNotEmpty)
                .map((e) => e.toString().trim())
                .where((url) => url.startsWith('http'))
                .toList() ?? [];
          } catch (e) {
            print('РћС€РёР±РєР° РѕР±СЂР°Р±РѕС‚РєРё GBIF С„РѕС‚Рѕ: $e');
          }
        }
        
        // РћР±СЂР°Р±РѕС‚РєР° GBIF occurrences СЃ РІР°Р»РёРґР°С†РёРµР№
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
                    // РџСЂРѕР±СѓРµРј СЃРѕР·РґР°С‚СЊ occurrence РёР· СЃРµСЂРёР°Р»РёР·РѕРІР°РЅРЅС‹С… РґР°РЅРЅС‹С…
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
            print('РћС€РёР±РєР° РѕР±СЂР°Р±РѕС‚РєРё GBIF occurrences: $e');
          }
        }
        
        // РЎРѕР·РґР°РµРј РѕР±РЅРѕРІР»РµРЅРЅРѕРµ СЂР°СЃС‚РµРЅРёРµ СЃ Р±РµР·РѕРїР°СЃРЅС‹РјРё РїСЂРѕРІРµСЂРєР°РјРё
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
        
        // РћР±РЅРѕРІР»СЏРµРј РІ Provider
        provider.updatePlant(plant.permanentId, updatedPlant);
        await provider.savePlants();
        
        // РћР±РЅРѕРІР»СЏРµРј UI СЃ РїСЂРѕРІРµСЂРєРѕР№ mounted
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
                    Text('Р”Р°РЅРЅС‹Рµ РѕР±РЅРѕРІР»РµРЅС‹: $occurrenceCount С‚РѕС‡РµРє, $photoCount С„РѕС‚Рѕ'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (context.mounted) {
        // Р”Р°РЅРЅС‹Рµ РЅРµ РїРѕР»СѓС‡РµРЅС‹
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Р”Р°РЅРЅС‹Рµ GBIF РЅРµ РЅР°Р№РґРµРЅС‹ РґР»СЏ СЌС‚РѕРіРѕ СЂР°СЃС‚РµРЅРёСЏ'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // РћР±СЂР°Р±РѕС‚РєР° РѕС€РёР±РѕРє СЃ РґРµС‚Р°Р»СЊРЅРѕР№ РёРЅС„РѕСЂРјР°С†РёРµР№
      if (context.mounted) {
        String errorMessage = 'РћС€РёР±РєР° РѕР±РЅРѕРІР»РµРЅРёСЏ';
        
        if (e.toString().contains('SocketException')) {
          errorMessage = 'РћС€РёР±РєР° СЃРµС‚Рё: РїСЂРѕРІРµСЂСЊС‚Рµ РїРѕРґРєР»СЋС‡РµРЅРёРµ Рє РёРЅС‚РµСЂРЅРµС‚Сѓ';
        } else if (e.toString().contains('TimeoutException')) {
          errorMessage = 'РџСЂРµРІС‹С€РµРЅРѕ РІСЂРµРјСЏ РѕР¶РёРґР°РЅРёСЏ: РїРѕРїСЂРѕР±СѓР№С‚Рµ РµС‰Рµ СЂР°Р·';
        } else if (e.toString().contains('HTTP')) {
          errorMessage = 'РћС€РёР±РєР° СЃРµСЂРІРµСЂР° GBIF: СЃРµСЂРІРёСЃ РІСЂРµРјРµРЅРЅРѕ РЅРµРґРѕСЃС‚СѓРїРµРЅ';
        } else {
          errorMessage = 'РћС€РёР±РєР° РѕР±РЅРѕРІР»РµРЅРёСЏ: ${e.toString().substring(0, 50)}...';
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
              label: 'РџРѕРІС‚РѕСЂРёС‚СЊ',
              textColor: Colors.white,
              onPressed: () => _refreshGbifData(context, plant),
            ),
          ),
        );
      }
    }
  }

  // === РњР•РўРћР”Р« РРќРўР•Р РђРљРўРР’РќРћР™ РљРђР РўР« GBIF ===
  
  // РћСЃРЅРѕРІРЅРѕР№ РІРёРґР¶РµС‚ РєР°СЂС‚С‹ СЃ occurrence С‚РѕС‡РєР°РјРё
  Widget _buildGbifMap(BuildContext context, Plant plant) {
    if (plant.gbifOccurrences.isEmpty) {
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Text('РќРµС‚ С‚РѕС‡РµРє РЅР°Р±Р»СЋРґРµРЅРёСЏ'),
        ),
      );
    }

    // Р’С‹С‡РёСЃР»СЏРµРј С†РµРЅС‚СЂ РєР°СЂС‚С‹ РЅР° РѕСЃРЅРѕРІРµ РІСЃРµС… occurrence С‚РѕС‡РµРє
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
        // OpenStreetMap С‚Р°Р№Р»С‹
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pavel.mycactus',
          maxZoom: 19,
        ),
        // РЎР»РѕР№ СЃ РјР°СЂРєРµСЂР°РјРё occurrence С‚РѕС‡РµРє
        MarkerLayer(
          markers: plant.gbifOccurrences.map((occurrence) {
            return _buildOccurrenceMarker(context, occurrence);
          }).toList(),
        ),
        // РЎР»РѕР№ СЃ РїРѕР»РёРіРѕРЅР°РјРё РґР»СЏ РІРёР·СѓР°Р»РёР·Р°С†РёРё Р°СЂРµР°Р»Р° (РѕРїС†РёРѕРЅР°Р»СЊРЅРѕ)
        if (plant.gbifOccurrences.length > 3)
          PolygonLayer(
            polygons: [_buildOccurrencePolygon(plant.gbifOccurrences)],
          ),
      ],
    );
  }

  // Р Р°СЃС‡РµС‚ С†РµРЅС‚СЂР° РєР°СЂС‚С‹ РЅР° РѕСЃРЅРѕРІРµ occurrence С‚РѕС‡РµРє
  LatLng _calculateMapCenter(List<GbifOccurrence> occurrences) {
    if (occurrences.isEmpty) {
      return const LatLng(0.0, 0.0); // Р¦РµРЅС‚СЂ РјРёСЂР° РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ
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

  // РЎРѕР·РґР°РЅРёРµ РјР°СЂРєРµСЂР° РґР»СЏ occurrence С‚РѕС‡РєРё
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

  // РџРѕСЃС‚СЂРѕРµРЅРёРµ РїРѕР»РёРіРѕРЅР° РґР»СЏ РІРёР·СѓР°Р»РёР·Р°С†РёРё Р°СЂРµР°Р»Р° (РІС‹РїСѓРєР»Р°СЏ РѕР±РѕР»РѕС‡РєР°)
  Polygon _buildOccurrencePolygon(List<GbifOccurrence> occurrences) {
    final validPoints = occurrences
        .where((occ) => occ.hasValidCoordinates)
        .map((occ) => LatLng(occ.latitude, occ.longitude))
        .toList();

    if (validPoints.length < 3) {
      // РЎРѕР·РґР°РµРј РїСЂРѕСЃС‚РѕР№ РїСЂСЏРјРѕСѓРіРѕР»СЊРЅРёРє РґР»СЏ 2 С‚РѕС‡РµРє
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
      // Р”Р»СЏ 1 С‚РѕС‡РєРё СЃРѕР·РґР°РµРј РјР°Р»РµРЅСЊРєРёР№ РєРІР°РґСЂР°С‚
      if (validPoints.length == 1) {
        final lat = validPoints[0].latitude;
        final lng = validPoints[0].longitude;
        final delta = 0.5; // ~50РєРј
        
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

    // Р”Р»СЏ 3+ С‚РѕС‡РµРє СЃРѕР·РґР°РµРј РІС‹РїСѓРєР»СѓСЋ РѕР±РѕР»РѕС‡РєСѓ
    final hullPoints = _calculateConvexHull(validPoints);
    
    return Polygon(
      points: hullPoints,
      color: Colors.green.withValues(alpha: 0.2),
      borderStrokeWidth: 2,
      borderColor: Colors.green.withValues(alpha: 0.6),
    );
  }

  // Р’С‹С‡РёСЃР»РµРЅРёРµ РІС‹РїСѓРєР»РѕР№ РѕР±РѕР»РѕС‡РєРё (Р°Р»РіРѕСЂРёС‚Рј Р“СЂСЌС…РµРјР°)
  List<LatLng> _calculateConvexHull(List<LatLng> points) {
    if (points.length < 3) return points;
    
    // РЎРѕСЂС‚РёСЂРѕРІРєР° РїРѕ x, Р·Р°С‚РµРј РїРѕ y
    final sortedPoints = List<LatLng>.from(points);
    sortedPoints.sort((a, b) {
      if (a.latitude != b.latitude) {
        return a.latitude.compareTo(b.latitude);
      }
      return a.longitude.compareTo(b.longitude);
    });

    // РџРѕСЃС‚СЂРѕРµРЅРёРµ РЅРёР¶РЅРµР№ РѕР±РѕР»РѕС‡РєРё
    final List<LatLng> lower = [];
    for (final point in sortedPoints) {
      while (lower.length >= 2 && _crossProduct(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) {
        lower.removeLast();
      }
      lower.add(point);
    }

    // РџРѕСЃС‚СЂРѕРµРЅРёРµ РІРµСЂС…РЅРµР№ РѕР±РѕР»РѕС‡РєРё
    final List<LatLng> upper = [];
    for (final point in sortedPoints.reversed) {
      while (upper.length >= 2 && _crossProduct(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) {
        upper.removeLast();
      }
      upper.add(point);
    }

    // РћР±СЉРµРґРёРЅРµРЅРёРµ (СѓРґР°Р»РµРЅРёРµ РїРѕСЃР»РµРґРЅРµР№ С‚РѕС‡РєРё РєР°Р¶РґРѕР№, С‚Р°Рє РєР°Рє РѕРЅР° РґСѓР±Р»РёСЂСѓРµС‚СЃСЏ)
    lower.removeLast();
    upper.removeLast();
    
    return [...lower, ...upper];
  }

  // Р’РµРєС‚РѕСЂРЅРѕРµ РїСЂРѕРёР·РІРµРґРµРЅРёРµ РґР»СЏ РѕРїСЂРµРґРµР»РµРЅРёСЏ РїРѕРІРѕСЂРѕС‚Р°
  double _crossProduct(LatLng o, LatLng a, LatLng b) {
    return (a.latitude - o.latitude) * (b.longitude - o.longitude) -
           (a.longitude - o.longitude) * (b.latitude - o.latitude);
  }

  // РџРѕРєР°Р· РґРµС‚Р°Р»РµР№ occurrence С‚РѕС‡РєРё
  void _showOccurrenceDetails(BuildContext context, GbifOccurrence occurrence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('РўРѕС‡РєР° РЅР°Р±Р»СЋРґРµРЅРёСЏ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (occurrence.country.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.flag, size: 16),
                  const SizedBox(width: 4),
                  Text('РЎС‚СЂР°РЅР°: ${occurrence.country}'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (occurrence.locality != null && occurrence.locality!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_city, size: 16),
                  const SizedBox(width: 4),
                  Text('РњРµСЃС‚РЅРѕСЃС‚СЊ: ${occurrence.locality}'),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (occurrence.habitat != null && occurrence.habitat!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.terrain, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text('РђСЂРµР°Р»: ${occurrence.habitat}')),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Text('РљРѕРѕСЂРґРёРЅР°С‚С‹: ${occurrence.latitude.toStringAsFixed(4)}, ${occurrence.longitude.toStringAsFixed(4)}'),
              ],
            ),
            if (occurrence.year != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text('Р“РѕРґ: ${occurrence.year}'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Р—Р°РєСЂС‹С‚СЊ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openInExternalMap(occurrence.latitude, occurrence.longitude);
            },
            child: const Text('РћС‚РєСЂС‹С‚СЊ РІ РєР°СЂС‚Р°С…'),
          ),
        ],
      ),
    );
  }

  // РћС‚РєСЂС‹С‚РёРµ РєРѕРѕСЂРґРёРЅР°С‚ РІРѕ РІРЅРµС€РЅРµРј РїСЂРёР»РѕР¶РµРЅРёРё РєР°СЂС‚
  void _openInExternalMap(double latitude, double longitude) {
    final url = 'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=15/$latitude/$longitude';
    launchUrl(Uri.parse(url));
  }

  // РЎР±СЂРѕСЃ РІРёРґР° РєР°СЂС‚С‹ Рє С†РµРЅС‚СЂСѓ
  void _resetMapView(BuildContext context, Plant plant) {
    if (!mounted) return;
    setState(() {
      // РџРµСЂРµСЃС‚СЂР°РёРІР°РµРј РєР°СЂС‚Сѓ РґР»СЏ РѕР±РЅРѕРІР»РµРЅРёСЏ С†РµРЅС‚СЂР°
      _mapKey = ValueKey(DateTime.now().millisecondsSinceEpoch);
    });
  }

  // РџРѕР»РЅРѕСЌРєСЂР°РЅРЅР°СЏ РєР°СЂС‚Р°
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
                      'РљР°СЂС‚Р° СЂР°СЃРїСЂРѕСЃС‚СЂР°РЅРµРЅРёСЏ: ${plant.latinName}',
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

  
  // Р’СЃРїРѕРјРѕРіР°С‚РµР»СЊРЅС‹Р№ С‡РёРї СЃ РёРєРѕРЅРєРѕР№
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
        title: const Text('РЎРґРµР»Р°С‚СЊ РіР»Р°РІРЅС‹Рј?'),
        content: const Text(
            'Р­С‚Рѕ С„РѕС‚Рѕ Р±СѓРґРµС‚ РѕС‚РѕР±СЂР°Р¶Р°С‚СЊСЃСЏ РІ С€Р°РїРєРµ РєР°СЂС‚РѕС‡РєРё СЂР°СЃС‚РµРЅРёСЏ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('РћС‚РјРµРЅР°'),
          ),
          ElevatedButton(
            onPressed: () {
              final provider =
                  context.read<PlantCrudProvider>();
              final userPhotos = List<String>.from(plant.userPhotos);
              userPhotos.remove(photoUrl);
              userPhotos.insert(0, photoUrl);

              final updatedPlant = plant.copyWith(userPhotos: userPhotos);
              provider.updatePlant(plant.permanentId, updatedPlant);
              provider.savePlants();

              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('РЎРґРµР»Р°С‚СЊ РіР»Р°РІРЅС‹Рј'),
          ),
        ],
      ),
    );
  }

  // РџРѕРєР°Р·С‹РІР°РµРј РјРµРЅСЋ РїСЂРё РґРѕР»РіРѕРј РЅР°Р¶Р°С‚РёРё РЅР° СЃРІРѕС‘ С„РѕС‚Рѕ
  void _showPhotoOptions(BuildContext context, Plant plant, String photoUrl) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('РЎРґРµР»Р°С‚СЊ РіР»Р°РІРЅС‹Рј С„РѕС‚Рѕ'),
            onTap: () {
              Navigator.pop(ctx);
              _setAsMainPhoto(context, plant, photoUrl);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('РЈРґР°Р»РёС‚СЊ С„РѕС‚Рѕ'),
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

  // РџРѕРґС‚РІРµСЂР¶РґРµРЅРёРµ СѓРґР°Р»РµРЅРёСЏ
  void _confirmDeletePhoto(BuildContext context, Plant plant, String photoUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('РЈРґР°Р»РёС‚СЊ С„РѕС‚Рѕ?'),
        content: const Text('Р­С‚Рѕ РґРµР№СЃС‚РІРёРµ РЅРµР»СЊР·СЏ РѕС‚РјРµРЅРёС‚СЊ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('РћС‚РјРµРЅР°'),
          ),
          TextButton(
            onPressed: () {
              final provider =
                  context.read<PlantCrudProvider>();
              
              // РћРїСЂРµРґРµР»СЏРµРј С‚РёРї С„РѕС‚Рѕ Рё РІС‹Р·С‹РІР°РµРј РїСЂР°РІРёР»СЊРЅС‹Р№ РјРµС‚РѕРґ СѓРґР°Р»РµРЅРёСЏ
              final isLliflePhoto = plant.lliflePhotoUrls.contains(photoUrl);
              final isUserPhoto = plant.userPhotos.contains(photoUrl);
              
              if (isLliflePhoto && isUserPhoto) {
                // Р•СЃР»Рё С„РѕС‚Рѕ РІ РѕР±РѕРёС… СЃРїРёСЃРєР°С…, РїСЂРёРѕСЂРёС‚РµС‚ - userPhotos (Р»РѕРєР°Р»СЊРЅС‹Рµ С„Р°Р№Р»С‹)
                provider.removeUserPhoto(plant.permanentId, photoUrl);
              } else if (isLliflePhoto) {
                provider.removeLliflePhoto(plant.permanentId, photoUrl);
              } else if (isUserPhoto) {
                provider.removeUserPhoto(plant.permanentId, photoUrl);
              } else {
                // Р¤РѕС‚Рѕ РЅРµ РЅР°Р№РґРµРЅРѕ - РїРѕРєР°Р·С‹РІР°РµРј РѕС€РёР±РєСѓ
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Р¤РѕС‚Рѕ РЅРµ РЅР°Р№РґРµРЅРѕ РІ РіР°Р»РµСЂРµРµ'),
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
            child: const Text('РЈРґР°Р»РёС‚СЊ'),
          ),
        ],
      ),
    );
  }

  void _showFullPhoto(
      BuildContext context, Plant plant, String photoUrl, bool isNetwork) {
    final isMain =
        plant.userPhotos.isNotEmpty && plant.userPhotos.first == photoUrl;

    // РћРїСЂРµРґРµР»СЏРµРј РґР°С‚Сѓ РґРѕР±Р°РІР»РµРЅРёСЏ
    String dateText = 'Р”Р°С‚Р° РЅРµРёР·РІРµСЃС‚РЅР°';
    if (!isNetwork && photoUrl.isNotEmpty) {
      try {
        final file = File(photoUrl);
        if (file.existsSync()) {
          final lastModified = file.lastModifiedSync();
          dateText =
              'Р”РѕР±Р°РІР»РµРЅРѕ: ${lastModified.day.toString().padLeft(2, '0')}.'
              '${lastModified.month.toString().padLeft(2, '0')}.'
              '${lastModified.year}';
        }
      } catch (_) {
        dateText = 'Р”Р°С‚Р° РЅРµРёР·РІРµСЃС‚РЅР°';
      }
    } else {
      dateText = 'Р¤РѕС‚Рѕ РёР· РѕР±Р»Р°РєР° / Llifle';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Р—СѓРј Рё РїР°РЅРѕСЂР°РјРёСЂРѕРІР°РЅРёРµ РјС‹С€РєРѕР№
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

            // РќР°Р·РІР°РЅРёРµ СЂР°СЃС‚РµРЅРёСЏ Рё ID вЂ” СЃРІРµСЂС…Сѓ РїРѕ С†РµРЅС‚СЂСѓ
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

            // РљРЅРѕРїРєР° Р·Р°РєСЂС‹С‚РёСЏ
            Positioned(
              top: 40,
              right: 40,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

            // РРЅС„РѕСЂРјР°С†РёСЏ СЃРЅРёР·Сѓ
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
                        isMain ? 'Р“Р»Р°РІРЅРѕРµ С„РѕС‚Рѕ' : 'РћР±С‹С‡РЅРѕРµ С„РѕС‚Рѕ',
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
  // === Р РђР‘РћР§РР• Р‘Р«РЎРўР Р«Р• Р”Р•Р™РЎРўР’РРЇ РЎ РћРўРњР•РќРћР™ ===

  void _markWateringToday(Plant plant) {
    if (!mounted) return;
    final provider = context.read<PlantCrudProvider>();
    final wateringDate = DateTime.now();

    provider.addIndividualWateringDate(plant.permanentId, wateringDate);
    provider.savePlants();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Р Р°СЃС‚РµРЅРёРµ ${plant.latinName} РїРѕР»РёС‚Рѕ СЃРµРіРѕРґРЅСЏ'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'РћС‚РјРµРЅРёС‚СЊ',
          textColor: Colors.white,
          onPressed: () {
            provider.removeIndividualWateringDate(
                plant.permanentId, wateringDate);
            provider.savePlants();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('РџРѕР»РёРІ РѕС‚РјРµРЅС‘РЅ'), backgroundColor: Colors.grey),
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

    final oldFertilization = plant.lastFertilization; // РґР»СЏ РІРѕР·РјРѕР¶РЅРѕР№ РѕС‚РјРµРЅС‹

    provider.markAsFertilized(plant.permanentId, date: selectedDate);
    provider.savePlants();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'РЈРґРѕР±СЂРµРЅРёРµ РѕС‚РјРµС‡РµРЅРѕ: ${DateFormat('dd.MM.yyyy').format(selectedDate)}'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'РћС‚РјРµРЅРёС‚СЊ',
          textColor: Colors.white,
          onPressed: () {
            if (oldFertilization != null) {
              provider.markAsFertilized(plant.permanentId,
                  date: oldFertilization);
            } else {
              // Р•СЃР»Рё РЅРµ Р±С‹Р»Рѕ РїСЂРµРґС‹РґСѓС‰РµР№ РґР°С‚С‹ вЂ” РїСЂРѕСЃС‚Рѕ СЃР±СЂР°СЃС‹РІР°РµРј
              final updated = plant.copyWith(
                  lastFertilization: null, plannedFertilizationDate: null);
              provider.updatePlant(plant.permanentId, updated);
            }
            provider.savePlants();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('РЈРґРѕР±СЂРµРЅРёРµ РѕС‚РјРµРЅРµРЅРѕ'),
                  backgroundColor: Colors.grey),
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
            'РџРµСЂРµСЃР°РґРєР° Р·Р°РїР»Р°РЅРёСЂРѕРІР°РЅР° РЅР° ${DateFormat('dd.MM.yyyy').format(selectedDate)}'),
        backgroundColor: Colors.brown,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'РћС‚РјРµРЅРёС‚СЊ',
          textColor: Colors.white,
          onPressed: () {
            final revertPlant =
                plant.copyWith(plannedTransplantDate: oldPlanned);
            provider.updatePlant(plant.permanentId, revertPlant);
            provider.savePlants();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('РџР»Р°РЅРёСЂРѕРІР°РЅРёРµ РїРµСЂРµСЃР°РґРєРё РѕС‚РјРµРЅРµРЅРѕ'),
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
        title: const Text('РћС‚РјРµС‚РёС‚СЊ С†РІРµС‚РµРЅРёРµ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.local_florist),
              label: const Text('Р Р°СЃС†РІРµР»Рѕ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, 'bloomed'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.wb_sunny),
              label: const Text('Р—Р°РІСЏР»Рѕ'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, 'wilted'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('РћС‚РјРµРЅР°')),
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
            event == 'bloomed' ? 'РћС‚РјРµС‡РµРЅРѕ С†РІРµС‚РµРЅРёРµ' : 'РћС‚РјРµС‡РµРЅРѕ СѓРІСЏРґР°РЅРёРµ'),
        backgroundColor: event == 'bloomed' ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'РћС‚РјРµРЅРёС‚СЊ',
          textColor: Colors.white,
          onPressed: () {
            // РЈРґР°Р»СЏРµРј РїРѕСЃР»РµРґРЅСЋСЋ Р·Р°РїРёСЃСЊ С†РІРµС‚РµРЅРёСЏ (РїСЂРѕСЃС‚РѕР№ СЃРїРѕСЃРѕР± РѕС‚РјРµРЅС‹)
            final updatedHistory =
                List<FloweringRecord>.from(plant.floweringHistory)
                  ..removeLast(); // СѓРґР°Р»СЏРµРј РїРѕСЃР»РµРґРЅСЋСЋ РґРѕР±Р°РІР»РµРЅРЅСѓСЋ
            final updatedPlant =
                plant.copyWith(floweringHistory: updatedHistory);
            provider.updatePlant(plant.permanentId, updatedPlant);
            provider.savePlants();
            setState(() {});

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Р—Р°РїРёСЃСЊ С†РІРµС‚РµРЅРёСЏ РѕС‚РјРµРЅРµРЅР°'),
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
    final habitatText = plant.habitat ?? 'РќРµ СѓРєР°Р·Р°РЅРѕ';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.map, color: Colors.green),
        title: const Text(
          'Р•СЃС‚РµСЃС‚РІРµРЅРЅС‹Р№ Р°СЂРµР°Р»',
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
              context.read<PlantCrudProvider>()
                  .updatePlant(plant.permanentId, result);
              context.read<PlantCrudProvider>().savePlants();
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
        const SnackBar(content: Text('РќРµ СѓРґР°Р»РѕСЃСЊ РЅР°Р№С‚Рё С„РѕС‚Рѕ РЅР° Llifle')),
      );
      return;
    }

    List<String> adultPhotoUrls =
        List<String>.from(plantData['photoUrls'] ?? []);

    // === РЈР›РЈР§РЁР•РќРќРђРЇ: Р¤РёР»СЊС‚СЂР°С†РёСЏ Рё РѕС‡РёСЃС‚РєР° СЃСЃС‹Р»РѕРє ===
    adultPhotoUrls = adultPhotoUrls
        .where((url) => url.isNotEmpty && url.contains('llifle.com'))
        .map((url) {
          var cleanUrl = url
              .replaceAll(
                  'https://llifle.comphotos/', 'https://llifle.com/photos/')
              .replaceAll('+', '_')
              .replaceAll('_m.jpg', '_l.jpg')
              .replaceAll('_s.jpg', '_l.jpg'); // Р”РѕР±Р°РІР»СЏРµРј Р·Р°РјРµРЅСѓ РјР°Р»РµРЅСЊРєРёС… С„РѕС‚Рѕ
          return Uri.encodeFull(cleanUrl);
        })
        .where((url) {
          // Р”РѕРїРѕР»РЅРёС‚РµР»СЊРЅР°СЏ РІР°Р»РёРґР°С†РёСЏ URL
          try {
            final uri = Uri.parse(url);
            return uri.hasScheme && uri.hasAuthority && 
                   url.contains('llifle.com/photos/') && 
                   url.endsWith('.jpg');
          } catch (e) {
            return false;
          }
        })
        .toSet() // РЈР±РёСЂР°РµРј РґСѓР±Р»РёРєР°С‚С‹
        .toList();

    if (adultPhotoUrls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Р¤РѕС‚Рѕ РЅРµ РЅР°Р№РґРµРЅС‹')),
        );
      }
      return;
    }

    // РџРѕРєР°Р·С‹РІР°РµРј РґРёР°Р»РѕРі СЃ РѕС‚С„РёР»СЊС‚СЂРѕРІР°РЅРЅС‹РјРё С„РѕС‚Рѕ
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
                const SnackBar(content: Text('Р¤РѕС‚Рѕ СЃ Llifle РґРѕР±Р°РІР»РµРЅРѕ')),
              );
            }
          },
        ),
      );
    }
  }

  Widget _buildDescriptionSection(BuildContext context, Plant plant) {
    final descriptionText = plant.description ?? 'Р”РѕР±Р°РІСЊС‚Рµ РѕРїРёСЃР°РЅРёРµ...';
    final descriptionList = descriptionText.split('\n');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.description, color: Colors.green),
        title: const Text(
          'РћРїРёСЃР°РЅРёРµ',
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
              context.read<PlantCrudProvider>()
                  .updatePlant(plant.permanentId, result);
              context.read<PlantCrudProvider>().savePlants();
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
    final synonymsText = plant.synonyms ?? 'РЎРёРЅРѕРЅРёРјС‹ РЅРµ СѓРєР°Р·Р°РЅС‹';
    final synonymsList = synonymsText.split('\n');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.bookmark, color: Colors.green),
        title: const Text(
          'РЎРёРЅРѕРЅРёРјС‹',
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
    final careTipsText = plant.careTips ?? 'РћСЃРѕР±РµРЅРЅРѕСЃС‚Рё СѓС…РѕРґР° РЅРµ СѓРєР°Р·Р°РЅС‹';
    final careTipsList = careTipsText.split('\n');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: const Icon(Icons.lightbulb, color: Colors.green),
        title: const Text(
          'РћСЃРѕР±РµРЅРЅРѕСЃС‚Рё СѓС…РѕРґР°',
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
              context.read<PlantCrudProvider>()
                  .updatePlant(plant.permanentId, result);
              context.read<PlantCrudProvider>().savePlants();
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
    bool isActive = true, // РќРѕРІРѕРµ: РјРѕР¶РЅРѕ Р»Рё РЅР°Р¶Р°С‚СЊ
    String? activeTitle, // РќРѕРІРѕРµ: Р°Р»СЊС‚РµСЂРЅР°С‚РёРІРЅС‹Р№ С‚РµРєСЃС‚ РїРѕСЃР»Рµ РґРµР№СЃС‚РІРёСЏ
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
        setState(() {}); // РїСЂРѕСЃС‚Рѕ РѕР±РЅРѕРІР»СЏРµРј СЌРєСЂР°РЅ
      }
    } catch (e) {
      print('РћС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё С„РѕС‚Рѕ: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('РћС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё: $e')),
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

  // РћР±РЅРѕРІР»РµРЅРёРµ С„РѕС‚Рѕ СЃ Llifle - С‚РµРїРµСЂСЊ РІС‹Р·С‹РІР°РµС‚ РІС‹Р±РѕСЂ С„РѕС‚Рѕ
  Future<void> _refreshLliflePhotos(BuildContext context, Plant plant) async {
    await _selectAdultImage(plant);
  }

  // === Р’РљР›РђР”РљРђ РЎР•РЇРќР¦Р« (РґР»СЏ РІРёС‚СЂРёРЅ-РїР°СЂС‚РёР№) ===
  Widget _buildSeedlingsTab(BuildContext context, Plant batch) {
    return Consumer<PlantCrudProvider>(
      builder: (context, provider, child) {
        final seedlings = provider.getBatchSeedlings(batch.permanentId);

        if (seedlings.isEmpty) {
          return const Center(
            child: Text(
              'РќРµС‚ СЃРµСЏРЅС†РµРІ РІ СЌС‚РѕР№ РїР°СЂС‚РёРё',
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
                title: Text('${seedling.displayId} вЂ” ${seedling.latinName}'),
                subtitle: Text('РЎС‚Р°С‚СѓСЃ: ${seedling.statusText}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // РљРЅРѕРїРєР° СЃРјРµРЅС‹ СЃС‚Р°С‚СѓСЃР°
                    _buildStatusButton(context, provider, seedling),
                    // РљРЅРѕРїРєР° СѓРґР°Р»РµРЅРёСЏ
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('РЈРґР°Р»РёС‚СЊ СЃРµСЏРЅРµС†?'),
                            content: Text('РЈРґР°Р»РёС‚СЊ ${seedling.displayId}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('РћС‚РјРµРЅР°'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('РЈРґР°Р»РёС‚СЊ',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await provider.removeSeedlingFromBatch(
                            batch.permanentId,
                            seedling.permanentId,
                          );
                        }
                      },
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  // РћС‚РєСЂС‹РІР°РµРј РєР°СЂС‚РѕС‡РєСѓ СЃРµСЏРЅС†Р°
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

  // РџРѕСЃС‚СЂРѕРµРЅРёРµ РјРёРЅРёР°С‚СЋСЂС‹ С„РѕС‚Рѕ СЃРµСЏРЅС†Р° (СЃ РїСЂРѕРІРµСЂРєРѕР№ http vs file)
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

  // РљРЅРѕРїРєР° СЃРјРµРЅС‹ СЃС‚Р°С‚СѓСЃР° СЃРµСЏРЅС†Р°
  Widget _buildStatusButton(BuildContext context, PlantCrudProvider provider, Plant seedling) {
    // РћРїСЂРµРґРµР»СЏРµРј С†РІРµС‚ РїРѕ СЃС‚Р°С‚СѓСЃСѓ
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
      tooltip: 'РР·РјРµРЅРёС‚СЊ СЃС‚Р°С‚СѓСЃ',
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
        // РћР±РЅРѕРІР»СЏРµРј СЃС‚Р°С‚СѓСЃ СЃРµСЏРЅС†Р°
        final updatedSeedling = seedling.copyWith(status: newStatus);
        provider.updatePlant(seedling.permanentId, updatedSeedling);

        // РџРѕРєР°Р·С‹РІР°РµРј СѓРІРµРґРѕРјР»РµРЅРёРµ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('РЎС‚Р°С‚СѓСЃ ${seedling.displayId} РёР·РјРµРЅС‘РЅ РЅР°: ${_getStatusText(newStatus)}'),
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
              Text('Р Р°СЃС‚С‘С‚'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'in_collection',
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text('Р’ РєРѕР»Р»РµРєС†РёРё'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'dead',
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text('РџРѕРіРёР±'),
            ],
          ),
        ),
      ],
    );
  }

  // Р’СЃРїРѕРјРѕРіР°С‚РµР»СЊРЅС‹Р№ РјРµС‚РѕРґ РґР»СЏ РїРѕР»СѓС‡РµРЅРёСЏ С‚РµРєСЃС‚Р° СЃС‚Р°С‚СѓСЃР°
  String _getStatusText(String status) {
    switch (status) {
      case 'growing':
        return 'Р Р°СЃС‚С‘С‚';
      case 'in_collection':
        return 'Р’ РєРѕР»Р»РµРєС†РёРё';
      case 'dead':
        return 'РџРѕРіРёР±';
      default:
        return status;
    }
  }

  // === РњР•РўРћР”Р« Р”Р›РЇ QR РљРћР”РћР’ ===

  /// РџРѕРєР°Р·С‹РІР°РµС‚ РґРёР°Р»РѕРі СЃРѕР·РґР°РЅРёСЏ QR РєРѕРґР°
  void _showCreateQRCodeDialog(BuildContext context, Plant plant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('РЎРѕР·РґР°С‚СЊ QR РєРѕРґ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'РЎРѕР·РґР°С‚СЊ QR РєРѕРґ РґР»СЏ СЂР°СЃС‚РµРЅРёСЏ:',
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
              'QR РєРѕРґ Р±СѓРґРµС‚ СЃРѕРґРµСЂР¶Р°С‚СЊ ID Рё РЅР°Р·РІР°РЅРёРµ СЂР°СЃС‚РµРЅРёСЏ. Р’С‹ СЃРјРѕР¶РµС‚Рµ СЂР°СЃРїРµС‡Р°С‚Р°С‚СЊ РµРіРѕ РЅР° СЌС‚РёРєРµС‚РєРµ.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('РћС‚РјРµРЅР°'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final provider = context.read<PlantCrudProvider>();
              provider.createQRCode(plant.permanentId);
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('QR РєРѕРґ РґР»СЏ ${plant.latinName} СЃРѕР·РґР°РЅ'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.qr_code),
            label: const Text('РЎРѕР·РґР°С‚СЊ'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  /// РџРѕРєР°Р·С‹РІР°РµС‚ РґРёР°Р»РѕРі СЃ QR РєРѕРґРѕРј
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
              // TODO(окружение): QRCodeWidget отсутствует в Windows
              // QRCodeWidget(
              //   plant: plant,
              //   size: 250,
              //   showName: false,
              // ),
              const SizedBox(height: 16),
              const Text(
                'РћС‚СЃРєР°РЅРёСЂСѓР№С‚Рµ РґР»СЏ Р±С‹СЃС‚СЂРѕРіРѕ РїРѕРёСЃРєР° СЂР°СЃС‚РµРЅРёСЏ',
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
                    label: const Text('РџРµС‡Р°С‚СЊ'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    label: const Text('Р—Р°РєСЂС‹С‚СЊ'),
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


