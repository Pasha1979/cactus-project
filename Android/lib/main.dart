import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/logger/app_logger.dart';
import 'core/config/feature_flags.dart';
import 'core/config/app_constants.dart';
import 'services/backup/auto_backup_service.dart';
import 'presentation/providers/settings_provider.dart';
import 'models/plant.dart';
import 'presentation/providers/cloud_storage_provider.dart';
import 'presentation/providers/providers.dart';
import 'presentation/routers/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/plant_cards.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'theme/cactus_theme.dart';
import 'data/datasources/local/hive_database.dart';
import 'data/migrations/data_migration_manager.dart';
import 'injection_container.dart' as di;
import 'utils/responsive_helper.dart';
import 'screens/statistics_screen.dart';

enum GroupAction { changeStatus, delete }

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация Firebase (фаза 3.4) - опционально
  try {
    await Firebase.initializeApp();
    await AppLogger.initializeCrashlytics();
    // Инициализация Feature Flags (фаза 4.1)
    await FeatureFlags.initialize();
  } catch (e) {
    AppLogger.warning('⚠️ Firebase не настроен: $e', tag: 'MAIN');
  }

  // Инициализация автобэкапа (фаза 4.2)
  await AutoBackupService.initialize();

  // Инициализация Hive базы данных
  await HiveDatabase.initialize();

  // Инициализация DI-контейнера (зависит от Hive)
  await di.init();

  // Миграция данных из SharedPreferences в Hive (при первом запуске после обновления)
  final migrationSuccess = await DataMigrationManager.runMigrationIfNeeded();
  if (!migrationSuccess) {
    AppLogger.warning('⚠️ Миграция данных не удалась. Используем резервный режим.', tag: 'MAIN');
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
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _initNotifications() async {
  // Инициализация для Android/Windows (твоя иконка из mipmap/ic_launcher.png в android/app/src/main/res — сохранена для consistency).
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings(
          '@mipmap/ic_launcher',); // Твоя иконка — не меняет, использует существующую.

  const InitializationSettings initializationSettings = InitializationSettings(
    android:
        initializationSettingsAndroid, // Для Windows — auto, без доп. настроек (плагин кросс-платформенный).
  );

  await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,); // Базовая инициализация — ждет 1 сек max, не блокирует main().

  // Разрешения для Android 13+ (Windows — не применимо).
  // await flutterLocalNotificationsPlugin
  //     .resolvePlatformSpecificImplementation<
  //         AndroidFlutterLocalNotificationsPlugin>()?
  //     .requestNotificationsPermission();
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
        // Сохранено: Временный MaterialApp для loading — не меняется, работает как раньше (CircularProgressIndicator).
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

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

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: CactusTheme.light(),
          darkTheme: CactusTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: appRouter,
        );
      }, // Исправлено: Закрывающая скобка для builder — фиксирует синтаксис (expected ';').
    ); // Исправлено: Закрывающая скобка для FutureBuilder — фиксирует unexpected token и missing identifier.
  }

  Future<Map<String, dynamic>> _initializeAndCheckStatus(
      CloudStorageProvider cloudProvider,) async {
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
      PlantCrudProvider plantCrudProvider, CloudStorageProvider cloudProvider,) async {
    await plantCrudProvider.loadPlants();
    if (!cloudProvider.isConnected) {
      AppLogger.api('Нет подключения к облаку, синхронизация пропущена', tag: 'MAIN');
      return;
    }
    await cloudProvider.fetchLastCloudUpdate();
    final localUpdate = plantCrudProvider.lastLocalUpdate;
    final cloudUpdate = cloudProvider.lastCloudUpdate;
    AppLogger.api('Локальное обновление: $localUpdate', tag: 'MAIN');
    AppLogger.api('Облачное обновление: $cloudUpdate', tag: 'MAIN');
    if (localUpdate == null && cloudUpdate == null) {
      AppLogger.api('Оба хранилища пусты, синхронизация не требуется', tag: 'MAIN');
      return;
    }
    if (plantCrudProvider.plants.isEmpty && cloudUpdate != null) {
      AppLogger.api('Локальные данные пусты, загружаем из облака', tag: 'MAIN');
      await cloudProvider.loadDataFromCloud(plantCrudProvider);
      await plantCrudProvider.savePlants();
    } else if (cloudUpdate == null ||
        (localUpdate != null && localUpdate.isAfter(cloudUpdate))) {
      AppLogger.api('Локальные данные новее или облако пусто, синхронизируем в облако', tag: 'MAIN');
      await cloudProvider.syncData(plantCrudProvider);
    } else if (localUpdate == null || cloudUpdate.isAfter(localUpdate)) {
      AppLogger.api('Облачные данные новее или локальные пусты, загружаем из облака', tag: 'MAIN');
      await cloudProvider.loadDataFromCloud(plantCrudProvider);
      await plantCrudProvider.savePlants();
    } else {
      AppLogger.api('Данные синхронизированы, ничего не требуется', tag: 'MAIN');
    }
  }
}

