import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/plant.dart';
import 'screens/edit_plant_screen.dart';
import 'providers/cloud_storage_provider.dart';
import 'presentation/providers/providers.dart';
import 'screens/sowing_management_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/collection_management_screen.dart';
import 'screens/batch_qr_creation_screen.dart';
import 'screens/qr_management_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // ←←← ДОБАВЬ ЭТУ СТРОКУ
import 'screens/welcome_screen.dart';
import '../widgets/plant_cards.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../theme/cactus_theme.dart';
import '../utils/responsive_helper.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // ← добавь эту строку
import 'data/datasources/local/hive_database.dart';
import 'data/migrations/data_migration_manager.dart';
import 'injection_container.dart' as di;

enum GroupAction { changeStatus, delete }

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Hive базы данных
  await HiveDatabase.initialize();

  // Инициализация DI-контейнера (зависит от Hive)
  await di.init();

  // Миграция данных из SharedPreferences в Hive (при первом запуске после обновления)
  final migrationSuccess = await DataMigrationManager.runMigrationIfNeeded();
  if (!migrationSuccess) {
    print('⚠️ Миграция данных не удалась. Используем резервный режим.');
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('=== FLUTTER ERROR ===');
    print(details.exception);
    print(details.stack);
  };

  await _initNotifications();
  tz.initializeTimeZones();

