import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/plant_provider.dart';

class WinteringScreen extends StatelessWidget {
  const WinteringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Зимовка'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: WinteringContent(),
      ),
    );
  }
}

class WinteringContent extends StatefulWidget {
  const WinteringContent({super.key});

  @override
  State<WinteringContent> createState() => _WinteringContentState();
}

class _WinteringContentState extends State<WinteringContent> {
  @override
  Widget build(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCalendarSection(plantProvider),
          const SizedBox(height: 16),
          _buildTemperatureSection(plantProvider),
          const SizedBox(height: 16),
          _buildRecommendationSection(plantProvider),
          const SizedBox(height: 16),
          _buildLogSection(plantProvider),
        ],
      ),
    );
  }

  Widget _buildCalendarSection(PlantProvider plantProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Календарь зимовки',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate:
                            plantProvider.winteringStartDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selectedDate != null) {
                        plantProvider.winteringStartDate = selectedDate;
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата начала',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        plantProvider.winteringStartDate != null
                            ? _formatDate(plantProvider.winteringStartDate!)
                            : 'Выберите дату',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate:
                            plantProvider.winteringEndDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selectedDate != null) {
                        plantProvider.winteringEndDate = selectedDate;
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата окончания',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        plantProvider.winteringEndDate != null
                            ? _formatDate(plantProvider.winteringEndDate!)
                            : 'Выберите дату',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Статус: ${_getWinteringStatus(plantProvider)}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureSection(PlantProvider plantProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Температурный мониторинг',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Текущая температура (°C)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.thermostat),
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                  text: plantProvider.winteringTemperature?.toString()),
              onChanged: (value) {
                plantProvider.winteringTemperature = double.tryParse(value);
                _showTemperatureWarning(plantProvider);
              },
            ),
            if (plantProvider.winteringTemperature != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  plantProvider.winteringTemperature! >= 5 &&
                          plantProvider.winteringTemperature! <= 13
                      ? 'Температура в норме'
                      : 'Температура вне диапазона!',
                  style: TextStyle(
                    color: plantProvider.winteringTemperature! >= 5 &&
                            plantProvider.winteringTemperature! <= 13
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSection(PlantProvider plantProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Рекомендации по поливу',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
            const SizedBox(height: 12),
            Text(
              _getWateringRecommendation(plantProvider),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogSection(PlantProvider plantProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Журнал состояния',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addLogEntry(plantProvider),
                  tooltip: 'Добавить запись',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (plantProvider.winteringLogEntries.isEmpty)
              const Text('Нет записей', style: TextStyle(color: Colors.grey))
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plantProvider.winteringLogEntries.length,
                  itemBuilder: (context, index) {
                    final entry = plantProvider.winteringLogEntries[index];
                    return ListTile(
                      title: Text(entry.description),
                      subtitle: Text(_formatDate(entry.date)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _getWinteringStatus(PlantProvider plantProvider) {
    final now = DateTime.now();
    if (plantProvider.winteringStartDate == null ||
        plantProvider.winteringEndDate == null) {
      return 'Не установлены даты зимовки';
    }
    if (now.isBefore(plantProvider.winteringStartDate!)) {
      return 'Подготовка к зимовке';
    } else if (now.isAfter(plantProvider.winteringEndDate!)) {
      return 'Зимовка завершена';
    } else {
      return 'Активная зимовка';
    }
  }

  String _getWateringRecommendation(PlantProvider plantProvider) {
    final now = DateTime.now();
    if (plantProvider.winteringStartDate == null ||
        plantProvider.winteringEndDate == null) {
      return 'Установите даты зимовки для получения рекомендаций';
    }
    if (now.month == 9) {
      return 'Сократите полив для подготовки к зимовке';
    } else if (now.isAfter(plantProvider.winteringStartDate!) &&
        now.isBefore(plantProvider.winteringEndDate!)) {
      return 'Полив не требуется';
    } else if (now.month == 3 && now.isAfter(plantProvider.winteringEndDate!)) {
      return 'Опрыскайте кактусы, через неделю начните скудный полив';
    } else {
      return 'Следуйте обычному графику полива';
    }
  }

  void _showTemperatureWarning(PlantProvider plantProvider) {
    if (plantProvider.winteringTemperature != null &&
        (plantProvider.winteringTemperature! < 5 ||
            plantProvider.winteringTemperature! > 13)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Температура вне диапазона! Текущая: ${plantProvider.winteringTemperature}°C'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addLogEntry(PlantProvider plantProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая запись'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Описание'),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              plantProvider.addWinteringLogEntry(
                WinteringLogEntry(date: DateTime.now(), description: value),
              );
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }
}
