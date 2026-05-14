import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/plant.dart';
import '../../screens/add_plant_screen.dart';
import '../../screens/add_sowing_year_screen.dart';
import '../../screens/batch_qr_creation_screen.dart';
import '../../screens/care_calendar_screen.dart';
import '../../screens/collection_management_screen.dart';
import '../../screens/edit_plant_screen.dart';
import '../../screens/plant_statistics_screen.dart';
import '../../screens/print_settings_screen.dart';
import '../../screens/qr_management_screen.dart';
import '../../screens/qr_scanner_screen.dart';
import '../../screens/select_plants_for_print_screen.dart';
import '../../screens/sowing_management_screen.dart';
import '../../screens/statistics_screen.dart';
import '../../screens/welcome_screen.dart';
import '../../screens/wintering_screen.dart';
import '../../screens/year_germination_chart_screen.dart';
import '../screens/plant_card/plant_card_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/appearance_settings_screen.dart';
import '../screens/settings/backup_settings_screen.dart';
import '../screens/settings/behavior_settings_screen.dart';
import '../screens/settings/cloud_settings_screen.dart';
import '../screens/settings/data_management_screen.dart';
import '../screens/settings/debug_settings_screen.dart';
import '../screens/settings/experiments_settings_screen.dart';
import '../screens/settings/notifications_settings_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/system_settings_screen.dart';
import '../screens/settings/weather_settings_screen.dart';
import '../../main.dart' show HomeScreen;

/// Централизованный роутер приложения.
///
/// Маршруты с параметрами-объектами (`Plant`, `List<Plant>`) принимают данные
/// через `state.extra`. Deep linking для таких маршрутов требует
/// доработки конструкторов экранов (загрузка по ID из Provider).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  redirect: (context, state) async {
    // Не редиректим если уже на /welcome
    if (state.uri.path == '/welcome') return null;
    // Не редиректим deep links (путь != корневому) — сохраняем внешние URL
    if (state.uri.path != '/') return null;
    // Только для корневого запуска проверяем welcome screen
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
    if (!hasSeenWelcome) {
      return '/welcome';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/add-plant',
      builder: (context, state) => const AddPlantScreen(),
    ),
    GoRoute(
      path: '/plant/:id',
      builder: (context, state) {
        final plant = state.extra as Plant?;
        if (plant == null) {
          return const Scaffold(
            body: Center(child: Text('Растение не передано')),
          );
        }
        return PlantCardScreen(plant: plant);
      },
    ),
    GoRoute(
      path: '/plant/:id/edit',
      builder: (context, state) {
        final plant = state.extra as Plant?;
        if (plant == null) {
          return const Scaffold(
            body: Center(child: Text('Растение не передано')),
          );
        }
        return EditPlantScreen(plant: plant);
      },
    ),
    GoRoute(
      path: '/sowing',
      builder: (context, state) => const SowingManagementScreen(),
    ),
    GoRoute(
      path: '/sowing-year/:year',
      builder: (context, state) {
        final yearStr = state.pathParameters['year'];
        final year = int.tryParse(yearStr ?? '');
        if (year == null) {
          return const Scaffold(
            body: Center(child: Text('Некорректный год')),
          );
        }
        return SowingYearDetailsScreen(year: year);
      },
    ),
    GoRoute(
      path: '/collection',
      builder: (context, state) => const CollectionManagementScreen(),
    ),
    GoRoute(
      path: '/qr',
      builder: (context, state) => const QRManagementScreen(),
    ),
    GoRoute(
      path: '/qr/scan',
      builder: (context, state) => const QRScannerScreen(),
    ),
    GoRoute(
      path: '/statistics',
      builder: (context, state) => const StatisticsScreen(),
    ),
    GoRoute(
      path: '/batch-qr',
      builder: (context, state) => const BatchQRCreationScreen(),
    ),
    GoRoute(
      path: '/print/select',
      builder: (context, state) => const SelectPlantsForPrintScreen(),
    ),
    GoRoute(
      path: '/print/settings',
      builder: (context, state) {
        final plants = state.extra as List<Plant>?;
        if (plants == null) {
          return const Scaffold(
            body: Center(child: Text('Растения не переданы')),
          );
        }
        return PrintSettingsScreen(plantsToPrint: plants);
      },
    ),
    GoRoute(
      path: '/plant-list',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final plants = extra?['plants'] as List<Plant>?;
        final title = extra?['title'] as String?;
        if (plants == null || title == null) {
          return const Scaffold(
            body: Center(child: Text('Некорректные данные')),
          );
        }
        return PlantListScreen(plants: plants, title: title);
      },
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CareCalendarScreen(),
    ),
    GoRoute(
      path: '/wintering',
      builder: (context, state) => const WinteringScreen(),
    ),
    GoRoute(
      path: '/plant-statistics',
      builder: (context, state) {
        final plant = state.extra as Plant?;
        if (plant == null) {
          return const Scaffold(
            body: Center(child: Text('Растение не передано')),
          );
        }
        return PlantStatisticsScreen(plant: plant);
      },
    ),
    GoRoute(
      path: '/germination-chart/:year',
      builder: (context, state) {
        final yearStr = state.pathParameters['year'];
        final year = int.tryParse(yearStr ?? '');
        if (year == null) {
          return const Scaffold(
            body: Center(child: Text('Некорректный год')),
          );
        }
        return YearGerminationChartScreen(year: year);
      },
    ),
    GoRoute(
      path: '/sowing/add',
      builder: (context, state) => const AddSowingYearScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/appearance',
      builder: (context, state) => const AppearanceSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/cloud',
      builder: (context, state) => const CloudSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/weather',
      builder: (context, state) => const WeatherSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/backup',
      builder: (context, state) => const BackupSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/notifications',
      builder: (context, state) => const NotificationsSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/behavior',
      builder: (context, state) => const BehaviorSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/experiments',
      builder: (context, state) => const ExperimentsSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/data',
      builder: (context, state) => const DataManagementScreen(),
    ),
    GoRoute(
      path: '/settings/debug',
      builder: (context, state) => const DebugSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/system',
      builder: (context, state) => const SystemSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/about',
      builder: (context, state) => const AboutScreen(),
    ),
  ],
);