// Остальной код (HomeScreen, PlantCards, AddPlantForm) остаётся без изменений

class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key, this.initialFilter});
  final List<Plant>? initialFilter;

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _addController;
  String _currentFilter = 'all';
  String? _selectedSowingYear;
  bool _isSownExpanded = false;
  String _sortColumn = 'latinName';
  bool _isAscending = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _cachedSeasonalTip;
  int? _cachedSeasonalTipHash;
  bool _tipDismissed = false;

  // История поиска (последние 5 запросов)
  List<String> _searchHistory = [];
  static const String _searchHistoryKey = 'search_history';

  @override
  void initState() {
    super.initState();
    _addController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _loadSearchHistory();
    // Defer loadPlants to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlantCrudProvider>().loadPlants();
      if (widget.initialFilter != null) {
        _currentFilter = 'custom_filter';
        context.read<PlantCrudProvider>().clearSelections();
        context
            .read<PlantCrudProvider>()
            .selectAll(widget.initialFilter!.map((p) => p.permanentId).toList());
      }
    });
  }

  @override
  void dispose() {
    _addController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Компактный чип статистики для Android
  Widget _buildStatChip({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    String? onTapFilter,
  }) {
    final isActive = _currentFilter == onTapFilter;
    return GestureDetector(
      onTap: onTapFilter != null
          ? () => setState(() => _currentFilter = onTapFilter)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? Colors.white : color,
                size: 14,),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? Colors.white.withValues(alpha: 0.9)
                    : color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Оставляем для Windows/tablet layout
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    String? onTapFilter,
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
                          color: color,),),
                  Text(title,
                      style: TextStyle(
                          fontSize: 14, color: color.withValues(alpha: 0.8),),),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Компактная строка чипов для мобильных
  Widget _buildStatsChips() {
    final provider = context.watch<PlantCrudProvider>();
    final plants = provider.plants;
    final mainPlants = plants.where((p) => p.parentId == null).toList();
    final total = mainPlants.length;
    final seedlingsCount = plants.where((p) => p.parentId != null).length;
    final batchesCount = plants.where((p) => p.isBatch).length;
    final inCollectionCount = mainPlants
        .where((p) => p.status == PlantStatus.inCollection)
        .length;
    final sownInCollection = mainPlants
        .where((p) =>
            p.category == PlantCategory.sown &&
            p.status == PlantStatus.inCollection,)
        .length;
    final purchasedInCollection = mainPlants
        .where((p) =>
            p.category == PlantCategory.purchased &&
            p.status == PlantStatus.inCollection,)
        .length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _buildStatChip(
            icon: Icons.all_inclusive,
            title: 'Все',
            count: total,
            color: Colors.grey.shade600,
            onTapFilter: 'all',
          ),
          const SizedBox(width: 6),
          _buildStatChip(
            icon: Icons.collections,
            title: 'Коллекция',
            count: inCollectionCount,
            color: Colors.green,
            onTapFilter: 'in_collection',
          ),
          const SizedBox(width: 6),
          _buildStatChip(
            icon: Icons.spa,
            title: 'Семена',
            count: sownInCollection,
            color: Colors.orange,
            onTapFilter: 'sown_in_collection',
          ),
          const SizedBox(width: 6),
          _buildStatChip(
            icon: Icons.shopping_cart,
            title: 'Покупка',
            count: purchasedInCollection,
            color: Colors.blue,
            onTapFilter: 'purchased_in_collection',
          ),
          if (seedlingsCount > 0) ...[
            const SizedBox(width: 6),
            _buildStatChip(
              icon: Icons.spa,
              title: 'Сеянцы',
              count: seedlingsCount,
              color: Colors.teal,
              onTapFilter: null,
            ),
          ],
          if (batchesCount > 0) ...[
            const SizedBox(width: 6),
            _buildStatChip(
              icon: Icons.group,
              title: 'Партий',
              count: batchesCount,
              color: Colors.indigo,
              onTapFilter: null,
            ),
          ],
        ],
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
                  'all',),
          _buildStatCard(
              icon: Icons.collections,
              title: 'В коллекции',
              count: inCollectionCount,
              color: Colors.green,
              onTapFilter:
                  'in_collection',), // Обновлён: onTapFilter 'in_collection' (instead of if title).
          _buildStatCard(
              icon: Icons.spa,
              title: 'Выращено из семян',
              count: sownInCollection,
              color: Colors.orange,
              onTapFilter:
                  'sown_in_collection',), // Обновлён: onTapFilter 'sown_in_collection'.
          _buildStatCard(
              icon: Icons.shopping_cart,
              title: 'Купленные',
              count: purchasedInCollection,
              color: Colors.blue,
              onTapFilter:
                  'purchased_in_collection',), // Обновлён: onTapFilter 'purchased_in_collection'.
          if (seedlingsCount > 0)
            _buildStatCard(
                icon: Icons.spa,
                title: 'Сеянцы',
                count: seedlingsCount,
                color: Colors.teal,
                onTapFilter: null,), // Сеянцы не кликабельны - они не на главном экране
          if (batchesCount > 0)
            _buildStatCard(
                icon: Icons.group,
                title: 'Партий',
                count: batchesCount,
                color: Colors.indigo,
                onTapFilter: null,), // Партии не кликабельны отдельно
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
              context.push('/statistics');
            } else if (index == 6) {
              context.push('/qr');
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
                                  style: TextStyle(fontSize: 12),),
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
                                  style: TextStyle(fontSize: 12),),
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
                                ),),
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
    final result = await context.push<Plant>('/add-plant');
    if (result != null && mounted) {
      Provider.of<PlantCrudProvider>(context, listen: false).addPlant(result);
    }
  }

  void _openEditForm(Plant plant) async {
    final result = await context.push<Plant>(
      '/plant/${plant.permanentId}/edit',
      extra: plant,
    );
    if (result != null && mounted) {
      context.read<PlantCrudProvider>().updatePlant(plant.permanentId, result);
    }
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

    final isMobile = Responsive.isMobile(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _handleExit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: Colors.green,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.black87,
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
                      borderSide: const BorderSide(color: Colors.green, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green, width: 2.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
            // Кнопка Сохранить (договорённость)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Сохранить изменения',
              onPressed: () => provider.savePlants(),
            ),
            // Кнопка подключения Яндекс.Диска
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              tooltip: 'Подключить Яндекс.Диск',
              onPressed: () async {
                final cloudProvider = context.read<CloudStorageProvider>();
                if (cloudProvider.isConnected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Яндекс.Диск уже подключён'),),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Открываем страницу авторизации...'),),
                );
                await cloudProvider.connectToYandexDisk(context);
              },
            ),
            // Кнопка погоды
            if (!_isSearching)
              IconButton(
                icon: const Icon(Icons.cloud),
                onPressed: () => _connectWeather(context),
              ),
            Consumer<PlantCrudProvider>(
              builder: (context, p, child) {
                if (p.selectedIds.isEmpty) return const SizedBox.shrink();
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Действия с выбранными (${p.selectedIds.length})',
                  onSelected: (value) async {
                    if (value == 'clear') {
                      p.clearSelections();
                    } else if (value == 'changeStatus') {
                      _showStatusDialog(context);
                    } else if (value == 'delete') {
                      _confirmMassDelete(context);
                    } else if (value == 'cleanup_old') {
                      await p.cleanupUnusedPhotosForSelected(
                          Set<String>.from(p.selectedIds), context,);
                    } else if (value == 'delete_all_photos') {
                      await p.deleteAllPhotosForSelected(
                          Set<String>.from(p.selectedIds), context,);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'clear',
                      child: Row(children: [
                        Icon(Icons.close, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Очистить выбор'),
                      ],),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'changeStatus',
                      child: Row(children: [
                        Icon(Icons.update, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Изменить статус'),
                      ],),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Удалить выбранные'),
                      ],),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'cleanup_old',
                      child: Row(children: [
                        Icon(Icons.delete_forever, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Удалить старые фото'),
                      ],),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete_all_photos',
                      child: Row(children: [
                        Icon(Icons.delete_sweep, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Удалить все фото'),
                      ],),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        drawer: isMobile ? _buildDrawer() : null,
        bottomNavigationBar: isMobile ? _buildBottomNavigationBar() : null,
        floatingActionButton: provider.selectedIds.isEmpty
            ? AnimatedBuilder(
                animation: _addController,
                builder: (context, _) => FloatingActionButton.extended(
                  onPressed: _openAddForm,
                  label: const Text('Добавить'),
                  icon: const Icon(Icons.add),
                  backgroundColor: Colors.green,
                ),
              )
            : null,
        body: isMobile
            ? SafeArea(
                child: Column(
                  children: [
                    // Компактный сезонный совет
                    if (!_tipDismissed)
                      Container(
                        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6,),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.green.shade200, width: 1,),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                color: Colors.green, size: 14,),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _getSeasonalTip(),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black87,),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _tipDismissed = true),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.grey,),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    _buildStatsChips(),
                  Expanded(
                    child: PlantCards(
                      plants: filteredPlants
                          .where((p) =>
                              p.latinName
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()) ||
                              p.displayId
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()),
                          )
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
            )
        : Row(
            children: [
              _buildNavigationRail(),
              Expanded(
                child: Column(
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),),
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
                                    fontSize: 16, fontWeight: FontWeight.w500,),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                    .contains(_searchQuery.toLowerCase()),)
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
    context.push('/sowing');
  }

  void _navigateToCollectionManagement() {
    context.push('/collection');
  }

  void _confirmMassDelete(BuildContext context) {
    final provider = context.read<PlantCrudProvider>();
    final count = provider.selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить выбранное'),
        content: Text('Удалить $count растений? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteMultiplePlants();
              Navigator.pop(ctx);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(BuildContext context) {
    final provider = context.read<PlantCrudProvider>();
    final selectedPlants = provider.plants
        .where((p) => provider.selectedIds.contains(p.permanentId))
        .toList();
    final count = selectedPlants.length;

    // Считаем сколько растений имеют каждый статус
    final statusCounts = <String, int>{};
    for (final plant in selectedPlants) {
      statusCounts[plant.status] = (statusCounts[plant.status] ?? 0) + 1;
    }

    // Если все одинаковые — предвыбираем, иначе null
    final uniqueStatuses = statusCounts.keys.toSet();
    final initialStatus = uniqueStatuses.length == 1 ? uniqueStatuses.first : null;

    const statusLabels = <String, String>{
      'sown': 'Посев',
      'growing': 'Растение',
      'in_collection': 'В коллекции',
      'dead': 'Погиб',
      'failed': 'Не взошел',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        String? selected = initialStatus;
        return StatefulBuilder(
          builder: (ctx, setStateLocal) => AlertDialog(
            title: Text('Изменить статус ($count растений)'),
            content: RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) => setStateLocal(() => selected = value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: statusLabels.entries.map((entry) {
                  final plantCount = statusCounts[entry.key] ?? 0;
                  return RadioListTile<String>(
                    value: entry.key,
                    activeColor: Colors.green,
                    title: Text(entry.value),
                    secondary: plantCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2,),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$plantCount',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.green,),
                            ),
                          )
                        : null,
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected != null
                      ? Colors.green
                      : Colors.grey.shade300,
                ),
                onPressed: selected == null
                    ? null
                    : () {
                        context
                            .read<PlantCrudProvider>()
                            .updateMultipleStatus(selected!);
                        Navigator.pop(ctx);
                      },
                child: const Text('Применить',
                    style: TextStyle(color: Colors.white),),
              ),
            ],
          ),
        );
      },
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
              currentContext, 'Город "$city" сохранён! Погода обновится.',);
        }
      } else {
        if (!currentContext.mounted) return;
        _showSnackBar(currentContext,
            'Геолокация подключена! Погода обновится в календаре.',);
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

  // Drawer для мобильных устройств
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.green),
            child: Text('Меню',
                style: TextStyle(color: Colors.white, fontSize: 24),),
          ),

          // Настройки
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.blue),
            title: const Text('Настройки'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),

          const Divider(),

          // Управление посевами
          ListTile(
            leading: const Icon(Icons.agriculture),
            title: const Text('Управление посевами'),
            onTap: () {
              Navigator.pop(context);
              _navigateToSowingManagement();
            },
          ),

          // Фильтр по году посева
          ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('Фильтр по году посева'),
            subtitle: _selectedSowingYear != null
                ? Text('Выбран: $_selectedSowingYear', style: const TextStyle(color: Colors.green))
                : null,
            onTap: () {
              Navigator.pop(context);
              _showSowingYearFilter();
            },
          ),

          // Управление коллекцией
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Управление коллекцией'),
            onTap: () {
              Navigator.pop(context);
              _navigateToCollectionManagement();
            },
          ),

          // Управление QR
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('QR-коды'),
            subtitle: const Text('Управление, печать, файлы'),
            onTap: () {
              Navigator.pop(context);
              context.push('/qr');
            },
          ),

          // Статистика
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

          const Divider(),

          // Принудительно обновить из облака
          ListTile(
            leading: const Icon(Icons.cloud_download, color: Colors.blue),
            title: const Text('Принудительно обновить из облака'),
            subtitle: const Text('Скачать свежие данные с Яндекс.Диска'),
            onTap: () async {
              Navigator.pop(context);

              final cloudProvider = context.read<CloudStorageProvider>();
              final plantProvider = context.read<PlantCrudProvider>();

              if (!cloudProvider.isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Сначала подключите Яндекс.Диск'),
                  ),
                );
                return;
              }

              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⏳ Загружаем данные из облака...'),
                  ),
                );

                await cloudProvider.fetchLastCloudUpdate();
                await cloudProvider.loadDataFromCloud(plantProvider);
                await plantProvider.savePlants();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Данные успешно загружены из Яндекс.Диска!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Ошибка загрузки: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // Нижняя навигация для мобильных устройств
  Widget _buildBottomNavigationBar() {
    final cloudProvider = context.read<CloudStorageProvider>();

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
          // Сканер QR
          context.push('/qr/scan');
        } else if (index == 2) {
          // Синхронизировать
          if (!cloudProvider.isConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Сначала подключите Яндекс.Диск'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          final plantProvider = context.read<PlantCrudProvider>();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🔄 Синхронизация началась...')),
          );

          try {
            await cloudProvider.syncData(plantProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Синхронизация успешно завершена'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Ошибка: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else if (index == 3) {
          // Выход
          await _handleExit(context);
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.grass),
          label: 'Растут',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_scanner),
          label: 'Сканер',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sync),
          label: 'Синхр.',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.exit_to_app),
          label: 'Выход',
        ),
      ],
    );
  }

  // Диалог фильтра по году посева
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
                      (p) => p.category == 'sown' && p.year.toString() == year,)
                  .length;
              return ListTile(
                title: Text(year),
                trailing: Text(
                  '$count шт.',
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedSowingYear = year;
                    _currentFilter = 'year_$year';
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

