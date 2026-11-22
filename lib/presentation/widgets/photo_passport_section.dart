import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/photo_passport.dart';
import '../../core/sync/photo_passport_manager.dart';
import '../../data/models/plant.dart';
import '../../injection_container.dart';

/// Секция фото-паспортов в галерее растения (этап 3.3, R-056).
///
/// Активные паспорта — карточки с меню «⋮» (В архив / Удалить везде /
/// Освободить место). Переключатель «Показать архивные фото» открывает
/// архив с кнопкой «Вернуть в галерею». Рендерится только при наличии
/// паспортов — без данных ничего не добавляет к дизайну.
class PhotoPassportSection extends StatefulWidget {
  const PhotoPassportSection({super.key, required this.plant, this.manager});

  final Plant plant;

  /// Менеджер для тестов; в приложении берётся из DI.
  final PhotoPassportManager? manager;

  @override
  State<PhotoPassportSection> createState() => _PhotoPassportSectionState();
}

class _PhotoPassportSectionState extends State<PhotoPassportSection> {
  bool _showArchived = false;
  Future<List<PhotoPassport>>? _future;

  PhotoPassportManager? get _manager =>
      widget.manager ?? _resolveManager();

  PhotoPassportManager? _resolveManager() {
    try {
      return sl<PhotoPassportManager>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final mgr = _manager;
    _future = mgr?.getAllPassports(widget.plant.permanentId);
  }

  Future<void> _act(Future<void> Function() action) async {
    await action();
    if (mounted) setState(_reload);
  }

  Future<void> _onMenuSelected(String action, PhotoPassport passport) async {
    final mgr = _manager;
    if (mgr == null) return;
    switch (action) {
      case 'archive':
        await _act(() => mgr.archivePassport(passport.passportId));
      case 'delete':
        await _confirmDelete(mgr, passport);
      case 'free':
        await _act(() => mgr.freeLocalSpace(passport.passportId));
    }
  }

  Future<void> _confirmDelete(
    PhotoPassportManager mgr,
    PhotoPassport passport,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить фото'),
        content: const Text(
          'Вы уверены? Фото будет удалено с Яндекс.Диска и всех устройств.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _act(() => mgr.deletePassportEverywhere(passport.passportId));
    }
  }

  Widget _image(String filePath) {
    if (filePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: filePath,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 32),
      );
    }
    final file = File(filePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    // Облачный путь /MyCactus/... — превью появится после скачивания
    return const Icon(Icons.cloud_outlined, size: 32, color: Colors.grey);
  }

  Widget _passportCard(PhotoPassport passport) {
    final path = passport.versions.isEmpty
        ? ''
        : passport.versions.last.yandexFilePath;
    return SizedBox(
      width: 100,
      height: 100,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.grey[200]!,
              child: path.isEmpty ? const SizedBox() : _image(path),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black54),
                onSelected: (v) => _onMenuSelected(v, passport),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'archive', child: Text('В архив')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить везде'),
                  ),
                  PopupMenuItem(
                    value: 'free',
                    child: Text('Освободить место'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mgr = _manager;
    if (mgr == null) return const SizedBox.shrink();

    return FutureBuilder<List<PhotoPassport>>(
      future: _future,
      builder: (context, snap) {
        final passports = snap.data ?? const <PhotoPassport>[];
        if (passports.isEmpty) return const SizedBox.shrink();

        final active = passports.where((p) => !p.isArchived).toList();
        final archived = passports.where((p) => p.isArchived).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: active.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _passportCard(active[i]),
                  ),
                ),
              if (archived.isNotEmpty)
                InkWell(
                  onTap: () =>
                      setState(() => _showArchived = !_showArchived),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _showArchived,
                        onChanged: (v) =>
                            setState(() => _showArchived = v ?? false),
                      ),
                      const Text('Показать архивные фото'),
                    ],
                  ),
                ),
              if (_showArchived)
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: archived.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final p = archived[i];
                      return Column(
                        children: [
                          _passportCard(p),
                          TextButton(
                            onPressed: () =>
                                _act(() => mgr.unarchivePassport(p.passportId)),
                            child: const Text('Вернуть в галерею'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
