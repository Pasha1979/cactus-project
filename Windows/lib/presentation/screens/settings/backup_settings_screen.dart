import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/logger/app_logger.dart';
import '../../../services/backup/auto_backup_service.dart';
import '../../../presentation/providers/cloud_storage_provider.dart';

/// Экран настроек автоматического резервного копирования.
///
/// Позволяет пользователю:
/// - Включить/выключить автобэкап
/// - Запустить бэкап вручную
/// - Восстановить данные из облака
/// - Увидеть статус последнего бэкапа
class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isEnabled = true;
  bool _isLoading = true;
  DateTime? _lastBackup;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await AutoBackupService.isEnabled;
    final lastBackup = await AutoBackupService.lastBackupDate;

    setState(() {
      _isEnabled = enabled;
      _lastBackup = lastBackup;
      _isLoading = false;
    });
  }

  Future<void> _toggleBackup(bool value) async {
    setState(() {
      _isEnabled = value;
      _statusMessage = value ? 'Автобэкап включен' : 'Автобэкап отключен';
    });

    await AutoBackupService.setEnabled(value);

    AppLogger.api('Пользователь ${value ? 'включил' : 'отключил'} автобэкап', tag: 'BACKUP_UI');

    // Очищаем статус через 3 секунды
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _statusMessage = null);
      }
    });
  }

  Future<void> _runManualBackup() async {
    final cloudProvider = context.read<CloudStorageProvider>();

    if (!cloudProvider.isConnected) {
      _showMessage('❌ Нет подключения к Яндекс.Диск. Подключите облако в настройках.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Создание бэкапа...';
    });

    try {
      final result = await AutoBackupService.performBackup();

      if (result.success) {
        _showMessage('✅ Бэкап успешно создан!');
        await _loadSettings(); // Обновляем время последнего бэкапа
      } else if (!result.isConnected) {
        _showMessage('❌ Нет подключения к Яндекс.Диск', isError: true);
      } else {
        _showMessage('❌ Ошибка: ${result.error}', isError: true);
      }
    } catch (e) {
      _showMessage('❌ Ошибка: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromCloud() async {
    final cloudProvider = context.read<CloudStorageProvider>();

    if (!cloudProvider.isConnected) {
      _showMessage('❌ Нет подключения к Яндекс.Диск', isError: true);
      return;
    }

    // Подтверждение восстановления
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Восстановление данных'),
        content: const Text(
          'Текущие данные будут заменены данными из облака.\n\n'
          'Это действие нельзя отменить!\n\n'
          'Убедитесь, что в облаке есть актуальная копия.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Восстановление данных...';
    });

    try {
      final result = await AutoBackupService.restoreFromCloud();

      if (result.success) {
        _showMessage('✅ Данные успешно восстановлены! Перезапустите приложение.');
      } else if (!result.isConnected) {
        _showMessage('❌ Нет подключения к Яндекс.Диск', isError: true);
      } else {
        _showMessage('❌ Ошибка восстановления: ${result.error}', isError: true);
      }
    } catch (e) {
      _showMessage('❌ Ошибка: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() => _statusMessage = message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );

    // Очищаем статус через 5 секунд
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _statusMessage = null);
      }
    });
  }

  String _formatLastBackup(DateTime? date) {
    if (date == null) return 'Бэкапов пока нет';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    if (diff.inDays == 1) return 'Вчера';
    return '${diff.inDays} дн. назад';
  }

  @override
  Widget build(BuildContext context) {
    final cloudProvider = context.watch<CloudStorageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Резервное копирование'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Карточка статуса
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              cloudProvider.isConnected
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: cloudProvider.isConnected
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cloudProvider.isConnected
                                  ? 'Подключено к Яндекс.Диск'
                                  : 'Яндекс.Диск не подключен',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Последний бэкап: ${_formatLastBackup(_lastBackup)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Переключатель автобэкапа
                SwitchListTile(
                  title: const Text('Автоматический бэкап'),
                  subtitle: const Text('Создавать копию каждые 24 часа'),
                  value: _isEnabled,
                  onChanged: cloudProvider.isConnected ? _toggleBackup : null,
                ),

                const Divider(),

                // Ручной бэкап
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Создать бэкап сейчас'),
                  subtitle: const Text('Загрузить текущие данные в облако'),
                  enabled: cloudProvider.isConnected,
                  onTap: _runManualBackup,
                ),

                // Восстановление
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: const Text('Восстановить из облака'),
                  subtitle: const Text('Заменить текущие данные копией из облака'),
                  enabled: cloudProvider.isConnected,
                  onTap: _restoreFromCloud,
                ),

                const SizedBox(height: 24),

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
                            'Как это работает',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Бэкап сохраняется на ваш Яндекс.Диск\n'
                        '• Создаётся автоматически раз в сутки\n'
                        '• Хранится в папке /MyCactus\n'
                        '• Можно восстановить на любом устройстве',
                        style: TextStyle(color: Colors.blue[800]),
                      ),
                    ],
                  ),
                ),

                // Статусное сообщение
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusMessage!.startsWith('✅')
                          ? Colors.green[50]
                          : _statusMessage!.startsWith('❌')
                              ? Colors.red[50]
                              : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _statusMessage!.startsWith('✅')
                            ? Colors.green[800]
                            : _statusMessage!.startsWith('❌')
                                ? Colors.red[800]
                                : Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
