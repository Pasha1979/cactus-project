import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/sync/sync_conflicts.dart';
import '../../../core/update_checker.dart';
import '../../../injection_container.dart';
import 'conflict_archive_screen.dart';

/// Экран "О приложении".
///
/// Показывает версию приложения, лицензии, ссылки.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _privacyPolicyUrl = ApiConstants.privacyPolicyUrl;
  static const String _supportEmail = ApiConstants.supportEmail;

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
                'Версия ${AppConstants.appVersion}',
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

          // Проверка обновлений (R-022)
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Проверить обновления'),
            subtitle: const Text('Поиск новой версии на GitHub'),
            onTap: () => _checkUpdates(context),
          ),

          const Divider(),

          // Архив конфликтов синхронизации (H2) — виден только при N>0.
          const ConflictArchiveTile(),

          // Ссылки
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Лицензии открытого ПО'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'MyCactus',
              applicationVersion: AppConstants.appVersion,
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

  Future<void> _checkUpdates(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final result = await UpdateChecker().checkForUpdates();
    if (!context.mounted) return;
    Navigator.pop(context);

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось проверить обновления')),
      );
      return;
    }
    if (!result.isNewer) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Обновлений нет'),
          content: Text(
            'У вас последняя версия (${AppConstants.appVersion})',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ОК'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Доступна версия ${result.latestVersion}'),
        content: Text(
          'Что нового:\n${result.releaseNotes}\n\nСкачать?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl(context, UpdateChecker.releasesUrl);
            },
            child: const Text('Скачать'),
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

/// Пункт «Архив конфликтов синхронизации (N)» (аудит 4.3, H2).
/// Скрыт при N==0; счётчик обновляется после возврата со списка.
/// Store подменяется в тестах через [store].
class ConflictArchiveTile extends StatefulWidget {
  const ConflictArchiveTile({super.key, this.store});

  final SyncConflictStore? store;

  @override
  State<ConflictArchiveTile> createState() => _ConflictArchiveTileState();
}

class _ConflictArchiveTileState extends State<ConflictArchiveTile> {
  int _count = 0;

  SyncConflictStore? get _store {
    try {
      return widget.store ?? sl<SyncConflictStore>();
    } catch (_) {
      return widget.store;
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ConflictArchiveTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) _reload();
  }

  void _reload() {
    final n = _store?.length ?? 0;
    if (n != _count && mounted) setState(() => _count = n);
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.sync_problem),
      title: Text('Архив конфликтов синхронизации ($_count)'),
      subtitle: const Text('Восстановить локальные версии'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConflictArchiveScreen(store: widget.store),
          ),
        );
        _reload();
      },
    );
  }
}
