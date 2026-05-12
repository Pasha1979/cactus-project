import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'wintering_screen.dart';
import 'care_calendar_screen.dart'; // ←←← ДОБАВИТЬ ЭТУ СТРОКУ
import '../providers/plant_provider.dart';
import '../utils/responsive_helper.dart';

class CollectionManagementScreen extends StatelessWidget {
  const CollectionManagementScreen({super.key});

  // === INSERT THIS CODE INSTEAD (полная замена build()) ===

  @override
  Widget build(BuildContext context) {
    final plantProvider = context.watch<PlantProvider>();
    final plants = plantProvider.plants
        .where((p) => p.status != 'dead' && p.status != 'failed')
        .toList();

    final overdueCount = plants.where((p) {
      final nextDate =
          p.plannedTransplantDate ?? p.getRecommendedTransplantDate();
      return nextDate != null && nextDate.isBefore(DateTime.now());
    }).length;

    final totalPlants = plants.length;
    final needsWatering = 0; // Можно потом посчитать через провайдер
    final winteringStatus = plantProvider.winteringStartDate != null &&
            plantProvider.winteringEndDate != null
        ? "Активна"
        : "Не настроена";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление коллекцией'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            plantProvider.clearNotifications();
            Navigator.pop(context);
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final cardWidth = isWide ? 280.0 : constraints.maxWidth * 0.45;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === Сводка по коллекции ===
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSummaryCard(
                            context,
                            'Всего растений',
                            totalPlants.toString(),
                            Icons.eco,
                            Colors.green,
                          ),
                          _buildSummaryCard(
                            context,
                            'Нужно полить',
                            needsWatering.toString(),
                            Icons.water_drop,
                            Colors.blue,
                          ),
                          _buildSummaryCard(
                            context,
                            'Просрочена пересадка',
                            overdueCount.toString(),
                            Icons.warning_amber,
                            Colors.red,
                          ),
                          _buildSummaryCard(
                            context,
                            'Зимовка',
                            winteringStatus,
                            Icons.ac_unit,
                            Colors.cyan,
                          ),
                        ],
                      ),
                    ),

                    // === Основные большие карточки ===
                    Expanded(
                      child: GridView(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Responsive.isMobile(context) ? 1 : 2,
                          childAspectRatio:
                              Responsive.isMobile(context) ? 2.0 : 1.8,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                        ),
                        children: [
                          // Календарь ухода — главная карточка
                          _buildBigSectionCard(
                            context,
                            title: 'Календарь ухода',
                            subtitle: 'Полив, пересадка, подкормка',
                            icon: Icons.calendar_today,
                            color: Colors.blue,
                            cardWidth: cardWidth,
                            hasNotification:
                                plantProvider.hasUnreadNotifications ||
                                    overdueCount > 0,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const CareCalendarScreen(),
                              ),
                            ),
                          ),

                          // Зимовка
                          _buildBigSectionCard(
                            context,
                            title: 'Зимовка',
                            subtitle: 'Температура и журнал',
                            icon: Icons.ac_unit,
                            color: Colors.cyan,
                            cardWidth: cardWidth,
                            hasNotification: false,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => const WinteringScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Восстановить бэкап (маленькая карточка внизу)
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context,
                      title: 'Восстановить бэкап',
                      icon: Icons.restore,
                      color: Colors.purple,
                      cardWidth: cardWidth,
                      hasNotification: false,
                      onTap: () async {
                        final provider = context.read<PlantProvider>();
                        final success = await provider.restoreFromLocalBackup();
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  '✅ Данные успешно восстановлены из локального бэкапа!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Бэкап не найден или произошла ошибка'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required double cardWidth,
    required bool hasNotification,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasNotification
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, // ← Добавили BuildContext как параметр
      String title,
      String value,
      IconData icon,
      Color color) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: isMobile ? 140 : 180,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isMobile ? 28 : 32),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: color.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double cardWidth,
    required bool hasNotification,
    required VoidCallback onTap,
  }) {
    final isMobile = Responsive.isMobile(context);

    return Card(
      elevation: isMobile ? 4 : 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isMobile ? 40 : 48,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasNotification)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Есть задачи',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