if (Platform.isAndroid) {
  const deepLinkChannel = MethodChannel('deep_link');

  deepLinkChannel.setMethodCallHandler((call) async {
    print('=== DEEP LINK CHANNEL CALL === method: ${call.method}, arguments: ${call.arguments}');

    if (call.method == 'deepLink') {
      final String? url = call.arguments as String?;
      if (url != null && url.startsWith('mycactus://')) {
        print('✅ Получен deep link: $url');

        final uri = Uri.parse(url);
        if (uri.scheme == 'mycactus' && uri.host == 'callback') {
          print('✅ Это наш callback от Яндекса!');

          try {
            final context = navigatorKey.currentContext;
            if (context == null || !context.mounted) {
              print('⚠️ Контекст недоступен');
              return;
            }

            final cloudProvider = Provider.of<CloudStorageProvider>(
              context,
              listen: false,
            );
            await cloudProvider.handleDeepLink(uri);
            print('✅ handleDeepLink выполнен успешно');
          } catch (e, stack) {
            print('❌ Ошибка в handleDeepLink: $e');
            print(stack);
          }
        }
      }
    }
    return null;
  });

  print('✅ Метод-канал deep_link зарегистрирован');
}
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlantCrudProvider()),
        ChangeNotifierProvider(create: (_) => CloudStorageProvider()),
        // Новые специализированные провайдеры (шаг 1.10)
        ChangeNotifierProvider(create: (_) => WateringProvider()),
        ChangeNotifierProvider(create: (_) => WinteringProvider()),
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
        ChangeNotifierProvider(create: (_) => BatchProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => QrCodeProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// Обработка возврата из браузера после авторизации Яндекс.Диска

Future<void> _initNotifications() async {
  // Инициализация для Android/Windows (твоя иконка из mipmap/ic_launcher.png в android/app/src/main/res — сохранена для consistency).
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings(
          '@mipmap/ic_launcher'); // Твоя иконка — не меняет, использует существующую.

  const InitializationSettings initializationSettings = InitializationSettings(
    android:
        initializationSettingsAndroid, // Для Windows — auto, без доп. настроек (плагин кросс-платформенный).
  );

  await flutterLocalNotificationsPlugin.initialize(
      initializationSettings); // Базовая инициализация — ждет 1 сек max, не блокирует main().

  // Разрешения для Android 13+ (на Windows — не нужно, работает сразу после init).
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cloudProvider =
        Provider.of<CloudStorageProvider>(context, listen: false);

    return FutureBuilder<Map<String, dynamic>>(
      future: _initializeAndCheckStatus(cloudProvider),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Ошибка запуска:\n${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        final showWelcomeScreen = snapshot.data?['show_welcome'] ?? true;

        if (snapshot.hasData) {
          final data = snapshot.data!;
          final showWelcomeScreen = data['show_welcome'] ?? true;
          final startupMessage = data['startup_message'] as String?;
          final cloudProvider =
              Provider.of<CloudStorageProvider>(context, listen: false);

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;

            final plantCrudProvider =
                Provider.of<PlantCrudProvider>(context, listen: false);
            final qrCodeProvider =
                Provider.of<QrCodeProvider>(context, listen: false);
            final wateringProvider =
                Provider.of<WateringProvider>(context, listen: false);
            final winteringProvider =
                Provider.of<WinteringProvider>(context, listen: false);
            final photoProvider =
                Provider.of<PhotoProvider>(context, listen: false);

            if (cloudProvider.isConnected) {
              print('🔄 Запуск автоматической синхронизации при старте...');
              await _performAutoSync(plantCrudProvider, cloudProvider);
            } else {
              await plantCrudProvider.loadPlants();
            }

            // Загрузка данных для специализированных провайдеров
            await wateringProvider.load();
            await winteringProvider.load();
            await photoProvider.load();
            await qrCodeProvider.loadScanHistory();
            await qrCodeProvider.loadQRCodeFiles();

            if (startupMessage != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(startupMessage),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          });

          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: CactusTheme.light(),
            darkTheme: CactusTheme.dark(),
            themeMode: ThemeMode.system,
            home:
                showWelcomeScreen ? const WelcomeScreen() : const HomeScreen(),
          );
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: CactusTheme.light(),
          darkTheme: CactusTheme.dark(),
          themeMode: ThemeMode.system,
          home: showWelcomeScreen ? const WelcomeScreen() : const HomeScreen(),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _initializeAndCheckStatus(
      CloudStorageProvider cloudProvider) async {
    final prefs = await SharedPreferences.getInstance();
    String? startupMessage;

    // Загружаем учётные данные
    try {
      await cloudProvider.loadCredentials();
      // После await cloudProvider.loadCredentials();
      if (Platform.isAndroid) {
        // Можно добавить обработчик deep link, если используешь go_router или uni_links
        // Пока достаточно текущей логики
      }
    } catch (e) {
      print('Ошибка загрузки учётных данных: $e');
      cloudProvider.disconnect();
    }

    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
    final rememberMe = prefs.getBool('remember_me') ?? false;

    // Тихое подключение, если пользователь выбрал "Запомнить меня"
    if (rememberMe && !cloudProvider.isConnected) {
      print('Попытка тихого подключения к Яндекс.Диску...');
      try {
        await cloudProvider.connectToYandexDiskSilently();
      } catch (e) {
        print('Тихое подключение не удалось: $e');
        startupMessage =
            'Переподключение к Яндекс.Диску не удалось. Работаем локально.';
      }
      if (!cloudProvider.isConnected) {
        startupMessage =
            'Переподключение к Яндекс.Диску не удалось. Работаем локально.';
      }
    }

    // Показываем WelcomeScreen только если:
    // - пользователь ещё не видел его ИЛИ
    // - не включено "Запомнить меня" И диск не подключён
    final showWelcomeScreen =
        !hasSeenWelcome || (!rememberMe && !cloudProvider.isConnected);

    return {
      'show_welcome': showWelcomeScreen,
      'remember_me': rememberMe,
      'is_connected': cloudProvider.isConnected,
      'startup_message': startupMessage,
    };
  }

  Future<void> _performAutoSync(
      PlantCrudProvider plantCrudProvider, CloudStorageProvider cloudProvider) async {
    try {
      print('🔄 Запуск автоматической синхронизации при старте приложения...');

      // 1. Сначала всегда загружаем локальные данные
      await plantCrudProvider.loadPlants();

      if (!cloudProvider.isConnected) {
        print(
            '☁️ Яндекс.Диск не подключён — работаем только с локальными данными');
        return;
      }

      //    (внутри уже есть: бэкап → сравнение lastLocalUpdate / lastCloudUpdate → upload или load)
      await cloudProvider.syncData(plantCrudProvider);

      print('✅ Автоматическая синхронизация успешно завершена');
    } catch (e) {
      print('❌ Ошибка автоматической синхронизации при запуске: $e');
      // Не показываем ошибку пользователю при автозапуске — только логи
      // Пользователь увидит уведомления только при ручной синхронизации
    }
  }
}

// Остальной код (HomeScreen, PlantCards, AddPlantForm) остаётся без изменений

class HomeScreen extends StatefulWidget {
  final List<Plant>? initialFilter;

  const HomeScreen({super.key, this.initialFilter});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _addController;
  String _currentFilter = 'all';
  // bool _isSearching = false;   // больше не используется
  String _sortColumn = 'latinName';
  bool _isAscending = true;
  // bool _isSearching = false;   // закомментировано — больше не используется
  String? _selectedSowingYear;
  // === Поиск ===
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // История поиска (последние 5 запросов)
  List<String> _searchHistory = [];
  static const String _searchHistoryKey = 'search_history';

  // === КЭШ СЕЗОННОГО СОВЕТА (п.2.2) ===
  String? _cachedSeasonalTip;
  int? _cachedSeasonalTipHash;

  @override
  void initState() {
    super.initState();
    _addController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _loadSearchHistory(); // Загружаем историю поиска

    context.read<PlantCrudProvider>().loadPlants();

    if (widget.initialFilter != null) {
      _currentFilter = 'custom_filter';
      context.read<PlantCrudProvider>().clearSelections();
      context
          .read<PlantCrudProvider>()
          .selectAll(widget.initialFilter!.map((p) => p.permanentId).toList());
    }
  }

  @override
  void dispose() {
    _addController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    String? onTapFilter,
  }) {
    final isMobile = Responsive.isMobile(context);

    return InkWell(
      onTap: onTapFilter != null
          ? () => setState(() => _currentFilter = onTapFilter)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: color.withValues(alpha: 0.09),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: isMobile ? 19 : 21),
              const SizedBox(height: 3),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: isMobile ? 15 : 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 9.5 : 10.5,
                  color: color.withValues(alpha: 0.75),
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final provider = context.watch<PlantCrudProvider>();
    final plants = provider.plants;
    // Всего растений на главном экране (без сеянцев)
    final mainPlants = plants.where((p) => p.parentId == null).toList();
    final total = mainPlants.length;
    // Сеянцы (растения с parentId)
    final seedlingsCount = plants.where((p) => p.parentId != null).length;
    // Витрины-партии
    final batchesCount = plants.where((p) => p.isBatch).length;
    final inCollectionCount =
        mainPlants.where((p) => p.status == 'in_collection').length;
    final sownInCollection = mainPlants
        .where((p) => p.category == 'sown' && p.status == 'in_collection')
        .length;
    final purchasedInCollection = mainPlants
        .where((p) => p.category == 'purchased' && p.status == 'in_collection')
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 5,
        alignment: WrapAlignment.spaceEvenly,
        children: [
          _buildStatCard(
            icon: Icons.all_inclusive,
            title: 'Все',
            count: total,
            color: Colors.grey,
            onTapFilter: 'all',
          ),
          _buildStatCard(
            icon: Icons.collections,
            title: 'Коллекция',
            count: inCollectionCount,
            color: Colors.green,
            onTapFilter: 'in_collection',
          ),
          _buildStatCard(
            icon: Icons.spa,
            title: 'Семена',
            count: sownInCollection,
            color: Colors.orange,
            onTapFilter: 'sown_in_collection',
          ),
          _buildStatCard(
            icon: Icons.shopping_cart,
            title: 'Покупка',
            count: purchasedInCollection,
            color: Colors.blue,
            onTapFilter: 'purchased_in_collection',
          ),
          if (seedlingsCount > 0)
            _buildStatCard(
              icon: Icons.spa,
              title: 'Сеянцы',
              count: seedlingsCount,
              color: Colors.teal,
              onTapFilter: null,
            ),
          if (batchesCount > 0)
            _buildStatCard(
              icon: Icons.group,
              title: 'Партий',
              count: batchesCount,
              color: Colors.indigo,
              onTapFilter: null,
            ),
        ],
      ),
    );
  }

  String _getSeasonalTip() {
    final month = DateTime.now().month;
    final provider = Provider.of<PlantCrudProvider>(context, listen: false);
    final plants = provider.plants;
    final sownCount = plants.where((p) => p.category == 'sown').length;
    final purchasedCount = plants.where((p) => p.category == 'purchased').length;
    final currentHash = Object.hash(month, sownCount, purchasedCount);

    if (_cachedSeasonalTip != null && _cachedSeasonalTipHash == currentHash) {
      return _cachedSeasonalTip!;
    }

    final isMostlySown = sownCount > purchasedCount;

    String baseTip;
    switch (month) {
      case 1:
        baseTip =
            'Январь: Кактусы в покое — не поливайте, держите прохладу 5-13°C, проверьте на сухость корней.';
      case 2:
        baseTip =
            'Февраль: Подготовка к весне — слегка опрыскайте, если сухо, но полив ещё не начинайте.';
      case 3:
        baseTip =
            'Март: Опрыскайте кактусы тёплой водой, через неделю — первый скудный полив для пробуждения.';
      case 4:
        baseTip =
            'Апрель: Увеличьте свет, полив 1 раз в 2 недели, следите за новыми ростками.';
      case 5:
        baseTip =
            'Май: Летний режим — полив 1 раз в неделю, удобрите слабым раствором для роста.';
      case 6:
        baseTip =
            'Июнь: Жаркий период — полив чаще, но без застоя воды, проверьте на вредителей.';
      case 7:
        baseTip =
            'Июль: Пиковый рост — полив 1-2 раза в неделю, обеспечьте хорошую вентиляцию.';
      case 8:
        baseTip =
            'Август: Сокращайте полив постепенно, готовьте к осени, осматривайте растения.';
      case 9:
        baseTip =
            'Сентябрь: Сократите полив для подготовки к зимовке — избегайте гнили у корней.';
      case 10:
        baseTip =
            'Октябрь: Переставьте в прохладу, полив минимальный, уберите удобрения.';
      case 11:
        baseTip =
            'Ноябрь: Кактусы в покое — полив только если сухо, температура 5-13°C.';
      case 12:
        baseTip =
            'Декабрь: Полный покой — без полива, прохладное место, проверьте на плесень.';
      default:
        baseTip = 'Следуйте графику: 1 полив/2 недели летом — проверьте дату.';
    }

    final result = isMostlySown
        ? 'Для посевов: $baseTip (молодые растения нуждаются в осторожности).'
        : 'Для купленных: $baseTip (взрослые кактусы устойчивее к ошибкам).';

    _cachedSeasonalTip = result;
    _cachedSeasonalTipHash = currentHash;
    return result;
  }

  void _openEditForm(Plant plant) async {
    final result = await Navigator.push<Plant>(
      context,
      MaterialPageRoute(builder: (ctx) => EditPlantScreen(plant: plant)),
    );
    if (result != null && mounted) {
      context.read<PlantCrudProvider>().updatePlant(plant.permanentId, result);
    }
  }

