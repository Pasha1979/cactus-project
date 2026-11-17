import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:provider/provider.dart';
import '../models/plant.dart';
import '../providers/plant_provider.dart';
import 'package:intl/intl.dart';

class YearGerminationChartScreen extends StatefulWidget {
  final int year;

  const YearGerminationChartScreen({super.key, required this.year});

  @override
  State<YearGerminationChartScreen> createState() =>
      _YearGerminationChartScreenState();
}

class _YearGerminationChartScreenState
    extends State<YearGerminationChartScreen> {
  late List<Plant> _plants;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<PlantProvider>(context, listen: false);
    _plants = provider.plants
        .where((p) => p.year == widget.year && p.category == 'sown')
        .toList();
  }

  // Собираем все уникальные даты из всех историй
  List<DateTime> _getAllDates() {
    final dates = <DateTime>{};
    for (var plant in _plants) {
      for (var rec in plant.germinationHistory) {
        dates.add(DateTime(rec.date.year, rec.date.month, rec.date.day));
      }
    }
    final sorted = dates.toList()..sort();
    return sorted;
  }

  List<CartesianSeries<LiveDataPoint, DateTime>> _buildSeries() {
    final allDates = _getAllDates();
    final series = <CartesianSeries<LiveDataPoint, DateTime>>[];

    for (var plant in _plants) {
      final points = <LiveDataPoint>[];

      int alive = 0;
      int dateIndex = 0;

      for (var date in allDates) {
        // Добавляем все изменения за этот день
        while (dateIndex < plant.germinationHistory.length &&
            DateTime(
              plant.germinationHistory[dateIndex].date.year,
              plant.germinationHistory[dateIndex].date.month,
              plant.germinationHistory[dateIndex].date.day,
            ).isAtSameMomentAs(date)) {
          final rec = plant.germinationHistory[dateIndex];
          alive += rec.germinatedCount - rec.deadCount;
          dateIndex++;
        }

        if (alive < 0) alive = 0;
        points.add(LiveDataPoint(date, alive.toDouble()));
      }

      series.add(
        LineSeries<LiveDataPoint, DateTime>(
          name: plant.latinName,
          dataSource: points,
          xValueMapper: (d, _) => d.date,
          yValueMapper: (d, _) => d.alive,
          color: _getColorForPlant(plant)
              .withValues(alpha: 0.9), // исправлено устаревшее withOpacity
          markerSettings: const MarkerSettings(
              isVisible: true, shape: DataMarkerType.circle),
          enableTooltip: true,
        ),
      );
    }

    return series;
  }

  // Простая функция для разных цветов (можно заменить на Palette)
  Color _getColorForPlant(Plant plant) {
    final hash = plant.latinName.hashCode;
    return Color.fromARGB(
      255,
      (hash & 0xFF0000) >> 16,
      (hash & 0x00FF00) >> 8,
      hash & 0x0000FF,
    ).withValues(alpha:0.9);
  }

  @override
  Widget build(BuildContext context) {
    final allDates = _getAllDates();

    return Scaffold(
      appBar: AppBar(
        title: Text('Живые сеянцы — ${widget.year} год'),
      ),
      body: allDates.isEmpty
          ? const Center(child: Text('Нет данных по всхожести в этом году'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SfCartesianChart(
                title:
                    const ChartTitle(text: 'Динамика живых сеянцев по видам'),
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                primaryXAxis: DateTimeAxis(
                  dateFormat: DateFormat('dd.MM'),
                  intervalType: DateTimeIntervalType.days,
                  labelRotation: -45,
                ),
                primaryYAxis: NumericAxis(
                  title: const AxisTitle(text: 'Количество живых сеянцев'),
                  minimum: 0,
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  shouldAlwaysShow: true,
                  color: Colors.black87,
                  textStyle: const TextStyle(color: Colors.white),
                ),
                series: _buildSeries(),
              ),
            ),
    );
  }
}

// Вспомогательный класс для точек графика
class LiveDataPoint {
  final DateTime date;
  final double alive;

  LiveDataPoint(this.date, this.alive);
}
