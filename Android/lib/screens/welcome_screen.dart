import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../presentation/providers/cloud_storage_provider.dart';
import '../main.dart';
import '../presentation/providers/providers.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  WelcomeScreenState createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherProvider>().initLocation();
    });
  }

  Future<void> _skip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_welcome', true);
      await prefs.setBool('remember_me', _rememberMe);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      debugPrint('Ошибка при пропуске: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _connectToYandexDisk(ValueNotifier<bool> isLoading) async {
    try {
      isLoading.value = true;

      final cloudProvider =
          Provider.of<CloudStorageProvider>(context, listen: false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Открываем браузер для авторизации...\nПосле авторизации закройте браузер и вернитесь в приложение',),
            duration: Duration(seconds: 6),
          ),
        );
      }

      await cloudProvider.connectToYandexDisk(context);

      // Даём системе время обработать deep link
      if (mounted) {
        await Future.delayed(const Duration(seconds: 3));
      }

      if (!mounted) return;

      if (cloudProvider.isConnected) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_seen_welcome', true);
        await prefs.setBool('remember_me', _rememberMe);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Авторизация успешна! Начинаем синхронизацию...'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (!mounted) return;
        final plantCrudProvider = context.read<PlantCrudProvider>();
        await _syncAfterFirstConnect(plantCrudProvider, cloudProvider);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось подключиться. Попробуйте ещё раз.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Критическая ошибка авторизации: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) isLoading.value = false;
    }
  }

  // Безопасная синхронизация после первого подключения
  Future<void> _syncAfterFirstConnect(
      PlantCrudProvider plantCrudProvider, CloudStorageProvider cloudProvider,) async {
    try {
      debugPrint('📥 Загружаем данные из Яндекс.Диска...');

      await plantCrudProvider.loadPlants();
      await cloudProvider.fetchLastCloudUpdate();

      if (cloudProvider.lastCloudUpdate != null) {
        await cloudProvider.loadDataFromCloud(plantCrudProvider);
        await plantCrudProvider.savePlants();
        debugPrint('✅ Данные успешно загружены из облака');
      } else {
        debugPrint('⚠️ В облаке пока нет данных, сохраняем локальные...');
        await cloudProvider.syncData(plantCrudProvider);
      }
    } catch (e) {
      debugPrint('❌ Ошибка при синхронизации после подключения: $e');
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
                        loading ? 'Подключение...' : 'Подключить Яндекс.Диск',),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12,),
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

