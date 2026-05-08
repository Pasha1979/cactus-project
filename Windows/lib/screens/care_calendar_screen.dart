import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/plant_provider.dart';

class CareCalendarScreen extends StatefulWidget {
  const CareCalendarScreen({super.key});

  @override
  State<CareCalendarScreen> createState() => _CareCalendarScreenState();
}

class _CareCalendarScreenState extends State<CareCalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantProvider>();
    final allPlants = provider.plants
        .where((p) => p.status != 'dead' && p.status != 'failed')
        .toList();

    final filteredPlants = allPlants.where((plant) {
      final query = _searchQuery.toLowerCase();
      return plant.latinName.toLowerCase().contains(query) ||
          plant.displayId.toLowerCase().contains(query);
    }).toList();

    final currentTab = _tabController.index;
    final selectedCount = _selectedIds.length;

    final tabColors = [Colors.blue, Colors.green, Colors.orange];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Календарь ухода'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          tabs: [
            Tab(
                icon: Icon(Icons.water_drop, color: tabColors[0]),
                text: 'Полив'),
            Tab(
                icon: Icon(Icons.local_florist, color: tabColors[1]),
                text: 'Пересадка'),
            Tab(icon: Icon(Icons.eco, color: tabColors[2]), text: 'Подкормка'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск по названию или ID...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  if (selectedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Выбрано: $selectedCount растений',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 400,
              child: TableCalendar(
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    _selectedDay != null && isSameDay(day, _selectedDay),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final normalized =
                        DateTime(date.year, date.month, date.day);
                    List<Widget> markers = [];

                    if (currentTab == 0) {
                      final isGlobal = provider.globalWateringDates.any((d) =>
                          d.year == date.year &&
                          d.month == date.month &&
                          d.day == date.day);
                      final individual =
                          provider.individualWateringDates[normalized] ?? [];
                      final customCount =
                          provider.customWateringDates[normalized] ?? 0;

                      if (isGlobal) {
                        markers.add(const Positioned(
                          bottom: 4,
                          child: Icon(Icons.water_drop,
                              color: Colors.blue, size: 16),
                        ));
                      }
                      if (customCount > 0 || individual.isNotEmpty) {
                        markers.add(const Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(Icons.local_drink,
                              color: Colors.green, size: 16),
                        ));
                      }
                    } else if (currentTab == 1) {
                      final needsTransplant = filteredPlants.any((p) {
                        final next = p.plannedTransplantDate ??
                            p.getRecommendedTransplantDate();
                        return next != null && isSameDay(next, date);
                      });
                      if (needsTransplant) {
                        markers.add(const Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(Icons.warning_amber,
                              color: Colors.red, size: 16),
                        ));
                      }
                    } else if (currentTab == 2) {
                      final fertilized =
                          provider.fertilizationDates[normalized] ?? [];
                      final planned =
                          provider.plannedFertilizationDates[normalized] ?? [];
                      if (fertilized.isNotEmpty || planned.isNotEmpty) {
                        markers.add(Positioned(
                          bottom: 4,
                          child: Icon(
                            Icons.eco,
                            color: planned.isNotEmpty &&
                                    date.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.orange,
                            size: 16,
                          ),
                        ));
                      }
                    }

                    return markers.isNotEmpty ? Stack(children: markers) : null;
                  },
                ),
              ),
            ),
            if (_selectedDay != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey..withValues(alpha:0.2),
                      spreadRadius: 1,
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (currentTab == 0)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.water_drop),
                        label: const Text('Отметить полив всей коллекции'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600),
                        onPressed: () {
                          provider.addGlobalWateringDate(_selectedDay!);
                          provider.updateRecommendedWateringDates();
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Полив всей коллекции отмечен')),
                          );
                        },
                      ),
                    if (currentTab == 1 || currentTab == 2)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: Text(currentTab == 1
                            ? 'Отметить пересадку'
                            : 'Отметить подкормку'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              currentTab == 1 ? Colors.green : Colors.orange,
                        ),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () {
                                if (currentTab == 1) {
                                  _markGroupAsTransplanted();
                                } else {
                                  provider.markGroupAsFertilized(_selectedIds,
                                      date: _selectedDay);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Подкормка отмечена')),
                                  );
                                }
                              },
                      ),
                    if (currentTab == 1 || currentTab == 2)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Запланировать'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () => _planGroupAction(currentTab),
                      ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('Очистить дату'),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _clearDataForDate(currentTab),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 320,
              child: filteredPlants.isEmpty
                  ? const Center(
                      child: Text('Растения не найдены',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: filteredPlants.length,
                      itemBuilder: (context, index) {
                        final plant = filteredPlants[index];
                        final isSelected =
                            _selectedIds.contains(plant.permanentId);

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          color: isSelected ? Colors.green.shade50 : null,
                          child: ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(plant.permanentId);
                                  } else {
                                    _selectedIds.remove(plant.permanentId);
                                  }
                                });
                              },
                            ),
                            title: Text(plant.latinName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('ID: ${plant.displayId}'),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(plant.permanentId);
                                } else {
                                  _selectedIds.add(plant.permanentId);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _markGroupAsTransplanted() {
    final provider = context.read<PlantProvider>();
    for (var id in _selectedIds) {
      final plant = provider.getPlantById(id);
      final updated = plant.copyWith(
        lastRepotting: DateTime.now(),
        plannedTransplantDate: null,
      );
      provider.updatePlant(id, updated);
    }
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пересадка отмечена')),
    );
  }

  void _planGroupAction(int tab) async {
    if (!mounted) return;
    final provider = context.read<PlantProvider>();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (!mounted || selectedDate == null) return;

    if (tab == 1) {
      for (var id in _selectedIds) {
        final plant = provider.getPlantById(id);
        final updated = plant.copyWith(plannedTransplantDate: selectedDate);
        provider.updatePlant(id, updated);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пересадка запланирована')),
      );
    } else if (tab == 2) {
      provider.planGroupFertilization(_selectedIds, selectedDate);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Подкормка запланирована')),
      );
    }

    setState(() => _selectedIds.clear());
  }

  void _clearDataForDate(int tab) {
    if (_selectedDay == null || !mounted) return;
    final provider = context.read<PlantProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить дату'),
        content: const Text('Удалить все записи для этой даты?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              if (tab == 0) {
                provider.clearWateringDataForDate(_selectedDay!);
              } else if (tab == 2) {
                provider.invalidateFertilizationDatesCache();
              }
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Дата очищена')),
              );
            },
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
