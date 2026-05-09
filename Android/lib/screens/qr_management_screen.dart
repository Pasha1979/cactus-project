import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/plant.dart';
import '../models/qr_code_file.dart';
import '../providers/plant_provider.dart';
import 'batch_qr_creation_screen.dart';
import 'print_settings_screen.dart';

/// Экран управления QR-кодами и файлами печати
class QRManagementScreen extends StatefulWidget {
  const QRManagementScreen({super.key});

  @override
  State<QRManagementScreen> createState() => _QRManagementScreenState();
}

class _QRManagementScreenState extends State<QRManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await context.read<PlantProvider>().loadQRCodeFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление QR-кодами'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.picture_as_pdf), text: 'Файлы'),
            Tab(icon: Icon(Icons.local_florist), text: 'Растения'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFilesTab(),
          _buildPlantsTab(),
        ],
      ),
    );
  }

  // === ВКЛАДКА "ФАЙЛЫ" ===
  Widget _buildFilesTab() {
    return Consumer<PlantProvider>(
      builder: (context, provider, child) {
        final files = provider.qrCodeFiles;

        if (files.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Нет созданных PDF-файлов',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Создайте QR-коды и сохраните PDF для печати',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return _buildFileCard(file, provider);
          },
        );
      },
    );
  }

  Widget _buildFileCard(QRCodeFile file, PlantProvider provider) {
    final plants = provider.plants
        .where((p) => file.plantIds.contains(p.permanentId))
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text(
          file.fileName,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${file.createdAt.day.toString().padLeft(2, '0')}.${file.createdAt.month.toString().padLeft(2, '0')}.${file.createdAt.year} '
              '${file.createdAt.hour.toString().padLeft(2, '0')}:${file.createdAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${plants.length} растений · ${file.pageFormat} · '
              '${file.orientation == 'portrait' ? 'книжная' : 'альбомная'} · '
              '${file.labelWidthCm}x${file.labelHeightCm} см',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleFileAction(value, file, provider),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'print',
              child: Row(
                children: [
                  Icon(Icons.print, size: 20),
                  SizedBox(width: 8),
                  Text('Печать'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'recreate',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text('Пересоздать'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Переименовать'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red.shade300),
                  const SizedBox(width: 8),
                  Text('Удалить', style: TextStyle(color: Colors.red.shade300)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileAction(
    String action,
    QRCodeFile file,
    PlantProvider provider,
  ) async {
    switch (action) {
      case 'print':
        final pdfFile = File(file.filePath);
        if (await pdfFile.exists()) {
          await Printing.layoutPdf(
            onLayout: (_) => pdfFile.readAsBytes(),
          );
        } else {
          _showSnackBar('Файл не найден');
        }
        break;
      case 'recreate':
        final plants = provider.plants
            .where((p) => file.plantIds.contains(p.permanentId))
            .toList();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => PrintSettingsScreen(plantsToPrint: plants),
          ),
        );
        break;
      case 'rename':
        _showRenameDialog(file, provider);
        break;
      case 'delete':
        _showDeleteConfirm(file, provider);
        break;
    }
  }

  void _showRenameDialog(QRCodeFile file, PlantProvider provider) {
    final controller = TextEditingController(
      text: file.fileName.replaceAll('.pdf', ''),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать файл'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Новое имя',
            suffixText: '.pdf',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(ctx);
                await provider.renameQRCodeFile(file.id, newName);
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Файл переименован')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(QRCodeFile file, PlantProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text(
            'Файл "${file.fileName}" будет удалён.\nЭто действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(ctx);
              await provider.deleteQRCodeFile(file.id);
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Файл удалён')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  // === ВКЛАДКА "РАСТЕНИЯ" ===
  Widget _buildPlantsTab() {
    return Consumer<PlantProvider>(
      builder: (context, provider, child) {
        final plants = provider.plants;
        final plantsWithQR = provider.getPlantsWithQRCode();
        final plantsWithoutQR = provider.getPlantsWithoutQRCode();

        return Column(
          children: [
            // Напоминание о новых растениях
            _buildReminderCard(plantsWithoutQR, provider),
            // Фильтры
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  FilterChip(
                    label: Text('Все (${plants.length})'),
                    selected: _plantFilter == 'all',
                    onSelected: (_) => setState(() => _plantFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('С QR (${plantsWithQR.length})'),
                    selected: _plantFilter == 'with_qr',
                    onSelected: (_) => setState(() => _plantFilter = 'with_qr'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Без QR (${plantsWithoutQR.length})'),
                    selected: _plantFilter == 'without_qr',
                    selectedColor: Colors.orange.shade100,
                    onSelected: (_) =>
                        setState(() => _plantFilter = 'without_qr'),
                  ),
                ],
              ),
            ),
            // Список растений
            Expanded(
              child: _buildPlantsList(plants, plantsWithQR, plantsWithoutQR),
            ),
          ],
        );
      },
    );
  }

  String _plantFilter = 'all';

  Widget _buildPlantsList(
    List<Plant> allPlants,
    List<Plant> withQR,
    List<Plant> withoutQR,
  ) {
    List<Plant> filtered;
    switch (_plantFilter) {
      case 'with_qr':
        filtered = withQR;
        break;
      case 'without_qr':
        filtered = withoutQR;
        break;
      default:
        filtered = allPlants;
    }

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'Нет растений',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final plant = filtered[index];
        final hasQR = plant.qrCode != null && plant.qrCode!.isActive;
        return ListTile(
          leading: Icon(
            hasQR ? Icons.qr_code : Icons.qr_code_outlined,
            color: hasQR ? Colors.green : Colors.grey,
          ),
          title: Text(plant.latinName),
          subtitle: Text(plant.displayId),
          trailing: hasQR
              ? const Icon(Icons.check_circle, color: Colors.green)
              : TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => BatchQRCreationScreen(),
                      ),
                    );
                  },
                  child: const Text('Создать QR'),
                ),
        );
      },
    );
  }

  Widget _buildReminderCard(List<Plant> plantsWithoutQR, PlantProvider provider) {
    // Все растения без QR требуют внимания
    final newPlants = plantsWithoutQR.toList();

    if (newPlants.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: ListTile(
        leading: Icon(Icons.notification_important, color: Colors.orange.shade700),
        title: Text(
          '${newPlants.length} растений без QR-кодов',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade900,
          ),
        ),
        subtitle: const Text('Нажмите, чтобы создать QR-коды'),
        trailing: ElevatedButton(
          onPressed: () {
            provider.clearSelections();
            for (var plant in newPlants) {
              provider.toggleSelection(plant.permanentId);
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => const BatchQRCreationScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Создать'),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
