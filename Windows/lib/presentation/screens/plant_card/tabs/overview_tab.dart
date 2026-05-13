import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/plant.dart';
import '../../../../presentation/providers/providers.dart';
import '../widgets/geography_section.dart';
import '../widgets/description_section.dart';
import '../widgets/synonyms_section.dart';

class OverviewTab extends StatelessWidget {
  final Plant plant;

  const OverviewTab({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GeographySection(plant: plant),
          const SizedBox(height: 16),
          DescriptionSection(plant: plant),
          const SizedBox(height: 16),
          SynonymsSection(plant: plant),

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
                              style: TextStyle(color: Colors.green),),
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
                label: Text('Преобразовать в партию (${plant.getCurrentAliveCount} шт.)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),),
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
}
