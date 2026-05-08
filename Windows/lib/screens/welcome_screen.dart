import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/cloud_storage_provider.dart';
import '../main.dart'; // Импортируем main.dart, где находится HomeScreen
import '../providers/plant_provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  WelcomeScreenState createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  bool _rememberMe = false; // Переменная для чекбокса

  @override
  void initState() {
    super.initState(); // Базовый вызов — стандартный для StatefulWidget.

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
