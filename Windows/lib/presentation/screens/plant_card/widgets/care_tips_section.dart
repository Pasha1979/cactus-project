import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/plant.dart';
import 'package:provider/provider.dart';
import '../../../../presentation/providers/providers.dart';

class CareTipsSection extends StatelessWidget {
  final Plant plant;

  const CareTipsSection({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
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
            final result = await context.push<Plant>(
              '/plant/${plant.permanentId}/edit',
              extra: plant,
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
                            ),)
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
