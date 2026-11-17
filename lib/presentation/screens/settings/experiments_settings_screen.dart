import 'package:flutter/material.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/logger/app_logger.dart';

/// Экран экспериментальных функций (Feature Flags).
///
/// Позволяет включать бета-функции для тестирования.
class ExperimentsSettingsScreen extends StatelessWidget {
  const ExperimentsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Экспериментальные функции'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Предупреждение
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Эти функции находятся в разработке. Они могут работать нестабильно.',
                    style: TextStyle(
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // GBIF парсинг
          _buildExperimentTile(
            context,
            title: 'Парсинг GBIF',
            subtitle: 'Автоматическое получение данных о видах из GBIF базы',
            icon: Icons.public,
            featureFlag: FeatureFlag.enableGbifParsing,
          ),

          const SizedBox(height: 32),

          // Информация
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.indigo[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Что такое Feature Flags?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Это возможность включать новые функции до их официального релиза. '
                  'Вы можете протестировать их и дать обратную связь. '
                  'Функции управляются как локально (через этот экран), так и удалённо '
                  '(через Firebase Console для постепенного rollout).',
                  style: TextStyle(
                    color: Colors.indigo[800],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperimentTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required FeatureFlag featureFlag,
  }) {
    final isEnabled = FeatureFlags.isEnabled(featureFlag);
    
    return StatefulBuilder(
      builder: (context, setState) {

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.indigo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                      Switch(
                        value: isEnabled,
                        onChanged: (value) {
                          FeatureFlags.setLocalOverride(featureFlag, value);
                          AppLogger.api(
                            'Feature ${featureFlag.name} ${value ? 'enabled' : 'disabled'} by user',
                            tag: 'FEATURE_FLAGS',
                          );
                          setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (isEnabled) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'АКТИВНО',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
