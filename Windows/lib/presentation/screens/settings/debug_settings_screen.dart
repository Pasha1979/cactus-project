import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/logger/app_logger.dart';
import '../../../presentation/providers/cloud_storage_provider.dart';
import '../../../presentation/providers/settings_provider.dart';

/// Экран отладки.
///
/// Позволяет просматривать логи, проводить диагностику и настраивать отладку.
class DebugSettingsScreen extends StatefulWidget {
  const DebugSettingsScreen({super.key});

  @override
  State<DebugSettingsScreen> createState() => _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends State<DebugSettingsScreen> {
  bool? _networkStatus;
  bool _checkingNetwork = false;

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
            Row(
              children: [
                Icon(
                  _networkStatus == null
                      ? Icons.help_outline
                      : (_networkStatus! ? Icons.check_circle : Icons.error),
                  color: _networkStatus == null
                      ? Colors.grey
                      : (_networkStatus! ? Colors.green : Colors.red),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(child: Text('Доступ к сети')),
                if (_checkingNetwork)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  GestureDetector(
                    onTap: () => _checkNetworkAccess(context),
                    child: Text(
                      _networkStatus == null
                          ? 'Проверить'
                          : (_networkStatus! ? 'Доступна' : 'Недоступна'),
                      style: TextStyle(
                        color: _networkStatus == null
                            ? Colors.blue
                            : (_networkStatus! ? Colors.green : Colors.red),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
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
    final logs = AppLogger.getRecentLogs(limit: 50);
    final displayLogs = logs.isEmpty
        ? ['[Логи отсутствуют — возможно, приложение только что запущено]']
        : logs.reversed.toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📋 Последние логи'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${displayLogs.length} записей',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      AppLogger.clearLogs();
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Очистить'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
              const Divider(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: displayLogs.length,
                  itemBuilder: (context, index) {
                    final log = displayLogs[index];
                    Color textColor = Colors.black87;
                    if (log.contains('[ERROR]')) textColor = Colors.red;
                    if (log.contains('[WARN]')) textColor = Colors.orange;
                    if (log.contains('[API]')) textColor = Colors.blue[800]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _shareLogs(context);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareLogs(BuildContext context) async {
    try {
      final logs = AppLogger.getRecentLogs(limit: 200);
      if (logs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет логов для отправки')),
          );
        }
        return;
      }

      final logContent = [
        '=== My Cactus App Logs ===',
        'Дата: ${DateTime.now().toIso8601String()}',
        '=========================',
        ...logs,
      ].join('\n');

      // Сохраняем во временный файл
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName =
          'cactus_logs_${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_'
          '${_twoDigits(now.hour)}${_twoDigits(now.minute)}.txt';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(logContent);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'My Cactus — логи для диагностики',
        text: 'Файл логов приложения My Cactus',
      );

      AppLogger.api('Логи отправлены через share_plus', tag: 'DEBUG');
    } catch (e, stack) {
      AppLogger.error('Ошибка отправки логов', error: e, stackTrace: stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки логов: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkNetworkAccess(BuildContext context) async {
    setState(() {
      _checkingNetwork = true;
      _networkStatus = null;
    });

    try {
      final response = await http
          .get(Uri.parse('https://yandex.ru'))
          .timeout(const Duration(seconds: 5));
      setState(() => _networkStatus = response.statusCode < 500);
    } catch (_) {
      setState(() => _networkStatus = false);
    } finally {
      setState(() => _checkingNetwork = false);
    }
  }

  String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
}
