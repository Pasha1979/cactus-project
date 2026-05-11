import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/plant.dart';
import '../../screens/add_sowing_year_screen.dart';
import '../../screens/batch_qr_creation_screen.dart';
import '../../screens/care_calendar_screen.dart';
import '../../screens/collection_management_screen.dart';
import '../../screens/edit_plant_screen.dart';
import '../../screens/plant_statistics_screen.dart';
import '../../screens/print_settings_screen.dart';
import '../../screens/qr_management_screen.dart';
import '../../screens/select_plants_for_print_screen.dart';
import '../../screens/sowing_management_screen.dart';
import '../../screens/statistics_screen.dart';
import '../../screens/welcome_screen.dart';
import '../../screens/wintering_screen.dart';
import '../../screens/year_germination_chart_screen.dart';
import '../screens/plant_card/plant_card_screen.dart';
import '../../main.dart' show HomeScreen;

/// Централизованный роутер приложения.
///
/// Маршруты с параметрами-объектами (`Plant`, `List<Plant>`) принимают данные
/// через `state.extra`. Deep linking для таких маршрутов требует
/// доработки конструкторов экранов (загрузка по ID из Provider).
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
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
      path: '/add-sowing-year',
      builder: (context, state) => const AddSowingYearScreen(),
    ),
  ],
);
