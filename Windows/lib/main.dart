import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'models/plant.dart';
import 'screens/edit_plant_screen.dart';
import 'presentation/providers/cloud_storage_provider.dart';
import 'presentation/providers/providers.dart';
import 'screens/sowing_management_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/qr_management_screen.dart';
import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'screens/collection_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import '../widgets/plant_cards.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../theme/cactus_theme.dart';
import 'data/datasources/local/hive_database.dart';
import 'data/migrations/data_migration_manager.dart';
import 'injection_container.dart' as di;

enum GroupAction { changeStatus, delete }

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

  await _initNotifications();

  tz.initializeTimeZones();

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
      child: MaterialApp(
        // Перенесите MaterialApp сюда
        debugShowCheckedModeBanner: false,
        home: MyApp(), // MyApp теперь внутри MaterialApp
      ),
    ),
  );
}

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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cloudProvider =
        Provider.of<CloudStorageProvider>(context, listen: false);

    return FutureBuilder<Map<String, dynamic>>(
      future: _initializeAndCheckStatus(cloudProvider),
      builder: (context, snapshot) {
        // Сохранено: Временный MaterialApp для loading — не меняется, работает как раньше (CircularProgressIndicator).
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final showWelcomeScreen = snapshot.data?['show_welcome'] ?? true;
        final startupMessage = snapshot.data?['startup_message'] as String?;

        // Загрузка данных после первого фрейма
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final plantCrudProvider =
              Provider.of<PlantCrudProvider>(context, listen: false);
          final wateringProvider =
              Provider.of<WateringProvider>(context, listen: false);
          final winteringProvider =
              Provider.of<WinteringProvider>(context, listen: false);
          final photoProvider =
              Provider.of<PhotoProvider>(context, listen: false);
          final qrCodeProvider =
              Provider.of<QrCodeProvider>(context, listen: false);

          await _syncData(plantCrudProvider, cloudProvider);

          // Параллельная загрузка специализированных провайдеров
          await Future.wait([
            wateringProvider.load(),
            winteringProvider.load(),
            photoProvider.load(),
            qrCodeProvider.loadScanHistory(),
            qrCodeProvider.loadQRCodeFiles(),
          ]);

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
          navigatorKey:
              navigatorKey, // Сохранено: Ваш ключ для SnackBar и навигации — не меняется, работает как раньше.
          debugShowCheckedModeBanner: false, // Сохранено: Без баннера отладки.
          theme: CactusTheme.light(),
          darkTheme: CactusTheme.dark(),
          themeMode: ThemeMode
              .system,
          home: showWelcomeScreen
              ? const WelcomeScreen()
              : const HomeScreen(), // Сохранено: Ваша логика показа экранов — не меняется.
        );
      }, // Исправлено: Закрывающая скобка для builder — фиксирует синтаксис (expected ';').
    ); // Исправлено: Закрывающая скобка для FutureBuilder — фиксирует unexpected token и missing identifier.
  }

  Future<Map<String, dynamic>> _initializeAndCheckStatus(
      CloudStorageProvider cloudProvider) async {
    final prefs = await SharedPreferences.getInstance();
    String? startupMessage;

    await cloudProvider.loadCredentials();

    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && !cloudProvider.isConnected) {
      try {
        await cloudProvider.connectToYandexDiskSilently();
      } catch (e) {
        startupMessage = 'Переподключение к Яндекс.Диску не удалось. Работаем локально.';
      }
      if (!cloudProvider.isConnected) {
        startupMessage = 'Переподключение к Яндекс.Диску не удалось. Работаем локально.';
      }
    }

    final showWelcomeScreen =
        !hasSeenWelcome || (!rememberMe && !cloudProvider.isConnected);

    return {
      'show_welcome': showWelcomeScreen,
      'remember_me': prefs.getBool('remember_me') ?? false,
      'is_connected': cloudProvider.isConnected,
      'startup_message': startupMessage,
    };
  }

  Future<void> _syncData(
      PlantCrudProvider plantCrudProvider, CloudStorageProvider cloudProvider) async {
    await plantCrudProvider.loadPlants();
    if (!cloudProvider.isConnected) {
      print('Нет подключения к облаку, синхронизация пропущена');
      return;
    }
    await cloudProvider.fetchLastCloudUpdate();
    final localUpdate = plantCrudProvider.lastLocalUpdate;
    final cloudUpdate = cloudProvider.lastCloudUpdate;
    print('Локальное обновление: $localUpdate');
    print('Облачное обновление: $cloudUpdate');
    if (localUpdate == null && cloudUpdate == null) {
      print('Оба хранилища пусты, синхронизация не требуется');
      return;
    }
    if (plantCrudProvider.plants.isEmpty && cloudUpdate != null) {
      print('Локальные данные пусты, загружаем из облака');
      await cloudProvider.loadDataFromCloud(plantCrudProvider);
      await plantCrudProvider.savePlants();
    } else if (cloudUpdate == null ||
        (localUpdate != null && localUpdate.isAfter(cloudUpdate))) {
      print('Локальные данные новее или облако пусто, синхронизируем в облако');
      await cloudProvider.syncData(plantCrudProvider);
    } else if (localUpdate == null || cloudUpdate.isAfter(localUpdate)) {
      print('Облачные данные новее или локальные пусты, загружаем из облака');
      await cloudProvider.loadDataFromCloud(plantCrudProvider);
      await plantCrudProvider.savePlants();
    } else {
      print('Данные синхронизированы, ничего не требуется');
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
  bool _isSownExpanded = false;
  String _sortColumn = 'latinName';
  bool _isAscending = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _cachedSeasonalTip;
  int? _cachedSeasonalTipHash;

  @override
  void initState() {
    super.initState();
    _addController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
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
    String?
        onTapFilter, // Новый param: onTapFilter для setState _currentFilter (e.g., 'in_collection' for tap).
  }) {
    return InkWell(
      onTap: onTapFilter != null
          ? () => setState(() => _currentFilter = onTapFilter)
          : null,
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(title,
                      style: TextStyle(
                          fontSize: 14, color: color.withValues(alpha: 0.8))),
                ],
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
        mainPlants.where((p) => p.status == PlantStatus.inCollection).length;
    final sownInCollection = mainPlants
        .where((p) => p.category == PlantCategory.sown && p.status == PlantStatus.inCollection)
        .length;
    final purchasedInCollection = mainPlants
        .where((p) => p.category == PlantCategory.purchased && p.status == PlantStatus.inCollection)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildStatCard(
              icon: Icons.all_inclusive,
              title: 'Всего',
              count: total,
              color: Colors.grey,
              onTapFilter:
                  'all'),
          _buildStatCard(
              icon: Icons.collections,
              title: 'В коллекции',
              count: inCollectionCount,
              color: Colors.green,
              onTapFilter:
                  'in_collection'), // Обновлён: onTapFilter 'in_collection' (instead of if title).
          _buildStatCard(
              icon: Icons.spa,
              title: 'Выращено из семян',
              count: sownInCollection,
              color: Colors.orange,
              onTapFilter:
                  'sown_in_collection'), // Обновлён: onTapFilter 'sown_in_collection'.
          _buildStatCard(
              icon: Icons.shopping_cart,
              title: 'Купленные',
              count: purchasedInCollection,
              color: Colors.blue,
              onTapFilter:
                  'purchased_in_collection'), // Обновлён: onTapFilter 'purchased_in_collection'.
          if (seedlingsCount > 0)
            _buildStatCard(
                icon: Icons.spa,
                title: 'Сеянцы',
                count: seedlingsCount,
                color: Colors.teal,
                onTapFilter: null), // Сеянцы не кликабельны - они не на главном экране
          if (batchesCount > 0)
            _buildStatCard(
                icon: Icons.group,
                title: 'Партий',
                count: batchesCount,
                color: Colors.indigo,
                onTapFilter: null), // Партии не кликабельны отдельно
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

  Widget _buildNavigationRail() {
    final provider = context.watch<PlantCrudProvider>();
    final years = provider.plants
        .where((p) => p.category == 'sown')
        .map((p) => p.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        NavigationRail(
          selectedIndex: _getSelectedIndex(),
          onDestinationSelected: (index) {
            if (index == 3) {
              _navigateToSowingManagement();
            } else if (index == 4) {
              _navigateToCollectionManagement();
            } else if (index == 5) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const StatisticsScreen()),
              );
            } else if (index == 6) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const QRManagementScreen()),
              );
            } else if (index == 7) {
              final provider = context.read<PlantCrudProvider>();
              provider.clearSelections();
              final plantsWithoutQR = provider.getPlantsWithoutQRCode();
              for (var plant in plantsWithoutQR) {
                provider.toggleSelection(plant.permanentId);
              }
              setState(() {
                _currentFilter = 'all';
                _isSownExpanded = false;
              });
            } else if (index == 8) {
              setState(() {
                _isSownExpanded = !_isSownExpanded;
              });
            } else {
              final filters = ['all', 'growing', 'purchased'];
              setState(() {
                _currentFilter = filters[index];
                _isSownExpanded = false;
              });
            }
          },
          labelType: NavigationRailLabelType.all,
          backgroundColor: Colors.grey.shade50,
          selectedIconTheme: const IconThemeData(color: Colors.green),
          unselectedIconTheme: const IconThemeData(color: Colors.black54),
          selectedLabelTextStyle:
              const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          unselectedLabelTextStyle: const TextStyle(color: Colors.black87),
          destinations: [
            const NavigationRailDestination(
              icon: Icon(Icons.all_inclusive),
              label: Text('Все'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.grass),
              label: Text('Растут'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.shopping_cart),
              label: Text('Купленные'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.agriculture),
              label: Text('Управление посевами'),
            ),
            NavigationRailDestination(
              icon: Stack(
                children: [
                  const Icon(Icons.event),
                  if (provider.hasUnreadNotifications)
                    Positioned(
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: const Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: const Text('Управление коллекцией'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.analytics),
              label: Text('Статистика'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.qr_code_2),
              label: Text('Управление QR'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.qr_code_outlined),
              label: Text('Без QR'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.grass),
              label: Text('Посевы'),
            ),
          ],
        ),
        if (_isSownExpanded)
          Positioned(
            left: 32,
            top: (6 * 72) +
                32, // Индекс "Посевы" = 6, высота кнопки ≈ 72, отступ = 25
            child: Material(
              elevation: 4,
              child: Container(
                width: 100, // Увеличена ширина для читаемости
                height: 200,
                color: Colors.white,
                child: years.isEmpty
                    ? const Center(child: Text('Нет посевов'))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Все посевы',
                                  style: TextStyle(fontSize: 12)),
                              dense: true,
                              onTap: () {
                                setState(() {
                                  _currentFilter = 'sown_all';
                                  _isSownExpanded = false;
                                });
                              },
                            ),
                            ListTile(
                              title: const Text('Активные',
                                  style: TextStyle(fontSize: 12)),
                              dense: true,
                              onTap: () {
                                setState(() {
                                  _currentFilter = 'sown_filtered';
                                  _isSownExpanded = false;
                                });
                              },
                            ),
                            ...years.map((year) => ListTile(
                                  title: Text(
                                    year.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  dense: true,
                                  onTap: () {
                                    setState(() {
                                      _currentFilter = 'year_$year';
                                      _isSownExpanded = false;
                                    });
                                  },
                                )),
                          ],
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  int? _getSelectedIndex() {
    if (_currentFilter == 'all') {
      return 0;
    }
    if (_currentFilter == PlantStatus.growing) {
      return 1;
    }
    if (_currentFilter == PlantCategory.purchased) {
      return 2;
    }
    if (_currentFilter == 'sown_all' ||
        _currentFilter == 'sown_filtered' ||
        _currentFilter.startsWith('year_') ||
        _isSownExpanded) {
      return 6; // Обновлено на 6, так как "Посевы" теперь на позиции 6
    }
    return null;
  }

  void _openAddForm() async {
    final result = await Navigator.push<Plant>(
      context,
      MaterialPageRoute(
          builder: (ctx) => AddPlantForm(
              getNextCustomNumber: _getNextCustomNumber, isCustomNumberUnique: _isCustomNumberUnique)),
    );
    if (result != null && mounted) {
      Provider.of<PlantCrudProvider>(context, listen: false).addPlant(result);
    }
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

  int _getNextCustomNumber(int year, String category) {
    final plants = context.read<PlantCrudProvider>().plants;
    final numbers = plants
        .where((p) => p.category == category && p.year == year)
        .map((p) => p.customNumber)
        .toList();
    return numbers.isEmpty ? 1 : numbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  bool _isCustomNumberUnique(int year, int number, String category,
      {String? excludeId}) {
    final plants = context.read<PlantCrudProvider>().plants;
    return !plants.any((p) =>
        p.category == category &&
        p.year == year &&
        p.customNumber == number &&
        p.permanentId != excludeId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantCrudProvider>();
    // Фильтруем: не показываем сеянцы (parentId != null) на главном экране
    // Сеянцы показываются только внутри своих витрин
    List<Plant> filteredPlants = provider.plants.where((plant) {
      // Исключаем всех детей (сеянцев с parentId)
      if (plant.parentId != null) return false;

      if (_currentFilter == 'custom_filter' && widget.initialFilter != null) {
        return widget.initialFilter!.contains(plant);
      }
      switch (_currentFilter) {
        case 'all':
          return true;
        case 'growing':
          return ['in_collection', 'growing', 'sown'].contains(plant.status);
        case 'purchased':
          return plant.category == PlantCategory.purchased;
        case 'collection_filter':
          return plant.status == PlantStatus.inCollection;
        case 'sown_in_collection':
          return plant.category == PlantCategory.sown && plant.status == PlantStatus.inCollection;
        case 'purchased_in_collection':
          return plant.category == PlantCategory.purchased &&
              plant.status == PlantStatus.inCollection;
        case 'sown_filtered':
          return plant.category == 'sown' &&
              !['dead', 'failed'].contains(plant.status);
        case 'sown_all':
          return plant.category == PlantCategory.sown;
        default:
          if (_currentFilter.startsWith('year_')) {
            final year = int.tryParse(_currentFilter.split('_')[1]) ?? 0;
            return plant.year == year && plant.category == PlantCategory.sown;
          }
          return true;
      }
    }).toList();

    filteredPlants.sort((a, b) {
      final compareResult = switch (_sortColumn) {
        'latinName' => a.latinName.compareTo(b.latinName),
        'status' => a.statusPriority.compareTo(b.statusPriority),
        'year' => a.year.compareTo(b.year),
        'category' => a.category.compareTo(b.category),
        _ => 0,
      };
      return _isAscending ? compareResult : -compareResult;
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _handleExit(context);
      },
      child: Scaffold(
        body: Row(
          children: [
            _buildNavigationRail(),
            Expanded(
              child: Column(
                children: [
                  AppBar(
                    foregroundColor: Colors
                        .green,
                    title: _isSearching
                        ? TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Поиск по названию или ID...',
                              border: InputBorder.none,
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.green),
                            ),
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                          )
                        : provider.selectedIds.isEmpty
                            ? const Text('Мои кактусы')
                            : Text('Выбрано: ${provider.selectedIds.length}'),
                    actions: [
                      ElevatedButton.icon(
                        onPressed: () => _connectWeather(context),
                        icon: const Icon(Icons.location_on),
                        label: const Text('Подключить погоду'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(
                          height:
                              16), // Отступ перед 'Импорт из Excel' — баланс.
                      IconButton(
                        icon: const Icon(Icons.import_export),
                        tooltip: 'Импорт из Excel',
                        onPressed: () => _importPlants(context),
                      ),
                      if (provider.selectedIds.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Очистить выбор',
                          onPressed: () => provider.clearSelections(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Экспорт в CSV',
                          onPressed: () =>
                              provider.exportSelectedToCSV(context),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.save),
                        tooltip: 'Сохранить изменения',
                        onPressed: () => provider.savePlants(),
                      ),
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close : Icons.search),
                        tooltip: _isSearching ? 'Закрыть поиск' : 'Поиск',
                        onPressed: () => setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) {
                            _searchQuery = '';
                            _searchController.clear();
                          }
                        }),
                      ),
                      if (!context.watch<CloudStorageProvider>().isConnected)
                        IconButton(
                          icon: const Icon(Icons.cloud),
                          tooltip: 'Подключить Яндекс.Диск',
                          onPressed: () async {
                            await context
                                .read<CloudStorageProvider>()
                                .connectToYandexDisk(context);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Попытка подключения завершена')),
                              );
                            }
                          },
                        ),
                      if (context.watch<CloudStorageProvider>().isConnected)
                        IconButton(
                          icon: const Icon(Icons.cloud_off),
                          tooltip: 'Отключить облачное хранилище',
                          onPressed: () async {
                            await context
                                .read<CloudStorageProvider>()
                                .disconnect();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Облачное хранилище отключено')),
                              );
                            }
                          },
                        ),
                      if (context.watch<CloudStorageProvider>().isConnected)
                        IconButton(
                          icon: const Icon(Icons.sync),
                          tooltip: 'Синхронизировать с облаком',
                          onPressed: () async {
                            final plantCrudProvider = context.read<PlantCrudProvider>();
                            final cloudProvider =
                                context.read<CloudStorageProvider>();
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                  content: Text('🔄 Синхронизация началась...')),
                            );
                            try {
                              await cloudProvider.syncData(plantCrudProvider);
                              if (!mounted) return;
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Синхронизация успешно завершена'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('❌ Ошибка: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        tooltip: 'Выйти из аккаунта',
                        onPressed: () async {
                          final cloudProvider =
                              context.read<CloudStorageProvider>();
                          if (cloudProvider.isConnected) {
                            await cloudProvider.disconnect();
                          }
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(
                              'has_seen_welcome', false); // Сбрасываем флаг
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (context) => const WelcomeScreen()),
                            );
                          }
                        },
                      ),
                      if (provider.selectedIds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: AnimatedBuilder(
                            animation: _addController,
                            builder: (context, _) =>
                                FloatingActionButton.extended(
                              onPressed: _openAddForm,
                              label: const Text('Добавить'),
                              icon: const Icon(Icons.add),
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                      if (provider.selectedIds.isNotEmpty)
                        PopupMenuButton<String>(
                          tooltip: 'Действия с выбранными',
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'changeStatus',
                              child: Row(children: [
                                Icon(Icons.update, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Изменить статус'),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Удалить'),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'cleanupPhotos',
                              child: Row(children: [
                                Icon(Icons.delete_forever,
                                    color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Очистить старые фото'),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'deleteAllPhotos',
                              child: Row(children: [
                                Icon(Icons.delete_sweep, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Удалить все фото'),
                              ]),
                            ),
                          ],
                          onSelected: (value) async {
                            final provider = context.read<PlantCrudProvider>();

                            if (value == 'changeStatus') {
                              _showStatusDialog(context);
                            } else if (value == 'delete') {
                              _confirmMassDelete(context);
                            } else if (value == 'cleanupPhotos') {
                              await provider.cleanupUnusedPhotosForSelected(
                                provider.selectedIds,
                                context,
                              );
                            } else if (value == 'deleteAllPhotos') {
                              await provider.deleteAllPhotosForSelected(
                                provider.selectedIds,
                                context,
                              );
                            }
                          },
                        ),
                    ],
                    elevation: 0,
                    backgroundColor: Colors
                        .green.shade50, // Сохранено: Светлый фон — не меняется.
                  ),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.green, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getSeasonalTip(),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(
                      height:
                          16), // Отступ перед статистикой, чтобы карточки не сливались.
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
          ],
        ),
      ),
    );
  }

  Future<void> _importPlants(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
      if (result == null || !context.mounted) {
        return;
      }

      final file = File(result.files.single.path!);
      final bytes = file.readAsBytesSync();
      final excelInstance = excel.Excel.decodeBytes(bytes);
      final sheet = excelInstance.tables.keys.first;
      final table = excelInstance.tables[sheet]!;
      final provider = Provider.of<PlantCrudProvider>(context, listen: false);
      int added = 0;
      int skipped = 0;

      for (var row in table.rows.skip(1)) {
        final name = row[0]?.value?.toString() ?? '';
        final origin = row[1]?.value?.toString() ?? '';
        final seedsStr = row[2]?.value?.toString() ?? '0';
        final germinatedStr = row[3]?.value?.toString() ?? '0';
        final seedNumberStr = row[4]?.value?.toString() ?? '';
        if (name.isEmpty) {
          continue;
        }

        String category;
        int? year;
        if (origin.toLowerCase().contains('куплен')) {
          category = 'purchased';
          year = int.tryParse(origin.split(' ').last) ?? DateTime.now().year;
        } else if (origin.toLowerCase().contains('посев')) {
          category = 'sown';
          year = int.tryParse(origin.split(' ').last);
        } else {
          skipped++;
          continue;
        }
        if (year == null) {
          skipped++;
          continue;
        }

        final seeds = int.tryParse(seedsStr) ?? 0;
        final germinated = int.tryParse(germinatedStr) ?? 0;
        final seedNumber = int.tryParse(seedNumberStr);
        int customNumber = seedNumber != null &&
                provider.isCustomNumberUnique(year, seedNumber, category)
            ? seedNumber
            : provider.getNextCustomNumber(year, category);

        // Проверка на дубликат по имени и году
        if (provider.plants.any((p) => p.latinName == name && p.year == year)) {
          skipped++;
          continue;
        }

        final newPlant = Plant(
          latinName: name,
          status: 'in_collection',
          year: year,
          customNumber: customNumber,
          category: category,
          seedsCount: seeds,
          germinatedCount: germinated,
        );
        provider.addPlant(newPlant);
        added++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Импорт: Добавлено $added, пропущено $skipped')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
      }
    }
  }

  Future<void> _handleExit(BuildContext parentContext) async {
    final provider = parentContext.read<PlantCrudProvider>();
    if (!provider.hasUnsavedChanges) {
      if (parentContext.mounted) {
        Navigator.of(parentContext).pop();
      }
      return;
    }

    await showDialog<void>(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Несохраненные изменения'),
        content: const Text('Сохранить изменения перед выходом?'),
        actions: [
          TextButton(
            child: const Text('Нет'),
            onPressed: () {
              Navigator.pop(dialogContext);
              if (dialogContext.mounted) {
                Navigator.of(parentContext).pop();
              }
            },
          ),
          TextButton(
            child: const Text('Да'),
            onPressed: () {
              provider.savePlants();
              Navigator.pop(dialogContext);
              if (dialogContext.mounted) {
                Navigator.of(parentContext).pop();
              }
            },
          ),
        ],
      ),
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

  void _confirmMassDelete(BuildContext context) {
    final provider = context.read<PlantCrudProvider>();
    final count = provider.selectedIds.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить выбранное'),
        content: Text('Удалить $count растений?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteMultiplePlants();
              Navigator.pop(ctx); // используем ctx из диалога
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(BuildContext context) {
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
        title: const Text('Изменить статус'),
        content: DropdownButtonFormField<String>(
          initialValue: PlantStatus.inCollection.toString(),
          items: validStatuses
              .map((status) => DropdownMenuItem<String>(
                    value: status.toString(),
                    child: Text(
                      status == PlantStatus.sown
                          ? 'Посев'
                          : status == PlantStatus.growing
                              ? 'Растение'
                              : status == PlantStatus.inCollection
                                  ? 'В коллекции'
                                  : status == PlantStatus.dead
                                      ? 'Погиб'
                                      : 'Не взошел',
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              context.read<PlantCrudProvider>().updateMultipleStatus(value);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'))
        ],
      ),
    );
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
      if (!currentContext.mounted) return;

      if (prefs.getDouble('lat') == null) {
        final city = await _showCityDialog(currentContext);
        if (!currentContext.mounted) return;

        if (city != null && city.isNotEmpty) {
          await provider.setCity(city);
          if (!currentContext.mounted) return;

          _showSnackBar(
              currentContext, 'Город "$city" сохранён! Погода обновится.');
        }
      } else {
        if (!currentContext.mounted) return;
        _showSnackBar(currentContext,
            'Геолокация подключена! Погода обновится в календаре.');
      }
    } catch (e) {
      if (!currentContext.mounted) return;
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
}

class AddPlantForm extends StatefulWidget {
  final int Function(int year, String category) getNextCustomNumber;
  final bool Function(int year, int number, String category,
      {String? excludeId}) isCustomNumberUnique;

  const AddPlantForm(
      {super.key, required this.getNextCustomNumber, required this.isCustomNumberUnique});

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
      _numberController.text = widget.getNextCustomNumber(year, _category).toString();
    }
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return 'Обязательное поле';
    final number = int.tryParse(value);
    if (number == null) return 'Введите число';
    final year = int.tryParse(_yearController.text);
    if (year == null) return 'Сначала укажите год';
    return widget.isCustomNumberUnique(year, number, _category)
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

