import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../models/plant.dart';
import '../presentation/providers/providers.dart';

class PlantStatisticsScreen extends StatefulWidget {
  final Plant plant;

  const PlantStatisticsScreen({super.key, required this.plant});

  @override
  State<PlantStatisticsScreen> createState() => PlantStatisticsScreenState();
}

class PlantStatisticsScreenState extends State<PlantStatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Статистика: ${widget.plant.latinName}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Всхожесть'),
            Tab(text: 'Цветение'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGerminationTab(),
          _buildFloweringTab(),
        ],
      ),
    );
  }

  Widget _buildGerminationTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSummaryPercentages(), // Итоговые проценты с выживаемостью
          const SizedBox(height: 24),
          _buildGerminationChart(), // График с двумя линиями
        ],
      ),
    );
  }

// === Итоговые проценты — теперь правильно считают живое количество ===
  Widget _buildSummaryPercentages() {
    final totalSeeds = widget.plant.seedsCount;

    // Общее взошедшее = сумма всех germinatedCount по истории
    int totalGerminated = 0;
    for (var record in widget.plant.germinationHistory) {
      totalGerminated += record.germinatedCount;
    }

    // Реальное живое количество = взошло всего минус погибло всего
    int currentAlive = 0;
    for (var record in widget.plant.germinationHistory) {
      currentAlive += record.germinatedCount - record.deadCount;
    }
    if (currentAlive < 0) currentAlive = 0;

    final germinationRate = totalSeeds > 0
        ? (totalGerminated / totalSeeds * 100).toStringAsFixed(1)
        : '0.0';

    final survivalRate = totalGerminated > 0
        ? (currentAlive / totalGerminated * 100).toStringAsFixed(1)
        : '0.0';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text('$germinationRate%',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,),),
                const Text('Всхожесть',
                    style: TextStyle(fontSize: 15, color: Colors.grey),),
              ],
            ),
            Column(
              children: [
                Text('$survivalRate%',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,),),
                const Text('Выживаемость',
                    style: TextStyle(fontSize: 15, color: Colors.grey),),
              ],
            ),
          ],
        ),
      ),
    );
  }

