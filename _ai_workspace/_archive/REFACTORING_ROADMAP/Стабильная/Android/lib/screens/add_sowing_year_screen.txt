import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/plant.dart';
import '../providers/plant_provider.dart';

class AddSowingYearScreen extends StatefulWidget {
  const AddSowingYearScreen({super.key});

  @override
  AddSowingYearScreenState createState() => AddSowingYearScreenState();
}

class AddSowingYearScreenState extends State<AddSowingYearScreen> {
  final List<Plant> _plants = [];
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Предотвращаем автоматический выход
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          _savePlants(); // Сохраняем растения
          if (mounted) {
            // Проверяем, что виджет всё ещё активен
            Navigator.pop(context); // Закрываем экран
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Добавить посев'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _savePlants();
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _savePlants,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildYearSelector(),
            Expanded(
              child: ListView.builder(
                itemCount: _plants.length,
                itemBuilder: (ctx, index) => _buildPlantRow(index),
              ),
            ),
            _buildAddRowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButton<int>(
        hint: const Text('Выберите год'),
        value: _selectedYear,
        items: List.generate(50, (i) => DateTime.now().year - i)
            .map((year) => DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                ))
            .toList(),
        onChanged: (value) => setState(() => _selectedYear = value),
      ),
    );
  }

  Widget _buildPlantRow(int index) {
    final plant = _plants[index];

    final latinNameController = TextEditingController(text: plant.latinName);
    final seedsController =
        TextEditingController(text: plant.seedsCount.toString());
    final germinatedController =
        TextEditingController(text: plant.germinatedCount.toString());
    final fieldNumberController =
        TextEditingController(text: plant.fieldNumber ?? '');
    final sellerController = TextEditingController(text: plant.seller ?? '');
    final harvestYearController =
        TextEditingController(text: plant.harvestYear?.toString() ?? '');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: latinNameController,
                    decoration:
                        const InputDecoration(labelText: 'Латинское название'),
                    onChanged: (value) {
                      final updatedPlant =
                          plant.copyWith(latinName: value.trim());
                      final idx = _plants.indexOf(plant);
                      if (idx != -1) _plants[idx] = updatedPlant;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: seedsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Семян'),
                    onChanged: (value) {
                      final cnt = int.tryParse(value) ?? 0;
                      final updatedPlant = plant.copyWith(seedsCount: cnt);
                      final idx = _plants.indexOf(plant);
                      if (idx != -1) _plants[idx] = updatedPlant;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: germinatedController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Взошло'),
                    onChanged: (value) {
                      final cnt = int.tryParse(value) ?? 0;
                      final updatedPlant = plant.copyWith(
                        germinatedCount: cnt,
                        germinationHistory: [
                          ...plant.germinationHistory,
                          GerminationRecord(
                              date: DateTime.now(), germinatedCount: cnt),
                        ],
                      );
                      final idx = _plants.indexOf(plant);
                      if (idx != -1) _plants[idx] = updatedPlant;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: fieldNumberController,
                    decoration:
                        const InputDecoration(labelText: 'Полевой номер'),
                    onChanged: (value) {
                      final updatedPlant = plant.copyWith(
                          fieldNumber:
                              value.trim().isEmpty ? null : value.trim());
                      final idx = _plants.indexOf(plant);
                      if (idx != -1) _plants[idx] = updatedPlant;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: sellerController,
                    decoration:
                        const InputDecoration(labelText: 'Продавец / источник'),
                    onChanged: (value) {
                      final updatedPlant = plant.copyWith(
                          seller: value.trim().isEmpty ? null : value.trim());
                      final idx = _plants.indexOf(plant);
                      if (idx != -1) _plants[idx] = updatedPlant;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: TextFormField(
                controller: harvestYearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Год сбора'),
                onChanged: (value) {
                  final year = int.tryParse(value);
                  final updatedPlant = plant.copyWith(harvestYear: year);
                  final idx = _plants.indexOf(plant);
                  if (idx != -1) _plants[idx] = updatedPlant;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRowButton() {
    return ElevatedButton(
      onPressed: () {
        if (_selectedYear == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Выберите год перед добавлением!')),
          );
          return;
        }
        final provider = Provider.of<PlantProvider>(context, listen: false);
        final existingNumbers = provider.plants
            .where((p) => p.year == _selectedYear && p.category == 'sown')
            .map((p) => p.customNumber)
            .toList();

        final nextNumber = existingNumbers.isEmpty
            ? 1
            : existingNumbers.reduce((a, b) => a > b ? a : b) + 1;

        setState(() {
          _plants.add(Plant(
            latinName: '',
            status: 'sown',
            year: _selectedYear!,
            customNumber: nextNumber,
            category: 'sown',
            seedsCount: 0,
            germinatedCount: 0,
          ));
        });
      },
      child: const Text('Добавить строку'),
    );
  }

  void _savePlants() {
    if (_selectedYear == null) return;

    // Проверка на пустые названия
    for (final plant in _plants) {
      if (plant.latinName.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Название не может быть пустым!')),
        );
        return;
      }
    }
    final provider = Provider.of<PlantProvider>(context, listen: false);
    for (final plant in _plants) {
      final existingIndex =
          provider.plants.indexWhere((p) => p.permanentId == plant.permanentId);

      if (existingIndex != -1) {
        provider.updatePlant(plant.permanentId, plant);
      } else {
        provider.addPlant(plant);
      }
    }
    provider.savePlants(); // Принудительное сохранение
    if (mounted) {
      // Добавляем проверку перед закрытием
      Navigator.pop(context);
    }
  }
}
