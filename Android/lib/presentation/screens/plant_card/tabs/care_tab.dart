import 'package:flutter/material.dart';
import '../../../../models/plant.dart';
import '../widgets/care_tips_section.dart';
import '../widgets/action_card.dart';

class CareTab extends StatelessWidget {
  final Plant plant;
  final Future<String>? weatherFuture;
  final VoidCallback onWatering;
  final VoidCallback onFertilization;
  final VoidCallback onRepotting;
  final VoidCallback onFlowering;

  const CareTab({
    super.key,
    required this.plant,
    this.weatherFuture,
    required this.onWatering,
    required this.onFertilization,
    required this.onRepotting,
    required this.onFlowering,
  });

  @override
  Widget build(BuildContext context) {
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
            future: weatherFuture,
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
                    borderRadius: BorderRadius.circular(16),),
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
                              style: TextStyle(fontWeight: FontWeight.bold),),
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
          CareTipsSection(plant: plant),
          const SizedBox(height: 32),

          // 3. Быстрые действия
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
              ActionCard(
                icon: Icons.water_drop,
                title: 'Полить сегодня',
                color: Colors.blue,
                onTap: onWatering,
              ),
              ActionCard(
                icon: Icons.science,
                title: 'Удобрить',
                color: Colors.purple,
                onTap: onFertilization,
              ),
              ActionCard(
                icon: Icons.yard,
                title: 'Пересадить',
                color: Colors.brown,
                onTap: onRepotting,
              ),
              ActionCard(
                icon: Icons.local_florist,
                title: 'Отметить цветение',
                color: Colors.pink,
                onTap: onFlowering,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
