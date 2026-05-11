import 'package:flutter/material.dart';
import '../../../../models/plant.dart';
import '../../../../screens/edit_plant_screen.dart';
import 'package:provider/provider.dart';
import '../../../../presentation/providers/providers.dart';

class DescriptionSection extends StatelessWidget {
  final Plant plant;

  const DescriptionSection({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
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
}
