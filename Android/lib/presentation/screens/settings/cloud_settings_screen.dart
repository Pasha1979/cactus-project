import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../presentation/providers/cloud_storage_provider.dart';
import '../../../presentation/providers/settings_provider.dart';

/// Экран настроек облака и синхронизации.
///
/// Позволяет управлять подключением к Яндекс.Диску и настройками автосинхронизации.
class CloudSettingsScreen extends StatelessWidget {
  const CloudSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cloudProvider = context.watch<CloudStorageProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Облако и синхронизация'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Карточка статуса подключения
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    cloudProvider.isConnected ? Icons.cloud_done : Icons.cloud_off,
                    size: 48,
                    color: cloudProvider.isConnected ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cloudProvider.isConnected
                        ? 'Подключено к Яндекс.Диск'
                        : 'Яндекс.Диск не подключен',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (cloudProvider.isConnected) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Синхронизация работает автоматически',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Кнопка подключения/отключения
          if (!cloudProvider.isConnected)
            ElevatedButton.icon(
              onPressed: () async {
                await cloudProvider.connectToYandexDisk(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        cloudProvider.isConnected
                            ? '✅ Яндекс.Диск подключен'
                            : '❌ Не удалось подключить',
                      ),
                      backgroundColor: cloudProvider.isConnected ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.cloud),
              label: const Text('Подключить Яндекс.Диск'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Отключить облако?'),
                    content: const Text(
                      'Данные останутся на устройстве, но синхронизация будет отключена.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Отключить'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await cloudProvider.disconnect();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Облачное хранилище отключено'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.cloud_off),
              label: const Text('Отключить Яндекс.Диск'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // Автосинхронизация
          SwitchListTile(
            title: const Text('Автосинхронизация при старте'),
            subtitle: const Text(
              'Автоматически синхронизировать данные при запуске приложения',
            ),
            value: settingsProvider.autoSyncOnStartup,
            onChanged: (value) => settingsProvider.setAutoSyncOnStartup(value),
          ),

          const SizedBox(height: 16),

          // Информация
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Как работает синхронизация',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Фото растений сохраняются в облаке\n'
                  '• Данные синхронизируются между устройствами\n'
                  '• Бэкапы создаются автоматически в облаке\n'
                  '• Доступ к коллекции с любого устройства',
                  style: TextStyle(
                    color: Colors.blue[800],
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
