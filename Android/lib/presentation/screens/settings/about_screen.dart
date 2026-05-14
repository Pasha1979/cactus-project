import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Экран "О приложении".
///
/// Показывает версию приложения, лицензии, ссылки.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _privacyPolicyUrl =
      'https://github.com/PaveUA/my-cactus/blob/main/PRIVACY.md';
  static const String _supportEmail = 'mycactus.support@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('О приложении'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Иконка и название
          Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.local_florist,
                  size: 48,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'MyCactus',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Версия 1.0.0',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Описание
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'MyCactus — приложение для коллекционеров кактусов и суккулентов. '
              'Ведите учёт растений, отслеживайте полив, создавайте напоминания '
              'и синхронизируйте коллекцию с облаком.',
              style: TextStyle(
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Ссылки
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Лицензии открытого ПО'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'MyCactus',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(
                Icons.local_florist,
                size: 48,
                color: Colors.green,
              ),
            ),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Политика конфиденциальности'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openUrl(context, _privacyPolicyUrl),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.support),
            title: const Text('Поддержка'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openEmail(context, _supportEmail),
          ),

          const SizedBox(height: 32),

          // Разработчики
          Center(
            child: Text(
              '© 2026 MyCactus',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть: $url')),
      );
    }
  }

  Future<void> _openEmail(BuildContext context, String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': 'MyCactus — Обращение в поддержку'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email-клиент недоступен. Напишите на: $email')),
      );
    }
  }
}