/*
  int _getNextNumber(int year, String category) {
    final plants = context.read<PlantCrudProvider>().plants;
    final numbers = plants
        .where((p) => p.category == category && p.year == year)
        .map((p) => p.customNumber)
        .toList();
    return numbers.isEmpty ? 1 : numbers.reduce((a, b) => a > b ? a : b) + 1;
  }
  */
/*
  bool _isNumberUnique(int year, int number, String category,
      {String? excludeId}) {
    final plants = context.read<PlantCrudProvider>().plants;
    return !plants.any((p) =>
        p.category == category &&
        p.year == year &&
        p.customNumber == number &&
        p.permanentId != excludeId);
  }
  */
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantCrudProvider>();
    final isMobile = Responsive.isMobile(context);

    // Сначала фильтруем: не показываем сеянцы (parentId != null)
    // и применяем текущий фильтр
    var filteredPlants = provider.plants.where((p) {
      // Исключаем всех детей (сеянцев с parentId)
      if (p.parentId != null) return false;

      if (_currentFilter == 'all') return true;
      if (_currentFilter == 'growing') return p.status == 'growing';
      if (_currentFilter == 'purchased') return p.category == 'purchased';
      if (_currentFilter == 'in_collection') return p.status == 'in_collection';
      if (_currentFilter == 'sown_in_collection') {
        return p.category == 'sown' && p.status == 'in_collection';
      }
      if (_currentFilter == 'purchased_in_collection') {
        return p.category == 'purchased' && p.status == 'in_collection';
      }
      if (_currentFilter == 'sown_by_year' && _selectedSowingYear != null) {
        return p.category == 'sown' && p.year.toString() == _selectedSowingYear;
      }
      return true;
    }).toList();

    // Применяем поиск (live search)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredPlants = filteredPlants.where((p) {
        return p.latinName.toLowerCase().contains(query) ||
            p.displayId.toLowerCase().contains(query) ||
            p.year.toString().contains(query);
      }).toList();
    }

    // Затем сортируем
    filteredPlants.sort((a, b) {
      int compare;
      switch (_sortColumn) {
        case 'latinName':
          compare =
              a.latinName.toLowerCase().compareTo(b.latinName.toLowerCase());
          break;
        case 'status':
          compare = a.status.compareTo(b.status);
          break;
        case 'year':
          compare = a.year.compareTo(b.year);
          break;
        case 'category':
          compare = a.category.compareTo(b.category);
          break;
        default:
          compare = 0;
      }
      return _isAscending ? compare : -compare;
    });

    // Применяем поиск
    filteredPlants = filteredPlants
        .where((p) =>
            p.latinName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.displayId.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.black87, // ← Главное исправление (было белым)
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Поиск по названию, ID или году...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.green, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.green, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.green, width: 2.0),
                  ),
                  filled: true,
                  fillColor: Colors.white, // чёткий белый фон
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                onSubmitted: (value) {
                  _addToSearchHistory(value);
                },
              )
            : const Text('Моя коллекция кактусов'),
        actions: [
          // Кнопка поиска
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),

          // Кнопка подключения Яндекс.Диска (новая)
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Подключить Яндекс.Диск',
            onPressed: () async {
              final cloudProvider = context.read<CloudStorageProvider>();
              if (cloudProvider.isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Яндекс.Диск уже подключён')),
                );
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Открываем страницу авторизации...')),
              );

              await cloudProvider.connectToYandexDisk(context);
            },
          ),

          // Кнопка погоды (остаётся)
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.cloud),
              onPressed: () => _connectWeather(context),
            ),
          // === МЕНЮ ДЛЯ ВЫБРАННЫХ РАСТЕНИЙ (три точки) ===
          Consumer<PlantCrudProvider>(
            builder: (context, provider, child) {
              if (provider.selectedIds.isEmpty) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Действия с выбранными растениями',
                onSelected: (value) async {
                  final selectedIds = Set<String>.from(provider.selectedIds);
                  if (selectedIds.isEmpty) return;

                  if (value == 'create_qr_codes') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const BatchQRCreationScreen(),
                      ),
                    );
                  } else if (value == 'cleanup_old') {
                    await provider.cleanupUnusedPhotosForSelected(
                        selectedIds, context);
                  } else if (value == 'delete_all_photos') {
                    await provider.deleteAllPhotosForSelected(
                        selectedIds, context);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'create_qr_codes',
                    child: Text('📱 Создать QR-коды для выбранных'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'cleanup_old',
                    child: Text('🗑 Удалить старые (неиспользуемые) фото'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete_all_photos',
                    child: Text('🗑 Удалить ВСЕ фото у выбранных'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: isMobile ? _buildDrawer() : null, // Drawer на мобильных
      body: SafeArea(
        child: Column(
          children: [
            // Компактный сезонный совет
            Card(
              elevation: 1,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Padding(
                padding: EdgeInsets.all(Responsive.defaultPadding(context)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getSeasonalTip(),
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildStatsRow(),

            Expanded(
              child: PlantCards(
                plants: filteredPlants
                    .where((p) =>
                        p.latinName
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ||
                        p.displayId
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                    .toList(),
                sortColumn: _sortColumn,
                isAscending: _isAscending,
                onSort: (column) => setState(() {
                  if (_sortColumn == column) {
                    _isAscending = !_isAscending;
                  } else {
                    _sortColumn = column;
                    _isAscending = true;
                  }
                }),
                onEdit: _openEditForm,
                onUpdate: (id, plant) => provider.updatePlant(id, plant),
                onDelete: (id) => provider.deletePlant(id),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavigationBar() : null,
    );
  }

  void _navigateToSowingManagement() {
    Navigator.push(context,
        MaterialPageRoute(builder: (ctx) => const SowingManagementScreen()));
  }

  void _navigateToCollectionManagement() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (ctx) => const CollectionManagementScreen()));
  }

  Future<void> _connectWeather(BuildContext context) async {
    // Сохраняем контекст в начале — это важно
    final currentContext = context;
    final provider = currentContext.read<WeatherProvider>();

    try {
      await provider.initLocation();
      if (!currentContext.mounted) {
        return; // проверка через сохранённый контекст
      }

      final prefs = await SharedPreferences.getInstance();
      if (!currentContext.mounted) {
        return;
      }

      if (prefs.getDouble('lat') == null) {
        final city = await _showCityDialog(currentContext);
        if (!currentContext.mounted) {
          return;
        }

        if (city != null && city.isNotEmpty) {
          await provider.setCity(city);
          if (!currentContext.mounted) {
            return;
          }

          _showSnackBar(
              currentContext, 'Город "$city" сохранён! Погода обновится.');
        }
      } else {
        if (!currentContext.mounted) {
          return;
        }
        _showSnackBar(currentContext,
            'Геолокация подключена! Погода обновится в календаре.');
      }
    } catch (e) {
      if (!currentContext.mounted) {
        return;
      }
      _showSnackBar(currentContext, 'Ошибка подключения погоды: $e');
    }
  }

  Future<String?> _showCityDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Введите город для погоды'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Например, Москва',
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(ctx, value.trim());
                } else {
                  Navigator.pop(ctx);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  final inputCity = controller.text.trim();
                  if (inputCity.isNotEmpty) {
                    Navigator.pop(ctx, inputCity);
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Нижняя навигация: "Растут" + "Синхронизировать" + "QR-скан" + "Выход"
  Widget _buildBottomNavigationBar() {
    final cloudProvider = context.watch<CloudStorageProvider>();

    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      onTap: (index) async {
        if (index == 0) {
          // Растут
          setState(() {
            _currentFilter = 'growing';
            _selectedSowingYear = null;
          });
        } else if (index == 1) {
          // Синхронизировать
          if (cloudProvider.isSyncing) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Синхронизация уже выполняется...'),
              ),
            );
          } else {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Синхронизация'),
                content: const Text(
                    'Загрузить данные с Яндекс.Диска?\n\nЭто перезапишет локальные изменения.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Отмена'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Загрузить'),
                  ),
                ],
              ),
            );
            if (confirmed == true && mounted) {
              cloudProvider.loadFromCloud(context);
            }
          }
        } else if (index == 2) {
          // Сканировать QR
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => const QRScannerScreen(),
            ),
          );
        } else if (index == 3) {
          // Выход
          _showExitDialog();
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.grass),
          label: 'Растут',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sync),
          label: 'Синхр.',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner),
          label: 'QR',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.exit_to_app),
          label: 'Выход',
        ),
      ],
    );
  }

  // Диалог выхода с сохранением
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход из приложения'),
        content: const Text('Сохранить все изменения перед выходом?\n\n'
            'Да — сохранить локально и в облако\n'
            'Нет — выйти без сохранения'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // Отмена
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _exitWithoutSaving();
            },
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveAndExit();
            },
            child: const Text('Да, сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndExit() async {
    final plantCrudProvider = context.read<PlantCrudProvider>();
    final cloudProvider = context.read<CloudStorageProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Сохранение данных...')),
    );

    try {
      await plantCrudProvider.savePlants();

      if (cloudProvider.isConnected) {
        await cloudProvider.syncData(plantCrudProvider);
      }

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Данные сохранены. Выход...'),
          backgroundColor: Colors.green,
        ),
      );

      // Небольшая задержка, чтобы пользователь увидел сообщение
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        SystemNavigator.pop(); // Выход из приложения
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exitWithoutSaving() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Выход без сохранения...')),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        SystemNavigator.pop();
      }
    });
  }

  // Drawer для дополнительных пунктов на мобильных
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.green),
            child: Text('Меню',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),

          // === НОВАЯ КНОПКА: Принудительно обновить из облака ===
          ListTile(
            leading: const Icon(Icons.cloud_download, color: Colors.blue),
            title: const Text('Принудительно обновить из облака'),
            subtitle: const Text('Скачать свежие данные с Яндекс.Диска'),
            onTap: () async {
              Navigator.pop(context); // закрываем меню

              final cloudProvider = context.read<CloudStorageProvider>();
              final plantCrudProvider = context.read<PlantCrudProvider>();
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              if (!cloudProvider.isConnected) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                      content: Text('Сначала подключите Яндекс.Диск')),
                );
                return;
              }

              try {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                      content: Text('⏳ Загружаем данные из облака...')),
                );

                await cloudProvider.fetchLastCloudUpdate();
                await cloudProvider.loadDataFromCloud(plantCrudProvider);
                await plantCrudProvider.savePlants();

                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content:
                        Text('✅ Данные успешно загружены из Яндекс.Диска!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('❌ Ошибка загрузки: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.qr_code_2, color: Colors.blue),
            title: const Text('Управление QR-кодами'),
            subtitle: const Text('Файлы и растения'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const QRManagementScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.qr_code_2, color: Colors.orange),
            title: const Text('Только без QR кодов'),
            subtitle: const Text('Показать растения без этикеток'),
            onTap: () {
              Navigator.pop(context);
              // Устанавливаем фильтр на растения без QR кодов
              final provider = context.read<PlantCrudProvider>();
              provider.clearSelections();
              final plantsWithoutQR = provider.getPlantsWithoutQRCode();
              for (var plant in plantsWithoutQR) {
                provider.toggleSelection(plant.permanentId);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Выбрано растений без QR: ${plantsWithoutQR.length}')),
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.agriculture),
            title: const Text('Управление посевами'),
            onTap: () {
              Navigator.pop(context);
              _navigateToSowingManagement();
            },
          ),
          ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('Фильтр по году посева'),
            onTap: () {
              Navigator.pop(context);
              _showSowingYearFilter();
            },
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Управление коллекцией'),
            onTap: () {
              Navigator.pop(context);
              _navigateToCollectionManagement();
            },
          ),
          ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('Статистика'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const StatisticsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSowingYearFilter() {
    final provider = context.read<PlantCrudProvider>();
    final years = provider.plants
        .where((p) => p.category == 'sown')
        .map((p) => p.year.toString())
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // от новых к старым

    if (years.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет посевов для фильтрации')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите год посева'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: years.length,
            itemBuilder: (ctx, index) {
              final year = years[index];
              final count = provider.plants
                  .where(
                      (p) => p.category == 'sown' && p.year.toString() == year)
                  .length;
              return ListTile(
                title: Text(year),
                trailing: Text('$count шт.',
                    style: const TextStyle(color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedSowingYear = year;
                    _currentFilter = 'sown_by_year';
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedSowingYear = null);
            },
            child: const Text('Сбросить фильтр'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  // Загрузка истории поиска
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_searchHistoryKey) ?? [];
    setState(() {
      _searchHistory = history;
    });
  }

  // Сохранение истории поиска (максимум 5 последних)
  Future<void> _saveSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryKey, _searchHistory);
  }

  // Добавление запроса в историю
  void _addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;

    setState(() {
      _searchHistory.remove(query); // убираем дубликат, если был
      _searchHistory.insert(0, query);

      if (_searchHistory.length > 5) {
        _searchHistory.removeLast();
      }
    });

    _saveSearchHistory();
  }
}

