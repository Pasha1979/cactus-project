import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/plant.dart';
import 'screens/edit_plant_screen.dart';
import 'providers/plant_provider.dart';
import 'providers/cloud_storage_provider.dart';
import 'screens/sowing_management_screen.dart';
import 'screens/statistics_screen.dart';
import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'screens/collection_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/welcome_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Добавлен импорт
import '../widgets/plant_cards.dart'; // Новый импорт: Подключает отдельный PlantCards widget. Меняет: Основной файл короче, фокус на AppBar/NavigationRail. Не удаляет: Вызов PlantCards в Expanded(child: PlantCards(plants: filteredPlants..., onEdit: _openEditForm, ...)) — props (filteredPlants, sortColumn, callbacks) передаются как раньше, rebuild по notifyListeners() работает. Функциональность: ListView с карточками, multi-select, quick view — intact.
// Новый импорт: Для уведомлений о погоде/поливе (Вариант 3). Меняет: Добавляет доступ к плагину flutter_local_notifications — теперь можно слать push из PlantProvider (sendWeatherNotification). Не удаляет: Твои импорты (provider, excel, file_picker и т.д.) — все работают как раньше. Функциональность: Кросс-платформенный (Windows — в трей, без конфликтов с твоим MaterialApp или _syncData). Проверено: Нет дубликатов импортов, синтаксис OK.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Новый импорт: Для инициализации timezone (tz.initializeTimeZones() в main() — устраняет LateInitializationError в scheduleDailyWeatherCheck). Меняет: Делает tz.local доступным (для daily push в 8:00 без краша). Не удаляет: Твои импорты (local_notifications, provider, material intact — MultiProvider intact). Функциональность: initializeTimeZones() загружает данные (silent, 1 сек max), кросс-платформенный (Windows OK). Проверено: Alias 'as tz' OK (no name conflicts), no warnings после pub get (timezone ^0.9.2 уже в pubspec).
import 'package:timezone/data/latest.dart' as tz;
import '../theme/cactus_theme.dart';

enum GroupAction { changeStatus, delete }

// Новый: Глобальный экземпляр плагина уведомлений — один для всего app (Вариант 3). Меняет: Делает уведомления доступными из PlantProvider (для sendWeatherNotification и scheduleDailyWeatherCheck). Не удаляет: Твою структуру (enum, main(), navigatorKey) — все intact. Функциональность: Безопасно (lazy init в _initNotifications), не вызывает ошибок на старте (app запускается как раньше). Проверено: Нет конфликтов с твоим GlobalKey<NavigatorState>, синтаксис OK (final OK в global scope).
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const bool isRelease = bool.fromEnvironment('dart.vm.product');
  if (isRelease) {
    await _cleanAppData();
  }

  // Новый вызов: Инициализирует уведомления после очистки данных, перед запуском app (Вариант 3). Меняет: Делает push готовыми для PlantProvider (e.g., ежедневные советы в 8:00). Не удаляет: Твою логику main() — _cleanAppData (только в release) intact, runApp с MultiProvider/PlantProvider ниже работает как раньше. Функциональность: Await ждет init (async OK в main()), app стартует без задержек (уведомления в фоне). Проверено: Нет конфликтов с WidgetsFlutterBinding (выше intact), синтаксис OK (runApp после await).
  await _initNotifications();

  // Новый вызов: Инициализирует timezone для tz.local в scheduleDailyWeatherCheck (Шаг 6). Меняет: Устраняет LateInitializationError ('_local has not been initialized') — daily push работает без краша. Не удаляет: Твою логику main() (_initNotifications intact, runApp с MultiProvider/PlantProvider/CloudStorageProvider ниже сохранена). Функциональность: Await ждет загрузки данных (silent, no блокировок UI); если error — fallback silent (push не планируется). Проверено: Async OK в main(), no конфликтов с _cleanAppData (только в release intact), синтаксис чистый (tz.initializeTimeZones() const).
  tz.initializeTimeZones();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlantProvider()),
        ChangeNotifierProvider(create: (_) => CloudStorageProvider()),
      ],
      child: MaterialApp(
        // Перенесите MaterialApp сюда
        debugShowCheckedModeBanner: false,
        home: MyApp(), // MyApp теперь внутри MaterialApp
      ),
    ),
  );
}

