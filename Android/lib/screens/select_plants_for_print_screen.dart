import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/plant.dart';
import '../presentation/providers/providers.dart';

/// Экран выбора растений для печати QR-этикеток
class SelectPlantsForPrintScreen extends StatefulWidget {
  const SelectPlantsForPrintScreen({super.key});

  @override
  State<SelectPlantsForPrintScreen> createState() => _SelectPlantsForPrintScreenState();
}

class _SelectPlantsForPrintScreenState extends State<SelectPlantsForPrintScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedPlantIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Plant> get _filteredPlants {
    final provider = context.read<PlantCrudProvider>();
    final plants = provider.plants;
    
    if (_searchQuery.isEmpty) {
      return plants;
    }
    
    return plants.where((plant) {
      final latinName = plant.latinName.toLowerCase();
      final displayId = plant.displayId.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return latinName.contains(query) || displayId.contains(query);
    }).toList();
  }

  void _selectAllWithQR() {
    final provider = context.read<PlantCrudProvider>();
    final plantsWithQR = provider.plants
        .where((p) => p.qrCode != null)
        .map((p) => p.permanentId)
        .toSet();
    
    setState(() {
      _selectedPlantIds.clear();
      _selectedPlantIds.addAll(plantsWithQR);
    });
  }

  void _toggleSelection(String plantId) {
    setState(() {
      if (_selectedPlantIds.contains(plantId)) {
        _selectedPlantIds.remove(plantId);
      } else {
        _selectedPlantIds.add(plantId);
      }
    });
  }

  void _continueToPrintSettings() {
    if (_selectedPlantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одно растение')),
      );
      return;
    }

    final provider = context.read<PlantCrudProvider>();
    final selectedPlants = provider.plants
        .where((p) => _selectedPlantIds.contains(p.permanentId))
        .toList();

    context.push(
      '/print/settings',
      extra: selectedPlants,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlants = _filteredPlants;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбрать растения для печати'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            tooltip: 'Выбрать все с QR кодами',
            onPressed: _selectAllWithQR,
          ),
        ],
      ),
      body: Column(
        children: [
          // Строка поиска
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск растений...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Список растений
          Expanded(
            child: filteredPlants.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Нет растений'
                          : 'Ничего не найдено',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredPlants.length,
                    itemBuilder: (context, index) {
                      final plant = filteredPlants[index];
                      final isSelected = _selectedPlantIds.contains(plant.permanentId);
                      final hasQR = plant.qrCode != null;

                      // Собираем все фото из разных источников
                      final allPhotos = [
                        ...plant.userPhotos,
                        ...plant.lliflePhotoUrls,
                        ...plant.gbifPhotoUrls,
                      ];

                      return RepaintBoundary(
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(plant.permanentId),
                          title: Text(plant.latinName),
                          subtitle: Text('${plant.displayId} ${hasQR ? "✓ QR" : ""}'),
                          secondary: CircleAvatar(
                            backgroundImage: allPhotos.isNotEmpty
                                ? NetworkImage(allPhotos.first)
                                : null,
                            child: allPhotos.isEmpty
                                ? const Icon(Icons.local_florist)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Кнопка продолжить
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedPlantIds.isEmpty ? null : _continueToPrintSettings,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text('Продолжить (${_selectedPlantIds.length})'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