class AddPlantForm extends StatefulWidget {
  final int Function(int year, String category) getNextNumber;
  final bool Function(int year, int number, String category,
      {String? excludeId}) isNumberUnique;

  const AddPlantForm(
      {super.key, required this.getNextNumber, required this.isNumberUnique});

  @override
  State<AddPlantForm> createState() => _AddPlantFormState();
}

class _AddPlantFormState extends State<AddPlantForm> {
  final _formKey = GlobalKey<FormState>();
  final _latinNameController = TextEditingController();
  final _yearController = TextEditingController();
  final _numberController = TextEditingController();
  final String _status = 'sown';
  String _category = 'sown';

  @override
  void initState() {
    super.initState();
    _updateNumber();
  }

  void _updateNumber() {
    final year = int.tryParse(_yearController.text);
    if (year != null) {
      _numberController.text = widget.getNextNumber(year, _category).toString();
    }
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return 'Обязательное поле';
    final number = int.tryParse(value);
    if (number == null) return 'Введите число';
    final year = int.tryParse(_yearController.text);
    if (year == null) return 'Сначала укажите год';
    return widget.isNumberUnique(year, number, _category)
        ? null
        : 'Номер должен быть уникальным';
  }

  void _showYearPicker() async {
    final year = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: SizedBox(
          width: 300,
          height: 400,
          child: ListView.builder(
            itemCount: 50,
            itemBuilder: (ctx, i) {
              final year = DateTime.now().year - i;
              return ListTile(
                title: Text(year.toString()),
                onTap: () => Navigator.pop(
                    ctx, year), // Возвращаем год только для диалога
              );
            },
          ),
        ),
      ),
    );
    if (year != null && mounted) {
      setState(() {
        _yearController.text = year.toString();
        _updateNumber();
      });
    }
  }

  void _saveForm() {
    if (_formKey.currentState!.validate()) {
      try {
        final newPlant = Plant(
          latinName: _latinNameController.text.trim(),
          status: _status,
          year: int.parse(_yearController.text),
          customNumber: int.parse(_numberController.text),
          category: _category,
        );
        print('Добавлено растение: ${newPlant.latinName}');
        Navigator.pop(context, newPlant);
      } catch (e) {
        print('Ошибка в _saveForm: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить растение')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Купленное растение'),
                value: _category == 'purchased',
                onChanged: (value) => setState(() {
                  _category = value ? 'purchased' : 'sown';
                  _updateNumber();
                }),
                activeThumbColor: Colors.green,
              ),
              TextFormField(
                controller: _latinNameController,
                decoration: const InputDecoration(
                  labelText: 'Латинское название*',
                  hintText: 'Пример: Gymnocalycium bayrianum',
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Обязательное поле'
                    : (value.split(' ').length < 2
                        ? 'Укажите род и вид'
                        : null),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _yearController,
                decoration: InputDecoration(
                  labelText:
                      _category == 'purchased' ? 'Год покупки*' : 'Год посева*',
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _showYearPicker),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Обязательное поле'
                    : (int.tryParse(value) == null ? 'Некорректный год' : null),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                    labelText: 'Номер растения*',
                    hintText: 'Пример: 3 → ID: 23-003'),
                keyboardType: TextInputType.number,
                validator: _validateNumber,
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Добавить'),
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

