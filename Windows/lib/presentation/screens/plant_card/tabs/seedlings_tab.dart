import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../models/plant.dart';
import '../../../../presentation/providers/providers.dart';
class SeedlingsTab extends StatelessWidget {
  final Plant batch;
  final void Function(BuildContext, Plant) onSeedlingTap;

  const SeedlingsTab({
    super.key,
    required this.batch,
    required this.onSeedlingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlantCrudProvider>(
      builder: (context, provider, child) {
        final seedlings = provider.getBatchSeedlings(batch.permanentId);

        if (seedlings.isEmpty) {
          return const Center(
            child: Text(
              'Нет сеянцев в этой партии',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: seedlings.length,
          itemBuilder: (context, index) {
            final seedling = seedlings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: _buildSeedlingPhoto(seedling),
                title: Text('${seedling.displayId} — ${seedling.latinName}'),
                subtitle: Text('Статус: ${seedling.statusText}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusButton(context, provider, seedling),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Удалить сеянец?'),
                            content: Text('Удалить ${seedling.displayId}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Отмена'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Удалить',
                                    style: TextStyle(color: Colors.red),),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await provider.removeSeedlingFromBatch(
                            batch.permanentId,
                            seedling.permanentId,
                          );
                        }
                      },
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => onSeedlingTap(context, seedling),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSeedlingPhoto(Plant seedling) {
    if (seedling.userPhotos.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.spa, color: Colors.grey),
      );
    }

    final photoUrl = seedling.userPhotos.first;
    final isNetworkPhoto = photoUrl.startsWith('http') || photoUrl.startsWith('https');

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isNetworkPhoto
          ? CachedNetworkImage(
              imageUrl: photoUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(Icons.hourglass_empty, color: Colors.grey),
              ),
              errorWidget: (context, url, error) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 40),
              ),
            )
          : Image.file(
              File(photoUrl),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 40),
              ),
            ),
    );
  }

  Widget _buildStatusButton(BuildContext context, PlantCrudProvider provider, Plant seedling) {
    Color statusColor;
    switch (seedling.status) {
      case 'growing':
        statusColor = Colors.orange;
        break;
      case 'in_collection':
        statusColor = Colors.green;
        break;
      case 'dead':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.blue;
    }

    return PopupMenuButton<String>(
      tooltip: 'Изменить статус',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.fiber_manual_record,
          color: statusColor,
          size: 20,
        ),
      ),
      onSelected: (String newStatus) async {
        final updatedSeedling = seedling.copyWith(status: newStatus);
        provider.updatePlant(seedling.permanentId, updatedSeedling);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус ${seedling.displayId} изменён на: ${_getStatusText(newStatus)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'growing',
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text('Растёт'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'in_collection',
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text('В коллекции'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'dead',
          child: Row(
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text('Погиб'),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'growing':
        return 'Растёт';
      case 'in_collection':
        return 'В коллекции';
      case 'dead':
        return 'Погиб';
      default:
        return status;
    }
  }
}
