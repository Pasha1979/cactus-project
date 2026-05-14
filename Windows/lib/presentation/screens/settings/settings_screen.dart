import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Главный экран настроек.
///
/// Отображает список разделов настроек. При нажатии на раздел
/// открывается детальный экран этого раздела.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSection(
            context,
            icon: Icons.palette,
            title: 'Внешний вид',
            subtitle: 'Тема оформления',
            color: Colors.purple,
            route: '/settings/appearance',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.cloud,
            title: 'Облако и синхронизация',
            subtitle: 'Яндекс.Диск, автосинхронизация',
            color: Colors.blue,
            route: '/settings/cloud',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.wb_sunny,
            title: 'Погода',
            subtitle: 'Город, включение/выключение',
            color: Colors.orange,
            route: '/settings/weather',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.backup,
            title: 'Резервное копирование',
            subtitle: 'Автобэкап, восстановление',
            color: Colors.green,
            route: '/settings/backup',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.notifications,
            title: 'Уведомления',
            subtitle: 'Напоминания о поливе',
            color: Colors.red,
            route: '/settings/notifications',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.tune,
            title: 'Поведение приложения',
            subtitle: 'Автосохранение, подтверждения',
            color: Colors.teal,
            route: '/settings/behavior',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.science,
            title: 'Эксперименты',
            subtitle: 'Бета-функции',
            color: Colors.indigo,
            route: '/settings/experiments',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.storage,
            title: 'Управление данными',
            subtitle: 'Кэш, экспорт',
            color: Colors.brown,
            route: '/settings/data',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.bug_report,
            title: 'Отладка',
            subtitle: 'Логи, диагностика',
            color: Colors.grey,
            route: '/settings/debug',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.settings_applications,
            title: 'Системные',
            subtitle: 'Выход из аккаунта, сброс',
            color: Colors.deepPurple,
            route: '/settings/system',
          ),
          const Divider(height: 1),
          _buildSection(
            context,
            icon: Icons.info,
            title: 'О приложении',
            subtitle: 'Версия, лицензии',
            color: Colors.blueGrey,
            route: '/settings/about',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String route,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => context.push(route),
    );
  }
}
