import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/plant.dart';
import 'package:provider/provider.dart';
import '../../../../presentation/providers/providers.dart';

class GeographySection extends StatelessWidget {
  final Plant plant;

  const GeographySection({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    final habitatText = plant.habitat ?? 'Не указано';
    final country = plant.country;
    final countryFlag = plant.countryFlag;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Страна происхождения с флагом
                if (country != null && country.isNotEmpty) ...[
                  Row(
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
                                if (countryFlag != null)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Image.network(
                                      countryFlag,
                                      width: 24,
                                      height: 16,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.flag, size: 20),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    country,
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
                  const SizedBox(height: 16),
                ],
                // Ареал обитания
                Row(
                  children: [
                    Icon(Icons.terrain, color: Colors.green.shade600, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ареал обитания',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            habitatText,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
