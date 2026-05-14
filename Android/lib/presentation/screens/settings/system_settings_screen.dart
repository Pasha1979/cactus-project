import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../presentation/providers/cloud_storage_provider.dart';
import '../../../presentation/providers/settings_provider.dart';
import '../../../screens/welcome_screen.dart';

/// Экран системных настроек.
///
/// Содержит критические операции: выход из аккаунта, сброс настроек.
class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Системные'),
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
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Внимание: операции в этом разделе необратимы!',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Выход из аккаунта
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Выйти из аккаунта',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'Отключить облако и сбросить авторизацию',
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: () => _confirmLogout(context),
            ),
          ),

          const SizedBox(height: 16),

          // Сбросить обучение
          Card(
            child: ListTile(
              leading: const Icon(Icons.school, color: Colors.orange),
              title: const Text('Сбросить обучение'),
              subtitle: const Text(
                'Показать экран приветствия при следующем запуске',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmResetWelcome(context),
            ),
          ),

          const SizedBox(height: 16),

          // Сбросить настройки
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore, color: Colors.blue),
              title: const Text('Сбросить настройки'),
              subtitle: const Text(
                'Вернуть все настройки к значениям по умолчанию',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmResetSettings(context, settingsProvider),
            ),
          ),

          const SizedBox(height: 32),

          // Информация
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Что делает каждая операция:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Выход из аккаунта — отключает Яндекс.Диск и удаляет локальные токены\n'
                  '• Сброс обучения — покажет экран приветствия при следующем запуске\n'
                  '• Сброс настроек — все переключатели вернутся к значениям по умолчанию',
                  style: TextStyle(
                    color: Colors.grey[700],
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

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Выйти из аккаунта?'),
        content: const Text(
          'Это действие:\n'
          '• Отключит Яндекс.Диск\n'
          '• Удалит локальные данные авторизации\n'
          '• Данные в облаке останутся\n\n'
          'Приложение будет перезапущено. Продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final cloudProvider = context.read<CloudStorageProvider>();

      // Отключаем облако
      if (cloudProvider.isConnected) {
        await cloudProvider.disconnect();
      }

      // Сбрасываем флаг welcome
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', false);

      if (!context.mounted) return;

      // Переходим на экран приветствия
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _confirmResetWelcome(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить обучение?'),
        content: const Text(
          'При следующем запуске приложения будет показан экран приветствия.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Обучение сброшено. Перезапустите приложение.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _confirmResetSettings(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить настройки?'),
        content: const Text(
          'Все настройки будут возвращены к значениям по умолчанию. '
          'Это не повлияет на данные растений.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.resetToDefaults();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Настройки сброшены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