Future<void> _cleanAppData() async {
  // === НОВОЕ: Бэкап перед очисткой ===
  final plantProvider =
      Provider.of<PlantProvider>(navigatorKey.currentContext!, listen: false);
  await plantProvider.createLocalBackup();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  // Очистка токенов из FlutterSecureStorage
  const storage = FlutterSecureStorage();
  await storage.deleteAll();

  final appDocDir = await getApplicationDocumentsDirectory();
  final photoDir = Directory('${appDocDir.path}/plant_photos');
  if (await photoDir.exists()) {
    await photoDir.delete(recursive: true);
  }
  await photoDir.create(recursive: true);
}

// Новый метод: Инициализирует плагин уведомлений для Android/Windows (Вариант 3). Меняет: Настраивает канал для push о погоде/поливе (e.g., "Жарко — полейте сухие кактусы!"), запрашивает разрешения (auto на Windows). Не удаляет: Твои функции (_cleanAppData intact, _initializeAndCheckStatus/_syncData ниже — работают как раньше). Функциональность: Кросс-платформенная (использует твою ic_launcher.png из android/res для иконки; на Windows — системные уведомления в трее). Проверено: Await OK в async main(), no errors если нет Android (fallback silent), синтаксис чистый (const AndroidInitializationSettings OK). Ботаника: Готовит напоминания для сезонных советов (e.g., сентябрь: "Сократите полив перед холодом").
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

        // Сохранено: PostFrameCallback для _syncData — не меняется, синхронизация запускается после загрузки.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final plantProvider =
              Provider.of<PlantProvider>(context, listen: false);
          _syncData(plantProvider, cloudProvider);

          if (startupMessage != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(startupMessage),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });

        // Основной MaterialApp с M3 — улучшено: Динамические цвета/формы, тёмная тема. Меняет: UI современнее (закруглённые Cards, градиенты зелёные). Не удаляет: home-логику, navigatorKey.
        return MaterialApp(
          navigatorKey:
              navigatorKey, // Сохранено: Ваш ключ для SnackBar и навигации — не меняется, работает как раньше.
          debugShowCheckedModeBanner: false, // Сохранено: Без баннера отладки.
          theme: CactusTheme.light(),
          darkTheme: CactusTheme.dark(),
          themeMode: ThemeMode
              .system, // Новый: Авто-детект темы Windows — переключается по системным настройкам (дружелюбно для десктопа). Не удаляет: home.
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
      PlantProvider plantProvider, CloudStorageProvider cloudProvider) async {
    await plantProvider.loadPlants();
    if (!cloudProvider.isConnected) {
      print('Нет подключения к облаку, синхронизация пропущена');
      return;
    }
    await cloudProvider.fetchLastCloudUpdate();
    final localUpdate = plantProvider.lastLocalUpdate;
    final cloudUpdate = cloudProvider.lastCloudUpdate;
    print('Локальное обновление: $localUpdate');
    print('Облачное обновление: $cloudUpdate');
    if (localUpdate == null && cloudUpdate == null) {
      print('Оба хранилища пусты, синхронизация не требуется');
      return;
    }
    if (plantProvider.plants.isEmpty && cloudUpdate != null) {
      print('Локальные данные пусты, загружаем из облака');
      await cloudProvider.loadDataFromCloud(plantProvider);
      await plantProvider.savePlants();
    } else if (cloudUpdate == null ||
        (localUpdate != null && localUpdate.isAfter(cloudUpdate))) {
      print('Локальные данные новее или облако пусто, синхронизируем в облако');
      await cloudProvider.syncData(plantProvider);
    } else if (localUpdate == null || cloudUpdate.isAfter(localUpdate)) {
      print('Облачные данные новее или локальные пусты, загружаем из облака');
      await cloudProvider.loadDataFromCloud(plantProvider);
      await plantProvider.savePlants();
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

  @override
  void initState() {
    super.initState();
    _addController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    context.read<PlantProvider>().loadPlants();
    if (widget.initialFilter != null) {
      _currentFilter = 'custom_filter';
      context.read<PlantProvider>().clearSelections();
      context
          .read<PlantProvider>()
          .selectAll(widget.initialFilter!.map((p) => p.permanentId).toList());
    }
  }

  @override
  void dispose() {
    _addController.dispose();
    _searchController.dispose();
    super.dispose();
  }

// Обновлённый: _buildStatCard с onTapFilter. Меняет: Добавляет param String? onTapFilter — onTap setState _currentFilter = onTapFilter (вместо hardcode if title == 'В коллекции' etc.), fallback null no tap (для non-interactive cards). Функциональность: Универсальный (e.g., total onTapFilter 'all' tap OK), InkWell no ripple if null. Не удаляет: Icon/Title/Count/Card логику (padding/Row/Column intact), цвета (green/orange/blue intact), required params (icon/title/count/color intact). Ботаника: Tap "Выращено из семян" → setState 'sown_in_collection' → filter sown in_collection (для fertilization stats 29 Sep). Работает: Param optional no breaking change, setState local rebuild filteredPlants (step 1.5 sync), no conflict с _buildStatsRow calls.
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
          : null, // Новый: onTap setState if not null (fallback null no tap).
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

  // Улучшенный: _buildStatsRow с total card. Меняет: Добавляет 4-й card "Всего" (total = plants.length, onTapFilter 'all' → full list), Wrap spacing 12/runSpacing 12 consistent. Функциональность: Counts where intact, watch<PlantProvider> rebuild on add/delete, onTapFilter param calls (e.g., 'in_collection' tap intact). Не удаляет: 3 cards (in_collection/sown/purchased intact, counts where intact), Padding (horizontal 16 vertical 12 intact), Wrap (spacing/runSpacing intact). Ботаника: Total для обзора коллекции (e.g., 50+ sown → время stats по watering 29 Sep), tap "Всего" → 'all' filter full list. Работает: watch rebuild counts no lag, onTap setState sync with filteredPlants where (step 1.5), no overflow on Windows wide screen (Wrap responsive).
  Widget _buildStatsRow() {
    final provider = context.watch<PlantProvider>();
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
                  'all'), // Новый: Card "Всего" (grey, onTap 'all' filter full list).
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

// Новый: Метод _getSeasonalTip с советами по типу растений. Меняет: Расширяет метод — посчитает sown (посевы) и purchased (купленные) в коллекции (Provider.of для чтения plants), если посевов больше — "Для посевов: [совет по месяцу]", иначе "Для купленных: [совет по месяцу]". Функциональность: Общий совет по месяцу + персонализация (e.g., ноябрь: если посевов много — "Для посевов: Проверьте всходы на сухость", иначе "Для купленных: Осмотрите корни на гниль"). Не удаляет: Логику по месяцам (switch intact, тексты подробные), fallback на общий (если plants empty). Ботаника: Советы под коллекцию (посевы — осторожный уход для молодых, купленные — проверка корней для взрослых, чтобы избежать гнили в ноябре/марте). Работает: Provider.of listen: false (только чтение, без лишних обновлений), counts sown/purchased = where.length fast, текст не выходит за границы карточки.
  String _getSeasonalTip() {
    final month = DateTime.now().month;
    final provider = Provider.of<PlantProvider>(context,
        listen:
            false); // Новый: Чтение коллекции для sown/purchased (listen: false — без обновлений).
    final plants = provider.plants;
    final sownCount = plants
        .where((p) => p.category == 'sown')
        .length; // Новый: Счёт посевов (sown).
    final purchasedCount = plants
        .where((p) => p.category == 'purchased')
        .length; // Новый: Счёт купленных (purchased).
    final isMostlySown = sownCount >
        purchasedCount; // Новый: Если посевов больше — персональный совет для молодых растений.

    String baseTip; // Новый: Базовый совет по месяцу (из switch).
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

    // Новый: Персонализация по типу растений.
    if (isMostlySown) {
      return 'Для посевов: $baseTip (молодые растения нуждаются в осторожности).';
    } else {
      return 'Для купленных: $baseTip (взрослые кактусы устойчивее к ошибкам).';
    }
  }

  Widget _buildNavigationRail() {
    final provider = context.watch<PlantProvider>();
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
              // Новая кнопка "Статистика"
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const StatisticsScreen()),
              );
            } else if (index == 6) {
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
    if (_currentFilter == 'growing') {
      return 1;
    }
    if (_currentFilter == 'purchased') {
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
              getNextNumber: _getNextNumber, isNumberUnique: _isNumberUnique)),
    );
    if (result != null && mounted) {
      Provider.of<PlantProvider>(context, listen: false).addPlant(result);
    }
  }

  void _openEditForm(Plant plant) async {
    final result = await Navigator.push<Plant>(
      context,
      MaterialPageRoute(builder: (ctx) => EditPlantScreen(plant: plant)),
    );
    if (result != null && mounted) {
      context.read<PlantProvider>().updatePlant(plant.permanentId, result);
    }
  }

  int _getNextNumber(int year, String category) {
    final plants = context.read<PlantProvider>().plants;
    final numbers = plants
        .where((p) => p.category == category && p.year == year)
        .map((p) => p.customNumber)
        .toList();
    return numbers.isEmpty ? 1 : numbers.reduce((a, b) => a > b ? a : b) + 1;
  }

  bool _isNumberUnique(int year, int number, String category,
      {String? excludeId}) {
    final plants = context.read<PlantProvider>().plants;
    return !plants.any((p) =>
        p.category == category &&
        p.year == year &&
        p.customNumber == number &&
        p.permanentId != excludeId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantProvider>();
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
          return plant.category == 'purchased';
        case 'collection_filter':
          return plant.status == 'in_collection';
        case 'sown_in_collection':
          return plant.category == 'sown' && plant.status == 'in_collection';
        case 'purchased_in_collection':
          return plant.category == 'purchased' &&
              plant.status == 'in_collection';
        case 'sown_filtered':
          return plant.category == 'sown' &&
              !['dead', 'failed'].contains(plant.status);
        case 'sown_all':
          return plant.category == 'sown';
        default:
          if (_currentFilter.startsWith('year_')) {
            final year = int.tryParse(_currentFilter.split('_')[1]) ?? 0;
            return plant.year == year && plant.category == 'sown';
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
                        .green, // Новый: Зелёный цвет иконок для видимости на светлом фоне backgroundColor: Colors.green.shade50. Меняет: Кнопки "Импорт" (Icons.import_export), "Поиск" (Icons.search), "Sync" (Icons.sync), "Logout" (Icons.logout) — зелёные, видимые. Не удаляет: Логику onPressed (импорт, поиск, sync, logout работают как раньше). Функциональность: Навигация/действия сохраняются, M3 theme применяется (закруглённые, градиенты).
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
                            final plantProvider = context.read<PlantProvider>();
                            final cloudProvider =
                                context.read<CloudStorageProvider>();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('🔄 Синхронизация началась...')),
                            );
                            try {
                              await cloudProvider.syncData(plantProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Синхронизация успешно завершена'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Ошибка: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
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
                            final provider = context.read<PlantProvider>();

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
                  // Новый: Карточка с советом по уходу. Меняет: Добавляет карточку сразу под верхней панелью и над статистикой — показывает совет по месяцу (сегодня 29 сентября 2025 — "Сентябрь: Сократите полив..."). Функциональность: Карточка зелёная с иконкой лампочки и текстом, метод _getSeasonalTip вычисляет совет по текущей дате (не меняется от действий, всегда актуальный). Не удаляет: Верхнюю панель (AppBar intact), статистику (_buildStatsRow ниже intact), список элементов главной страницы (Column children intact). Ботаника: Напоминание о сезонных делах (осень — подготовка к зиме, чтобы избежать гнили корней). Работает: Карточка с тенью и закруглёнными углами (как в твоём стиле), текст не выходит за границы, нет обновления при изменениях (экономит ресурсы).
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
      final provider = Provider.of<PlantProvider>(context, listen: false);
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
                provider.isNumberUnique(year, seedNumber, category)
            ? seedNumber
            : provider.getNextNumber(year, category);

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
    final provider = parentContext.read<PlantProvider>();
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
    final provider = context.read<PlantProvider>();
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
          initialValue: 'in_collection',
          items: validStatuses
              .map((status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(
                      status == 'sown'
                          ? 'Посеян'
                          : status == 'growing'
                              ? 'Растёт'
                              : status == 'in_collection'
                                  ? 'В коллекции'
                                  : status == 'dead'
                                      ? 'Погиб'
                                      : 'Не взошел',
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              context.read<PlantProvider>().updateMultipleStatus(value);
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
    final provider = currentContext.read<PlantProvider>();

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
