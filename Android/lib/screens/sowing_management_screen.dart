import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/providers.dart';
import '../models/plant.dart';

class SowingManagementScreen extends StatelessWidget {
  const SowingManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantCrudProvider>();
    final years = provider.getUniqueSowingYears();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление посевами'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ListView.separated(
          itemCount: years.length + 1,
          separatorBuilder: (context, index) => Divider(),
          itemBuilder: (context, index) {
            if (index < years.length) {
              final year = years[index];
              final plantCount = provider.getPlantCountForYear(year);
              return Card(
                elevation: 4,
                margin: const EdgeInsets.all(8),
                child: InkWell(
                  onTap: () {
                    context.push('/sowing-year/$year');
                  },
                  child: ListTile(
                    title: Text(year.toString(),
                        style: const TextStyle(fontSize: 20)),
                    subtitle: Text('Количество растений: $plantCount'),
                  ),
                ),
              );
            } else {
              return _buildAddYearButton(context);
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Добавить новый посев',
        elevation: 2,
        shape: CircleBorder(),
        foregroundColor: Colors.white,
        onPressed: () {
          context.push('/sowing/add');
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildAddYearButton(BuildContext context) {
    return Card(
      color: Colors.green[100],
      child: InkWell(
        onTap: () => context.push('/sowing/add'),
        child: const Center(
          child: Icon(Icons.add, size: 40),
        ),
      ),
    );
  }
}

class SowingYearDetailsScreen extends StatefulWidget {
  final int year;

  const SowingYearDetailsScreen({super.key, required this.year});

  @override
  State<SowingYearDetailsScreen> createState() =>
      _SowingYearDetailsScreenState();
}

class _SowingYearDetailsScreenState extends State<SowingYearDetailsScreen> {
  late List<Plant> _editablePlants;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PlantCrudProvider>();
    _editablePlants = provider.plants
        .where((p) => p.year == widget.year && p.category == 'sown')
        .map((p) => p.copyWith())
        .toList();
  }

  void _saveChanges() {
    final provider = context.read<PlantCrudProvider>();
    for (final updatedPlant in _editablePlants) {
      final index = provider.plants
          .indexWhere((p) => p.permanentId == updatedPlant.permanentId);

      if (index != -1) {
        provider.updatePlant(updatedPlant.permanentId, updatedPlant);
      } else {
        provider.addPlant(updatedPlant);
      }
    }
    provider.savePlants();
    Navigator.pop(context);
  }

  // ==================== ВЕРХНЯЯ СТАТИСТИКА ГОДА ====================
  Widget _buildYearSummary() {
    int totalPlants = _editablePlants.length;
    int totalSeeds = _editablePlants.fold(0, (sum, p) => sum + p.seedsCount);

    // Правильный расчёт всех живых сеянцев по всем растениям года
    int totalAlive = 0;
    for (var plant in _editablePlants) {
      int alive = 0;
      for (var record in plant.germinationHistory) {
        alive += record.germinatedCount - record.deadCount;
      }
      if (alive < 0) alive = 0;
      totalAlive += alive;
    }

    double germinationRate =
        totalSeeds > 0 ? (totalAlive / totalSeeds * 100) : 0.0;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [
              Text('$totalPlants',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('Растений')
            ]),
            Column(children: [
              Text('$totalSeeds',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('Семян')
            ]),
            Column(children: [
              Text('$totalAlive',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('Живых')
            ]),
            Column(children: [
              Text('${germinationRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
              const Text('Пророст')
            ]),
          ],
        ),
      ),
    );
  }

  // ==================== ЕДИНЫЙ СПИСОК РАСТЕНИЙ ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Посев ${widget.year} года'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
          ),
          IconButton(
            icon: const Icon(Icons.show_chart, color: Colors.purple, size: 28),
            tooltip: 'График живых сеянцев за год',
            onPressed: () {
              context.push('/germination-chart/${widget.year}');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildYearSummary(),
            const Divider(height: 1),

            // Один список с ExpansionTile для каждого растения
            ..._editablePlants.map((plant) {
// Расчёт живых сеянцев: используем aliveCount если задан, иначе авторасчёт из истории
              final int currentAlive = plant.getCurrentAliveCount;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ExpansionTile(
                  leading: const Icon(Icons.spa, color: Colors.green),
                  title: Row(
                    children: [
                      Text(
                        '${plant.displayId} — ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[700],
                          fontSize: 16,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          plant.latinName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Семян: ${plant.seedsCount} • Живых: $currentAlive',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Редактируемые поля
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: plant.latinName,
                                  decoration: const InputDecoration(
                                      labelText: 'Название'),
                                  onChanged: (v) {
                                    setState(() {
                                      final index =
                                          _editablePlants.indexOf(plant);
                                      _editablePlants[index] =
                                          plant.copyWith(latinName: v.trim());
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: plant.seedsCount.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Всего семян'),
                                  onChanged: (v) {
                                    setState(() {
                                      final cnt = int.tryParse(v) ?? 0;
                                      final index =
                                          _editablePlants.indexOf(plant);
                                      _editablePlants[index] =
                                          plant.copyWith(seedsCount: cnt);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: plant.aliveCount?.toString() ??
                                      currentAlive.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Живых сейчас',
                                    helperText: plant.aliveCount != null
                                        ? 'Ручной ввод'
                                        : 'Авто (из истории)',
                                    helperStyle: TextStyle(
                                      color: plant.aliveCount != null
                                          ? Colors.orange
                                          : Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      final cnt = int.tryParse(v);
                                      final index =
                                          _editablePlants.indexOf(plant);
                                      // Если введено число — сохраняем в aliveCount (ручной ввод)
                                      // Если пусто — null (авторасчёт)
                                      _editablePlants[index] = plant.copyWith(
                                        aliveCount: cnt,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: plant.fieldNumber ?? '',
                                  decoration: const InputDecoration(
                                      labelText: 'Полевой номер'),
                                  onChanged: (v) {
                                    setState(() {
                                      final val =
                                          v.trim().isEmpty ? null : v.trim();
                                      final index =
                                          _editablePlants.indexOf(plant);
                                      _editablePlants[index] =
                                          plant.copyWith(fieldNumber: val);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: plant.seller ?? '',
                                  decoration: const InputDecoration(
                                      labelText: 'Источник'),
                                  onChanged: (v) {
                                    setState(() {
                                      final val =
                                          v.trim().isEmpty ? null : v.trim();
                                      final index =
                                          _editablePlants.indexOf(plant);
                                      _editablePlants[index] =
                                          plant.copyWith(seller: val);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 180,
                            child: TextFormField(
                              initialValue: plant.harvestYear?.toString() ?? '',
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Год сбора'),
                              onChanged: (v) {
                                setState(() {
                                  final year = int.tryParse(v);
                                  final index = _editablePlants.indexOf(plant);
                                  _editablePlants[index] =
                                      plant.copyWith(harvestYear: year);
                                });
                              },
                            ),
                          ),
// Кнопка статистики для этого растения
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(Icons.bar_chart,
                                  color: Colors.purple, size: 28),
                              tooltip: 'Статистика всхожести и выживаемости',
                              onPressed: () {
                                context.push(
                                  '/plant-statistics',
                                  extra: plant,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Кнопка добавления записи (взошло + погибло)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text(
                                'Добавить запись (взошло / погибло)'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            onPressed: () =>
                                _addGerminationRecordForPlant(plant),
                          ),

                          const SizedBox(height: 16),

                          // История записей
                          const Text('История изменений:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ...plant.germinationHistory.map((record) {
                            return ListTile(
                              title: Text(
                                  '${record.date.day}.${record.date.month}.${record.date.year}'),
                              subtitle: Text(
                                'Взошло: +${record.germinatedCount} • Погибло: -${record.deadCount}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () =>
                                        _editGerminationRecord(plant, record),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _deleteGerminationRecord(plant, record),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (plant.germinationHistory.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('Записей пока нет',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================== МЕТОДЫ ДЛЯ ИСТОРИИ ====================

  Future<void> _addGerminationRecordForPlant(Plant plant) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(widget.year),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;

    final int? germinated = await _showNumberDialog('Сколько взошло?');
    if (germinated == null) return;

    final int? dead = await _showNumberDialog('Сколько погибло? (0 если нет)',
        initialValue: 0);
    if (dead == null) return;

    setState(() {
      final index = _editablePlants.indexOf(plant);
      if (index == -1) return;

      final newHistory = List<GerminationRecord>.from(plant.germinationHistory)
        ..add(GerminationRecord(
          date: date,
          germinatedCount: germinated,
          deadCount: dead,
        ));

      _editablePlants[index] = plant.copyWith(
        germinationHistory: newHistory,
        lastModified: DateTime.now(), // ← Добавили
      );
    });
  }

  Future<void> _editGerminationRecord(
      Plant plant, GerminationRecord oldRecord) async {
    final DateTime? newDate = await showDatePicker(
      context: context,
      initialDate: oldRecord.date,
      firstDate: DateTime(widget.year),
      lastDate: DateTime.now(),
    );
    if (newDate == null) return;

    final int? newGerminated = await _showNumberDialog('Сколько взошло?',
        initialValue: oldRecord.germinatedCount);
    if (newGerminated == null) return;

    final int? newDead = await _showNumberDialog('Сколько погибло?',
        initialValue: oldRecord.deadCount);
    if (newDead == null) return;

    setState(() {
      final index = _editablePlants.indexOf(plant);
      if (index == -1) return;

      final newHistory = List<GerminationRecord>.from(plant.germinationHistory)
        ..remove(oldRecord)
        ..add(GerminationRecord(
          date: newDate,
          germinatedCount: newGerminated,
          deadCount: newDead,
        ));

      _editablePlants[index] = plant.copyWith(
        germinationHistory: newHistory,
        lastModified: DateTime.now(),
      );
    });
  }

  void _deleteGerminationRecord(Plant plant, GerminationRecord record) {
    setState(() {
      final index = _editablePlants.indexOf(plant);
      if (index == -1) return;

      final newHistory = List<GerminationRecord>.from(plant.germinationHistory)
        ..remove(record);

      _editablePlants[index] = plant.copyWith(
        germinationHistory: newHistory,
        lastModified: DateTime.now(),
      );
    });
  }

  // Диалог ввода числа
  Future<int?> _showNumberDialog(String title, {int initialValue = 0}) async {
    final controller = TextEditingController(text: initialValue.toString());
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx, val);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
