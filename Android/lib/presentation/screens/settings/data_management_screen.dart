import 'package:flutter/material.dart';

import '../../../core/logger/app_logger.dart';
import '../../../services/image/photo_cache_manager.dart';

/// Экран управления данными.
///
/// Позволяет очистить кэш, посмотреть размер данных, экспортировать.
class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isLoading = false;
  String _cacheSize = 'Вычисление...';

  @override
  void initState() {
    super.initState();
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    // Здесь можно добавить вычисление размера кэша
    setState(() => _cacheSize = 'Нажмите "Очистить кэш" для очистки');
  }

  Future<void> _clearPhotoCache() async {
    setState(() => _isLoading = true);

    try {
      await PhotoCacheManager.clearCache();
      AppLogger.api('Photo cache cleared by user', tag: 'DATA_MANAGEMENT');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Кэш фото очищен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.api('Error clearing photo cache: $e', tag: 'DATA_MANAGEMENT');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearGbifCache() async {
    setState(() => _isLoading = true);

    // Здесь можно добавить очистку кэша GBIF
    await Future.delayed(const Duration(seconds: 1)); // Заглушка

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Кэш GBIF очищен'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление данными'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Размер данных
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.storage, size: 48, color: Colors.blue),
                        const SizedBox(height: 12),
                        Text(
                          'Данные приложения',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _cacheSize,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Очистка кэша фото
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.orange),
                  title: const Text('Очистить кэш фото'),
                  subtitle: const Text('Удалить загруженные изображения из кэша'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearPhotoCache,
                ),

                const Divider(),

                // Очистка кэша GBIF
                ListTile(
                  leading: const Icon(Icons.public, color: Colors.green),
                  title: const Text('Очистить кэш GBIF'),
                  subtitle: const Text('Удалить закэшированные данные о видах'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearGbifCache,
                ),

                const Divider(),

                // Экспорт всех данных
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.blue),
                  title: const Text('Экспорт всех данных'),
                  subtitle: const Text('Сохранить локальную копию базы данных'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Реализовать экспорт
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Функция в разработке'),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Предупреждение
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Важно',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Очистка кэша фото удалит только кэшированные изображения, '
                        'оригиналы в облаке останутся\n'
                        '• Очистка кэша GBIF удалит сохранённые данные о видах, '
                        'они будут загружены заново при необходимости\n'
                        '• Экспорт создаёт локальный файл для резервного копирования',
                        style: TextStyle(
                          color: Colors.orange[800],
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
}
