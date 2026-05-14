import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:share_plus/share_plus.dart'; // TODO: Добавить зависимость

import '../../../presentation/providers/cloud_storage_provider.dart';
import '../../../presentation/providers/settings_provider.dart';

/// Экран отладки.
///
/// Позволяет просматривать логи, проводить диагностику и настраивать отладку.
class DebugSettingsScreen extends StatelessWidget {
  const DebugSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final cloudProvider = context.watch<CloudStorageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Отладка'),
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
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.construction, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Этот раздел предназначен для диагностики проблем. '
                    'Используйте его при обращении в поддержку.',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Логирование API
          SwitchListTile(
            title: const Text('Логирование API'),
            subtitle: const Text(
              'Записывать все API-запросы для диагностики',
            ),
            value: settingsProvider.apiLoggingEnabled,
            onChanged: (value) => settingsProvider.setApiLoggingEnabled(value),
          ),

          const Divider(),

          // Показывать ID
          SwitchListTile(
            title: const Text('Показывать ID растений'),
            subtitle: const Text(
              'Отображать внутренние ID в списке растений',
            ),
            value: settingsProvider.showPlantIds,
            onChanged: (value) => settingsProvider.setShowPlantIds(value),
          ),

          const SizedBox(height: 24),

          // Диагностика облака
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud, color: Colors.blue),
              title: const Text('Диагностика облака'),
              subtitle: const Text('Проверить подключение к Яндекс.Диск'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCloudDiagnostics(context, cloudProvider),
            ),
          ),

          const SizedBox(height: 8),

          // Посмотреть логи
          Card(
            child: ListTile(
              leading: const Icon(Icons.article, color: Colors.green),
              title: const Text('Посмотреть логи'),
              subtitle: const Text('Последние 50 записей'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLogs(context),
            ),
          ),

          const SizedBox(height: 8),

          // Отправить логи
          Card(
            child: ListTile(
              leading: const Icon(Icons.share, color: Colors.orange),
              title: const Text('Отправить логи'),
              subtitle: const Text('Поделиться логами для диагностики'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _shareLogs(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCloudDiagnostics(
    BuildContext context,
    CloudStorageProvider provider,
  ) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🔍 Диагностика облака'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDiagnosticRow(
              'Подключение к Яндекс.Диск',
              provider.isConnected,
            ),
            const SizedBox(height: 8),
            _buildDiagnosticRow(
              'Синхронизация',
              !provider.isSyncing,
              trueText: 'Готова',
              falseText: 'Идёт синхронизация...',
            ),
            const SizedBox(height: 8),
            _buildDiagnosticRow(
              'Доступ к сети',
              true, // TODO: Реальная проверка
            ),
            const SizedBox(height: 16),
            Text(
              'Если есть проблемы с подключением:\n'
              '1. Проверьте интернет-соединение\n'
              '2. Выйдите и войдите снова в аккаунт\n'
              '3. Проверьте, что Яндекс.Диск доступен',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(
    String label,
    bool isOK, {
    String? trueText,
    String? falseText,
  }) {
    return Row(
      children: [
        Icon(
          isOK ? Icons.check_circle : Icons.error,
          color: isOK ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          isOK ? (trueText ?? 'OK') : (falseText ?? 'Ошибка'),
          style: TextStyle(
            color: isOK ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _showLogs(BuildContext context) async {
    // TODO: Получить реальные логи из AppLogger
    final mockLogs = [
      '[2024-01-15 09:23:45] [API] GET /plants - 200 OK',
      '[2024-01-15 09:23:42] [SYNC] Синхронизация завершена',
      '[2024-01-15 09:23:40] [CLOUD] Подключение к Яндекс.Диск',
      '[2024-01-15 09:23:38] [DB] Загружено 150 растений',
      '[2024-01-15 09:23:35] [INIT] Приложение запущено',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📋 Последние логи'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: mockLogs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  mockLogs[index],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLogs(BuildContext context) async {
    // TODO: Добавить share_plus в pubspec.yaml и реализовать отправку
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция отправки логов в разработке'),
      ),
    );
  }
}
