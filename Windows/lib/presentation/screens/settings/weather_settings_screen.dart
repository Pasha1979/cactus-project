import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../presentation/providers/settings_provider.dart';
import '../../../presentation/providers/weather_provider.dart';

/// Экран настроек погоды.
///
/// Позволяет включить/выключить погоду и изменить город.
class WeatherSettingsScreen extends StatefulWidget {
  const WeatherSettingsScreen({super.key});

  @override
  State<WeatherSettingsScreen> createState() => _WeatherSettingsScreenState();
}

class _WeatherSettingsScreenState extends State<WeatherSettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final weatherProvider = context.watch<WeatherProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Погода'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Включение/выключение погоды
          SwitchListTile(
            title: const Text('Показывать погоду'),
            subtitle: const Text(
              'Погодные рекомендации для полива в календаре ухода',
            ),
            value: settingsProvider.weatherEnabled,
            onChanged: (value) => settingsProvider.setWeatherEnabled(value),
          ),

          const Divider(),

          // Текущий город
          ListTile(
            title: const Text('Текущий город'),
            subtitle: FutureBuilder<String?>(
              future: weatherProvider.getCity(),
              builder: (context, snapshot) {
                final city = snapshot.data;
                return Text(city ?? 'Не установлен');
              },
            ),
            trailing: ElevatedButton(
              onPressed: settingsProvider.weatherEnabled
                  ? () => _showCityDialog(context)
                  : null,
              child: const Text('Изменить'),
            ),
          ),

          const SizedBox(height: 24),

          // Кнопка определения по геолокации
          ElevatedButton.icon(
            onPressed: settingsProvider.weatherEnabled && !_isLoading
                ? () => _detectLocation(context)
                : null,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(_isLoading ? 'Определение...' : 'Определить автоматически'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 32),

          // Информация
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
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Как это работает',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Погода показывается в календаре ухода\n'
                  '• Рекомендации по поливу на основе температуры\n'
                  '• Данные обновляются автоматически\n'
                  '• Работает для любого города мира',
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

  Future<void> _detectLocation(BuildContext context) async {
    setState(() => _isLoading = true);

    final weatherProvider = context.read<WeatherProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await weatherProvider.initLocation();

      if (!mounted) return;

      final city = await weatherProvider.getCity();

      if (!mounted) return;

      if (city != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ Город определён: $city'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('⚠️ Не удалось определить город автоматически'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCityDialog(BuildContext context) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);

    final city = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Введите город'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Например, Москва',
            prefixIcon: Icon(Icons.location_city),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(ctx, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(ctx, value);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (city != null && city.isNotEmpty && mounted) {
      await weatherProvider.setCity(city);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ Город "$city" сохранён!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
