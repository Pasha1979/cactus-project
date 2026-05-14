import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../presentation/providers/settings_provider.dart';

/// Экран настроек внешнего вида.
///
/// Позволяет выбрать тему оформления приложения.
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Внешний вид'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Тема оформления',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите тему, которая будет использоваться в приложении',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          // Светлая тема
          _buildThemeOption(
            context,
            title: 'Светлая',
            subtitle: 'Всегда использовать светлую тему',
            icon: Icons.wb_sunny,
            value: 'light',
            groupValue: settingsProvider.themeMode,
            onChanged: (value) => settingsProvider.setThemeMode(value!),
          ),

          const Divider(),

          // Тёмная тема
          _buildThemeOption(
            context,
            title: 'Тёмная',
            subtitle: 'Всегда использовать тёмную тему',
            icon: Icons.nights_stay,
            value: 'dark',
            groupValue: settingsProvider.themeMode,
            onChanged: (value) => settingsProvider.setThemeMode(value!),
          ),

          const Divider(),

          // Системная
          _buildThemeOption(
            context,
            title: 'Системная',
            subtitle: 'Следовать настройкам системы',
            icon: Icons.settings_suggest,
            value: 'system',
            groupValue: settingsProvider.themeMode,
            onChanged: (value) => settingsProvider.setThemeMode(value!),
          ),

          const SizedBox(height: 32),

          // Предпросмотр
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Текущая тема',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getThemeDescription(settingsProvider.themeMode),
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_florist,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Пример текста',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.green : Colors.grey,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Radio<String>(
        value: value,
        // ignore: deprecated_member_use
        groupValue: groupValue,
        // ignore: deprecated_member_use
        onChanged: onChanged,
        activeColor: Colors.green,
      ),
      onTap: () => onChanged(value),
    );
  }

  String _getThemeDescription(String themeMode) {
    switch (themeMode) {
      case 'light':
        return 'Светлая тема — белый фон, тёмный текст';
      case 'dark':
        return 'Тёмная тема — тёмный фон, светлый текст';
      case 'system':
        return 'Системная — автоматически переключается в зависимости от настроек устройства';
      default:
        return 'Неизвестная тема';
    }
  }
}
