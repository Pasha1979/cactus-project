import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';
import '../models/plant.dart';
import 'print_settings_screen.dart';

/// Экран массового создания QR-кодов для выбранных растений
class BatchQRCreationScreen extends StatefulWidget {
  const BatchQRCreationScreen({super.key});

  @override
  State<BatchQRCreationScreen> createState() => _BatchQRCreationScreenState();
}

class _BatchQRCreationScreenState extends State<BatchQRCreationScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantProvider>();
    final selectedIds = provider.selectedIds;
    final selectedPlants = provider.plants
        .where((p) => selectedIds.contains(p.permanentId))
        .toList();
    final plantsWithoutQR = selectedPlants
        .where((p) => p.qrCode == null || !p.qrCode!.isActive)
        .toList();
    final plantsWithQR = selectedPlants
        .where((p) => p.qrCode != null && p.qrCode!.isActive)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Массовое создание QR-кодов'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(selectedPlants.length, plantsWithoutQR.length, plantsWithQR.length),
            const SizedBox(height: 16),
            if (plantsWithoutQR.isNotEmpty) ...[
              Text(
                'Будут созданы QR-коды (${plantsWithoutQR.length}):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: plantsWithoutQR.length,
                  itemBuilder: (context, index) {
                    final plant = plantsWithoutQR[index];
                    return ListTile(
                      leading: const Icon(Icons.qr_code, color: Colors.orange),
                      title: Text(plant.latinName),
                      subtitle: Text(plant.displayId),
                    );
                  },
                ),
              ),
            ] else if (selectedPlants.isNotEmpty) ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Все выбранные растения уже имеют QR-коды',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Не выбрано ни одного растения',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Вернитесь к списку и выберите растения чекбоксами',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: plantsWithoutQR.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _createQRCodesAndPrint(plantsWithoutQR),
                  icon: const Icon(Icons.qr_code),
                  label: Text('Создать QR-коды и перейти к печати (${plantsWithoutQR.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSummaryCard(int total, int withoutQR, int withQR) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatColumn('Выбрано', total.toString(), Icons.check_box),
            ),
            const VerticalDivider(),
            Expanded(
              child: _buildStatColumn('Без QR', withoutQR.toString(), Icons.qr_code, Colors.orange),
            ),
            const VerticalDivider(),
            Expanded(
              child: _buildStatColumn('С QR', withQR.toString(), Icons.qr_code, Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _createQRCodesAndPrint(List<Plant> plants) {
    final provider = context.read<PlantProvider>();
    final ids = plants.map((p) => p.permanentId).toSet();
    provider.createQRCodeBatch(ids);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Создано QR-кодов: ${plants.length}'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) => PrintSettingsScreen(
          plantsToPrint: plants.toList(),
        ),
      ),
    );
  }
}
