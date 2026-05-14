import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../presentation/providers/settings_provider.dart';

/// Экран настроек уведомлений.
///
/// Позволяет настроить напоминания о поливе и их параметры.
class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Главный переключатель
          SwitchListTile(
            title: const Text(
              'Напоминания о поливе',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Получать уведомления когда наступает время полива',
            ),
            value: settingsProvider.wateringNotificationsEnabled,
            onChanged: (value) => settingsProvider.setWateringNotificationsEnabled(value),
          ),

          const Divider(),

          // Время уведомлений
          ListTile(
            enabled: settingsProvider.wateringNotificationsEnabled,
            leading: const Icon(Icons.access_time),
            title: const Text('Время напоминаний'),
            subtitle: Text(
              'Уведомления будут приходить в ${settingsProvider.notificationTime}',
            ),
            trailing: TextButton(
              onPressed: settingsProvider.wateringNotificationsEnabled
                  ? () => _showTimePicker(context, settingsProvider)
                  : null,
              child: const Text('ИЗМЕНИТЬ'),
            ),
          ),

          const Divider(),

          // Звук
          SwitchListTile(
            title: const Text('Звук уведомлений'),
            subtitle: const Text('Воспроизводить звук при получении уведомления'),
            value: settingsProvider.notificationSoundEnabled,
            onChanged: settingsProvider.wateringNotificationsEnabled
                ? (value) => settingsProvider.setNotificationSoundEnabled(value)
                : null,
          ),

          const SizedBox(height: 32),

          // Информация
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Как работают напоминания',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Уведомления приходят для растений, у которых наступил срок полива\n'
                  '• Время можно выбрать удобное для вас\n'
                  '• Уведомления работают даже когда приложение закрыто\n'
                  '• Для работы уведомлений разрешите их в настройках системы',
                  style: TextStyle(
                    color: Colors.red[800],
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

  Future<void> _showTimePicker(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final currentTime = provider.notificationTime;
    final parts = currentTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await provider.setNotificationTime(formattedTime);
    }
  }
}
