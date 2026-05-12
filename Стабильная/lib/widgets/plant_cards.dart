import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Сохранено: Для adultImageUrl и userPhotos network.
import 'dart:io'; // Сохранено: Для Image.file local userPhotos.
import '../providers/plant_provider.dart'; // Сохранено: Для context.watch/read<PlantProvider>() — selectedIds, getAdultImage, lastGlobalWateringText.
import '../models/plant.dart'; // Сохранено: Для Plant тип, statusText, lastWateringText.
import '../screens/plant_card_screen.dart';
import '../theme/cactus_theme.dart';

class PlantCards extends StatelessWidget {
  final List<Plant> plants;
  final String sortColumn;
  final bool isAscending;
  final Function(String) onSort;
  final Function(Plant) onEdit;
  final Function(String, Plant) onUpdate;
  final Function(String) onDelete;

  const PlantCards({
    super.key,
    required this.plants,
    required this.sortColumn,
    required this.isAscending,
    required this.onSort,
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  Widget _buildSortButton(String column, String label) {
    return TextButton(
      onPressed: () => onSort(column),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          if (sortColumn == column)
            Icon(isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'in_collection':
        return Colors.amber.shade600;
      case 'growing':
        return Colors.green.shade400;
      case 'dead':
        return Colors.red.shade400;
      case 'failed':
        return Colors.blueGrey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  void _showStatusDialog(BuildContext context, Plant plant) {
    const validStatuses = [
      'sown',
      'growing',
      'in_collection',
      'dead',
      'failed'
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Изменить статус ${plant.latinName}'),
        content: DropdownButton<String>(
          value: validStatuses.contains(plant.status) ? plant.status : 'failed',
          items: validStatuses
              .map((status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(
                      status == 'sown'
                          ? 'Посеян'
                          : status == 'growing'
                              ? 'Растёт'
                              : status == 'in_collection'
                                  ? 'В коллекции'
                                  : status == 'dead'
                                      ? 'Погиб'
                                      : 'Не взошел',
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              final updatedPlant = plant.copyWith(status: value);
              onUpdate(plant.permanentId, updatedPlant);
              Navigator.pop(ctx); // Используем ctx вместо context
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // Используем ctx
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _showQuickView(BuildContext context, Plant plant) {
    final provider = context.read<PlantProvider>();
    final adultImageUrl = provider.getAdultImage(plant.permanentId);
    final userPhotos = plant.userPhotos;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plant.latinName),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        content: SizedBox(
          width: 380, // компактная ширина
          height: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Секция Header — только ОДНА главная фотография
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (plant.countryFlag != null) ...[
                          Hero(
                            tag: 'flag_${plant.permanentId}',
                            child:
                                Image.network(plant.countryFlag!, height: 32),
                          ),
                          Text('Страна: ${plant.country ?? "Не указана"}'),
                        ],
                        const SizedBox(height: 8),

                        // === Главная фотография растения ===
                        if (userPhotos.isNotEmpty) ...[
                          const Text('Растение в коллекции (главное фото):'),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 150,
                              height: 150,
                              child: userPhotos.first.startsWith('http') ||
                                      userPhotos.first.startsWith('https')
                                  ? CachedNetworkImage(
                                      imageUrl: userPhotos.first,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                    )
                                  : Image.file(
                                      File(userPhotos.first),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.error),
                                    ),
                            ),
                          ),
                        ] else if (adultImageUrl != null) ...[
                          const Text('Взрослое растение:'),
                          const SizedBox(height: 6),
                          Hero(
                            tag: 'adult_photo_${plant.permanentId}',
                            child: CachedNetworkImage(
                              imageUrl: adultImageUrl,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          ),
                        ] else
                          const Center(
                            child: Column(
                              children: [
                                Icon(Icons.eco, size: 80, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Нет фото',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Секция Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Статус: ${plant.statusText}'),
                        Text('Год: ${plant.year}'),
                        Text('ID: ${plant.displayId}'),
                        Text('Последний полив: ${plant.lastWateringText}'),
                        Text(
                            'Последний общий полив: ${provider.lastGlobalWateringText}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Секция Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Редактировать'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onEdit(plant);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CactusColors.primaryGreen,
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text('Удалить',
                          style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete(plant.permanentId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Закрыть'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // Улучшенный метод: всегда берёт первое фото из userPhotos как главное
  String? _getSelectedPhotoUrl(Plant plant, PlantProvider provider) {
    // Приоритет 1: пользовательские фото (первое всегда главное)
    if (plant.userPhotos.isNotEmpty) {
      final mainPhoto = plant.userPhotos.first;
      return mainPhoto;
    }

    // Приоритет 2: adult фото (только если нет своих фото)
    final adultUrl = provider.getAdultImage(plant.permanentId);
    if (adultUrl != null) {
      return adultUrl;
    }

    return null;
  }

  void _showFullPhoto(BuildContext context, String photoUrl, bool isNetwork) {
    if (isNetwork && photoUrl.startsWith('https://')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;
        final provider = Provider.of<PlantProvider>(context, listen: false);
        await provider.ensureLocalPhotosExist();
        if (context.mounted) {
          // Обновляем UI, чтобы фото перезагрузилось
          (context as Element).markNeedsBuild();
        }
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: InteractiveViewer(
              child: isNetwork
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(color: Colors.white),
                      errorWidget: (context, url, error) => const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 50),
                    )
                  : Image.file(
                      File(photoUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 50),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildSortButton('latinName', 'Название'),
                  const SizedBox(width: 8),
                  _buildSortButton('status', 'Статус'),
                  const SizedBox(width: 8),
                  _buildSortButton('year', 'Год'),
                  const SizedBox(width: 8),
                  _buildSortButton('category', 'Категория'),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: provider.selectedIds.length == plants.length &&
                        plants.isNotEmpty,
                    onChanged: (value) {
                      if (value == true) {
                        provider.selectAll(
                            plants.map((p) => p.permanentId).toList());
                      } else {
                        provider.clearSelections();
                      }
                    },
                    activeColor: Colors.green,
                  ),
                  const Text('Все', style: TextStyle(fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: plants.isEmpty
              ? Center(
                  child: Card(
                    elevation: 2,
                    color: CactusColors.sandLight,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // МЕСТО ДЛЯ КАСТОМНОЙ ИЛЛЮСТРАЦИИ КАКТУСА
                          // Положи свой PNG/SVG в assets/illustrations/empty_cactus.png (или .svg)
                          // и добавь в pubspec.yaml:
                          // assets:
                          //   - assets/illustrations/
                          // const Image.asset('assets/illustrations/empty_cactus.png', height: 120),
                          const Icon(Icons.eco,
                              size: 80,
                              color: CactusColors
                                  .primaryGreen), // временная иконка
                          const SizedBox(height: 16),
                          const Text(
                            'Коллекция пуста',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: CactusColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Добавьте первое растение\nили импортируйте из Excel',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plants.length,
                  itemBuilder: (context, index) {
                    final plant = plants[index];
                    final isSelected =
                        provider.selectedIds.contains(plant.permanentId);
                    final statusColor = _getStatusColor(plant.status);

                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => PlantCardScreen(plant: plant),
                        ),
                      ),
                      onLongPress: () => _showQuickView(context, plant),
                      child: Card(
                        color:
                            isSelected ? CactusColors.sandBeige : Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) => context
                                    .read<PlantProvider>()
                                    .toggleSelection(plant.permanentId),
                                activeColor: CactusColors.primaryGreen,
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: CactusColors.sandLight,
                                child: Text('${index + 1}',
                                    style: const TextStyle(
                                        color: CactusColors.primaryGreen,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),

                              // Основная информация
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plant.latinName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          plant.category == 'purchased'
                                              ? Icons.local_offer
                                              : Icons.eco,
                                          size: 16,
                                          color: plant.category == 'purchased'
                                              ? Colors.blue
                                              : CactusColors.primaryGreen,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${plant.category == 'purchased' ? 'Куплено' : 'Посев'} ${plant.year}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: plant.category == 'purchased'
                                                ? Colors.blue
                                                : CactusColors.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${plant.displayId}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Главное фото — улучшенная версия
                              if (!isSelected)
                                SizedBox(
                                  width: 80,
                                  height: 60,
                                  child: _getSelectedPhotoUrl(
                                              plant, provider) !=
                                          null
                                      ? GestureDetector(
                                          onTap: () {
                                            final photoUrl =
                                                _getSelectedPhotoUrl(
                                                    plant, provider)!;
                                            final isNetwork =
                                                photoUrl.startsWith('http');
                                            _showFullPhoto(
                                                context, photoUrl, isNetwork);
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: _getSelectedPhotoUrl(
                                                        plant, provider)!
                                                    .startsWith('http')
                                                ? CachedNetworkImage(
                                                    imageUrl:
                                                        _getSelectedPhotoUrl(
                                                            plant, provider)!,
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) =>
                                                        const CircularProgressIndicator(
                                                            strokeWidth: 2),
                                                    errorWidget: (_, __, ___) =>
                                                        const Icon(Icons.error,
                                                            color: Colors.red),
                                                  )
                                                : Image.file(
                                                    File(_getSelectedPhotoUrl(
                                                        plant, provider)!),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __,
                                                            ___) =>
                                                        const Icon(Icons.error,
                                                            color: Colors.red),
                                                  ),
                                          ),
                                        )
                                      : Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.eco,
                                              size: 32, color: Colors.grey),
                                        ),
                                ),

                              const SizedBox(width: 12),

                              // Статус
                              GestureDetector(
                                onTap: () => _showStatusDialog(context, plant),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    plant.statusText,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: CactusColors.primaryGreen),
                                onPressed: () => onEdit(plant),
                                tooltip: 'Редактировать',
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => onDelete(plant.permanentId),
                                tooltip: 'Удалить',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