// === График с тремя линиями: всхожесть, погибшие, живые ===
  Widget _buildGerminationChart() {
    final sortedHistory =
        List<GerminationRecord>.from(widget.plant.germinationHistory)
          ..sort((a, b) => a.date.compareTo(b.date));

    final List<ChartData> germData = []; // накопительная всхожесть (зелёная)
    final List<ChartData> deadData =
        []; // накопительные погибшие (оранжевая/жёлтая)
    final List<ChartData> aliveData = []; // текущее живое количество (красная)

    int cumulativeGerminated = 0;
    int cumulativeDead = 0;

    for (var record in sortedHistory) {
      cumulativeGerminated += record.germinatedCount;
      cumulativeDead += record.deadCount;

      germData.add(ChartData(record.date.toString().substring(0, 10),
          cumulativeGerminated.toDouble(),),);
      deadData.add(ChartData(
          record.date.toString().substring(0, 10), cumulativeDead.toDouble(),),);

      // Живое = взошло всего минус погибло всего
      int alive = cumulativeGerminated - cumulativeDead;
      if (alive < 0) alive = 0;
      aliveData.add(
          ChartData(record.date.toString().substring(0, 10), alive.toDouble()),);
    }

    return SfCartesianChart(
      title: const ChartTitle(text: 'Всхожесть, гибель и выживаемость семян'),
      primaryXAxis: CategoryAxis(
        title: const AxisTitle(text: 'Дата'),
        labelRotation: -45,
      ),
      primaryYAxis:
          NumericAxis(title: const AxisTitle(text: 'Количество семян')),
      legend: const Legend(isVisible: true, position: LegendPosition.bottom),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries>[
        // Зелёная — накопительная всхожесть
        LineSeries<ChartData, String>(
          name: 'Всхожесть (всего взошло)',
          dataSource: germData,
          xValueMapper: (d, _) => d.category,
          yValueMapper: (d, _) => d.value,
          color: Colors.green,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
        // Оранжевая/жёлтая — накопительная гибель
        LineSeries<ChartData, String>(
          name: 'Гибель (всего погибло)',
          dataSource: deadData,
          xValueMapper: (d, _) => d.category,
          yValueMapper: (d, _) => d.value,
          color: Colors.orange,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
        // Красная — текущее живое количество
        LineSeries<ChartData, String>(
          name: 'Живых осталось',
          dataSource: aliveData,
          xValueMapper: (d, _) => d.category,
          yValueMapper: (d, _) => d.value,
          color: Colors.red,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _buildFloweringTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildFloweringCalendar(),
            const SizedBox(height: 16),
            _buildFloweringChart(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearFloweringData,
              child: const Text('Очистить данные цветения'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloweringCalendar() {
    final plantCrud = Provider.of<PlantCrudProvider>(context, listen: false);
    final floweringEvents = widget.plant.floweringHistory;

    Map<DateTime, List<String>> events = {};
    for (var record in floweringEvents) {
      final date =
          DateTime(record.date.year, record.date.month, record.date.day);
      events[date] = [record.event];
    }

    return TableCalendar(
      firstDay: DateTime(widget.plant.year, 1, 1),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: DateTime.now(),
      calendarFormat: CalendarFormat.month,
      eventLoader: (day) {
        return events[DateTime(day.year, day.month, day.day)] ?? [];
      },
      calendarStyle: CalendarStyle(
        markersAlignment: Alignment.bottomCenter,
        markerDecoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          for (var record in floweringEvents) {
            if (record.event == 'bloomed') {
              final bloomDate = DateTime(
                  record.date.year, record.date.month, record.date.day,);
              final nextWilt = floweringEvents
                  .where(
                      (r) => r.event == 'wilted' && r.date.isAfter(record.date),)
                  .firstOrNull;
              final wiltDate = nextWilt != null
                  ? DateTime(nextWilt.date.year, nextWilt.date.month,
                      nextWilt.date.day,)
                  : null;
              if (wiltDate != null &&
                  day.isAfter(bloomDate.subtract(const Duration(days: 1))) &&
                  day.isBefore(wiltDate.add(const Duration(days: 1)))) {
                return Container(
                  margin: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(255, 235, 59, 0.3), // Исправлено
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                );
              }
            }
          }
          return null;
        },
        markerBuilder: (context, day, events) {
          if (events.isNotEmpty) {
            return Positioned(
              bottom: 1,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: events[0] == 'bloomed' ? Colors.green : Colors.red,
                ),
              ),
            );
          }
          return null;
        },
      ),
      onDaySelected: (selectedDay, focusedDay) {
        _showFloweringDialog(selectedDay, plantCrud);
      },
    );
  }

  void _showFloweringDialog(DateTime selectedDay, PlantCrudProvider plantCrud) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              'Отметить цветение (${selectedDay.toString().substring(0, 10)})',),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  plantCrud.addFloweringEvent(
                      widget.plant.permanentId, selectedDay, 'bloomed',);
                  Navigator.pop(context);
                },
                child: const Text('Расцвёл'),
              ),
              ElevatedButton(
                onPressed: () {
                  plantCrud.addFloweringEvent(
                      widget.plant.permanentId, selectedDay, 'wilted',);
                  Navigator.pop(context);
                },
                child: const Text('Завял'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloweringChart() {
    final floweringEvents = widget.plant.floweringHistory;
    List<ChartData> data = [];
    DateTime? bloomStart;

    for (var i = 0; i < floweringEvents.length; i++) {
      if (floweringEvents[i].event == 'bloomed') {
        bloomStart = floweringEvents[i].date;
      } else if (floweringEvents[i].event == 'wilted' && bloomStart != null) {
        final duration =
            floweringEvents[i].date.difference(bloomStart).inDays.toDouble();
        data.add(ChartData(bloomStart.toString().substring(0, 10), duration));
        bloomStart = null;
      }
    }

    return SfCartesianChart(
      title: ChartTitle(text: 'Периоды цветения'),
      primaryXAxis:
          CategoryAxis(title: AxisTitle(text: 'Дата начала цветения')),
      primaryYAxis: NumericAxis(title: AxisTitle(text: 'Длительность (дни)')),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <ColumnSeries<ChartData, String>>[
        ColumnSeries<ChartData, String>(
          dataSource: data,
          xValueMapper: (ChartData d, _) => d.category,
          yValueMapper: (ChartData d, _) => d.value,
          color: Colors.orange,
        ),
      ],
    );
  }

  void _clearFloweringData() {
    final plantCrud = Provider.of<PlantCrudProvider>(context, listen: false);
    plantCrud.clearFloweringData(widget.plant.permanentId);
    if (mounted) {
      setState(() {}); // Обновляем UI
    }
  }
}

class ChartData {
  final String category;
  final double value;
  ChartData(this.category, this.value);
}
