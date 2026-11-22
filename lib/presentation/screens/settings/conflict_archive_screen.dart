import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/sync/sync_conflicts.dart';
import '../../../data/models/plant.dart';
import '../../../injection_container.dart';
import '../../providers/plant_crud_provider.dart';

/// Архив конфликтов синхронизации (аудит 4.3, H2).
///
/// При LWW-конфликте движок применяет remote, а локальную версию
/// архивирует. Здесь пользователь может вернуть свою локальную версию
/// (через штатный updatePlant → outbox → синхронизация) или оставить
/// облачную (запись просто удаляется из архива).
class ConflictArchiveScreen extends StatefulWidget {
  const ConflictArchiveScreen({super.key, this.store});

  /// Store для тестов; в приложении берётся из DI.
  final SyncConflictStore? store;

  @override
  State<ConflictArchiveScreen> createState() => _ConflictArchiveScreenState();
}

/// «Вернуть мою локальную версию»: восстановить localJson как новую
/// локальную правку (штатный updatePlant → outbox → синхронизация),
/// затем удалить запись из архива. localJson == null (локально запись
/// удалялась) — восстанавливать нечего, только чистим архив.
Future<void> restoreLocalConflict({
  required PlantCrudProvider provider,
  required SyncConflictStore store,
  required SyncConflict conflict,
}) async {
  final localJson = conflict.localJson;
  if (localJson != null) {
    await provider.updatePlant(
      conflict.permanentId,
      Plant.fromJson(localJson),
    );
  }
  await store.removeConflict(conflict.id);
}

/// «Оставить облачную»: облачная версия уже применена движком —
/// просто удалить запись из архива.
Future<void> keepRemoteConflict({
  required SyncConflictStore store,
  required SyncConflict conflict,
}) =>
    store.removeConflict(conflict.id);

class _ConflictArchiveScreenState extends State<ConflictArchiveScreen> {
  List<SyncConflict> _conflicts = [];

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

  void _reload() {
    setState(() {
      _conflicts = _store?.listConflicts() ?? [];
    });
  }

  String _plantName(SyncConflict c) {
    final json = c.localJson ?? c.remoteJson;
    final name = json?['latinName']?.toString();
    return (name == null || name.isEmpty) ? c.permanentId : name;
  }

  String _typeLabel(SyncConflict c) => switch (c.type) {
        'delete_vs_edit' => 'Удалено локально · изменено в облаке',
        _ => 'Изменено локально и в облаке',
      };

  Future<void> _restoreLocal(SyncConflict c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вернуть локальную версию'),
        content: const Text(
          'Заменить текущую версию вашей локальной копией из архива? '
          'Она будет синхронизирована на все устройства.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Вернуть'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final store = _store;
    if (store == null) return;
    await restoreLocalConflict(
      provider: context.read<PlantCrudProvider>(),
      store: store,
      conflict: c,
    );
    _reload();
  }

  Future<void> _keepRemote(SyncConflict c) async {
    final store = _store;
    if (store == null) return;
    await keepRemoteConflict(store: store, conflict: c);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Архив конфликтов'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _conflicts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.green,),
                  SizedBox(height: 16),
                  Text('Конфликтов нет',
                      style: TextStyle(fontSize: 18, color: Colors.grey),),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _conflicts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final c = _conflicts[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _plantName(c),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _typeLabel(c),
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[700],),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Дата: ${c.at.toLocal()}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500],),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _restoreLocal(c),
                                child: const Text(
                                  'Вернуть мою локальную версию',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton(
                                onPressed: () => _keepRemote(c),
                                child: const Text(
                                  'Оставить облачную',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
