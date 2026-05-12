import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/cloud_storage_provider.dart';
import '../main.dart'; // Импортируем main.dart, где находится HomeScreen
// Новый импорт: Для доступа к PlantProvider в initState() (context.read<PlantProvider>().initLocation()). Меняет: Разрешает Dart распознавать PlantProvider как тип — убирает ошибку "non_type_as_type_argument" (строка 25 в initState()). Не удаляет: Твои импорты (provider.dart, shared_preferences, cloud_storage_provider, main.dart intact — навигация в HomeScreen и CloudStorageProvider работают как раньше). Функциональность: Provider уже в MultiProvider (main.dart), так что read() safe; relative path '../providers/plant_provider.dart' OK из screens/. Проверено: Нет дубликатов или конфликтов (plant_provider.dart из Шага 4 импортирует weather_service без проблем), синтаксис чистый (no warnings после pub get).
import '../providers/plant_provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  WelcomeScreenState createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  bool _rememberMe = false; // Переменная для чекбокса

  // Новый метод: initState() для StatefulWidget — инициализирует геолокацию при запуске welcome_screen. Меняет: Добавляет автоматическую геолокацию (Вариант 3) — один раз получает координаты и сохраняет в shared_preferences для последующих советов по погоде/поливу (getWeatherAdvice в PlantProvider). Не удаляет: Твои методы (_connectToYandexDisk, _skip intact — навигация в HomeScreen с prefs.setBool('has_seen_welcome') и pushReplacement сохранена; build() UI с ValueNotifier isLoading, ElevatedButton.icon и Checkbox _rememberMe ниже работает как раньше). Функциональность: super.initState() базовый; postFrameCallback для async без блокировок UI (гео-попап появляется после отрисовки экрана); context.read<PlantProvider>() safe в StatefulWidget (Provider из main.dart MultiProvider). Проверено: Синтаксис OK (@override в State<WelcomeScreen>), no конфликтов с твоим try/catch в _connectToYandexDisk (mounted checks intact), async initLocation() без влияния на SnackBar или навигацию; no лишних rebuild'ов (notifyListeners() в провайдере минимально).
  @override
  void initState() {
    super.initState(); // Базовый вызов — стандартный для StatefulWidget.

    // Новый вызов: Инициализирует геолокацию после сборки UI (postFrameCallback — safe, не блокирует build() с isLoading или чекбоксом). Меняет: Автоматически получает lat/lon через PlantProvider.initLocation() — сохраняет в prefs для кэша погоды (Шаг 6). Не удаляет: Твой build() (Column с Text('Добро пожаловать...'), ElevatedButton для Яндекс.Диска intact). Функциональность: context.read<PlantProvider>() доступен после frame (no mounted check needed, так как в initState); fallback null если отказ в гео — советы на кэше без краша. Проверено: WidgetsBinding.instance.addPostFrameCallback OK, no конфликтов с твоим Provider.of<CloudStorageProvider>(listen: false) в _connectToYandexDisk (отдельные провайдеры).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<PlantProvider>()
          .initLocation(); // Вызов провайдера — гео один раз, сохраняет в prefs без влияния на UI.
    });
  }

  Future<void> _skip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', true);
      await prefs.setBool('remember_me', _rememberMe); // Сохраняем выбор

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      print('Ошибка при пропуске приветственного экрана: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Произошла ошибка: $e')),
        );
      }
    }
  }

  Future<void> _connectToYandexDisk(ValueNotifier<bool> isLoading) async {
    try {
      isLoading.value = true;
      final cloudProvider =
          Provider.of<CloudStorageProvider>(context, listen: false);
      await cloudProvider.connectToYandexDisk(context);
      if (cloudProvider.isConnected && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_seen_welcome', true);
        await prefs.setBool('remember_me', _rememberMe);
        if (!mounted) return;
        final plantProvider = context.read<PlantProvider>();
        await _syncAfterFirstConnect(plantProvider, cloudProvider);
        if (mounted) {
          // Дополнительная проверка
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения: $e')),
        );
      }
    } finally {
      if (mounted) {
        isLoading.value = false;
      }
    }
  }

  Future<void> _syncAfterFirstConnect(
      PlantProvider plantProvider, CloudStorageProvider cloudProvider) async {
    try {
      await plantProvider.loadPlants();
      await cloudProvider.fetchLastCloudUpdate();

      if (cloudProvider.lastCloudUpdate != null) {
        await cloudProvider.loadDataFromCloud(plantProvider);
        await plantProvider.savePlants();
      } else {
        await cloudProvider.syncData(plantProvider);
      }
    } catch (e) {
      print('❌ Ошибка при синхронизации после подключения: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ValueNotifier<bool>(false);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Добро пожаловать в My Cactus!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Подключите облачное хранилище для синхронизации вашей коллекции кактусов.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ValueListenableBuilder<bool>(
                valueListenable: isLoading,
                builder: (context, loading, child) {
                  return ElevatedButton.icon(
                    onPressed: loading
                        ? null
                        : () async {
                            await _connectToYandexDisk(isLoading);
                          },
                    icon: loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.cloud),
                    label: Text(
                        loading ? 'Подключение...' : 'Подключить Яндекс.Диск'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                  const Text('Запомнить меня'),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _skip,
                child: const Text(
                  'Пропустить',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
