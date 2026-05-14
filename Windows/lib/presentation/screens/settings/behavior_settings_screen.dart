import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../presentation/providers/settings_provider.dart';

/// Экран настроек поведения приложения.
///
/// Позволяет настроить автосохранение, подтверждения и анимации.
class BehaviorSettingsScreen extends StatelessWidget {
  const BehaviorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поведение приложения'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Автоматизация',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Автосохранение
          SwitchListTile(
            title: const Text('Автосохранение изменений'),
            subtitle: const Text(
              'Автоматически сохранять изменения при редактировании растений',
            ),
            value: settingsProvider.autoSaveEnabled,
            onChanged: (value) => settingsProvider.setAutoSaveEnabled(value),
          ),

          const Divider(),

          Text(
            'Безопасность',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Подтверждение перед удалением
          SwitchListTile(
            title: const Text('Подтверждать удаление'),
            subtitle: const Text(
              'Показывать диалог подтверждения перед удалением растений',
            ),
            value: settingsProvider.confirmBeforeDelete,
            onChanged: (value) => settingsProvider.setConfirmBeforeDelete(value),
          ),

          const Divider(),

          Text(
            'Интерфейс',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Анимации
          SwitchListTile(
            title: const Text('Анимации интерфейса'),
            subtitle: const Text(
              'Включить анимации переходов и взаимодействий',
            ),
            value: settingsProvider.animationsEnabled,
            onChanged: (value) => settingsProvider.setAnimationsEnabled(value),
          ),

          const SizedBox(height: 32),

          // Информация
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.teal[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Рекомендации',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Автосохранение удобно, но можно отключить если хотите контролировать когда сохранять\n'
                  '• Подтверждение удаления защищает от случайных действий\n'
                  '• Отключение анимаций может улучшить производительность на старых устройствах',
                  style: TextStyle(
                    color: Colors.teal[800],
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
}
