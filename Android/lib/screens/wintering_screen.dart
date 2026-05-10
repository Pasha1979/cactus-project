import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/providers.dart';
import '../utils/responsive_helper.dart';

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
    final winteringProvider = Provider.of<WinteringProvider>(context);
    final isMobile = Responsive.isMobile(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendarSection(winteringProvider),
            const SizedBox(height: 16),
            _buildTemperatureSection(winteringProvider),
            const SizedBox(height: 16),
            _buildRecommendationSection(winteringProvider),
            const SizedBox(height: 16),
            _buildLogSection(winteringProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(WinteringProvider winteringProvider) {
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
                            winteringProvider.winteringStartDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selectedDate != null) {
                        winteringProvider.winteringStartDate = selectedDate;
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата начала',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        winteringProvider.winteringStartDate != null
                            ? _formatDate(winteringProvider.winteringStartDate!)
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
                            winteringProvider.winteringEndDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selectedDate != null) {
                        winteringProvider.winteringEndDate = selectedDate;
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Дата окончания',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        winteringProvider.winteringEndDate != null
                            ? _formatDate(winteringProvider.winteringEndDate!)
                            : 'Выберите дату',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Статус: ${_getWinteringStatus(winteringProvider)}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureSection(WinteringProvider winteringProvider) {
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
                  text: winteringProvider.winteringTemperature?.toString()),
              onChanged: (value) {
                winteringProvider.winteringTemperature = double.tryParse(value);
                _showTemperatureWarning(winteringProvider);
              },
            ),
            if (winteringProvider.winteringTemperature != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  winteringProvider.winteringTemperature! >= 5 &&
                          winteringProvider.winteringTemperature! <= 13
                      ? 'Температура в норме'
                      : 'Температура вне диапазона!',
                  style: TextStyle(
                    color: winteringProvider.winteringTemperature! >= 5 &&
                            winteringProvider.winteringTemperature! <= 13
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

  Widget _buildRecommendationSection(WinteringProvider winteringProvider) {
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
              _getWateringRecommendation(winteringProvider),
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogSection(WinteringProvider winteringProvider) {
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
                  onPressed: () => _addLogEntry(winteringProvider),
                  tooltip: 'Добавить запись',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (winteringProvider.winteringLogEntries.isEmpty)
              const Text('Нет записей', style: TextStyle(color: Colors.grey))
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: winteringProvider.winteringLogEntries.length,
                  itemBuilder: (context, index) {
                    final entry = winteringProvider.winteringLogEntries[index];
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

  String _getWinteringStatus(WinteringProvider winteringProvider) {
    final now = DateTime.now();
    if (winteringProvider.winteringStartDate == null ||
        winteringProvider.winteringEndDate == null) {
      return 'Не установлены даты зимовки';
    }
    if (now.isBefore(winteringProvider.winteringStartDate!)) {
      return 'Подготовка к зимовке';
    } else if (now.isAfter(winteringProvider.winteringEndDate!)) {
      return 'Зимовка завершена';
    } else {
      return 'Активная зимовка';
    }
  }

  String _getWateringRecommendation(WinteringProvider winteringProvider) {
    final now = DateTime.now();
    if (winteringProvider.winteringStartDate == null ||
        winteringProvider.winteringEndDate == null) {
      return 'Установите даты зимовки для получения рекомендаций';
    }
    if (now.month == 9) {
      return 'Сократите полив для подготовки к зимовке';
    } else if (now.isAfter(winteringProvider.winteringStartDate!) &&
        now.isBefore(winteringProvider.winteringEndDate!)) {
      return 'Полив не требуется';
    } else if (now.month == 3 && now.isAfter(winteringProvider.winteringEndDate!)) {
      return 'Опрыскайте кактусы, через неделю начните скудный полив';
    } else {
      return 'Следуйте обычному графику полива';
    }
  }

  void _showTemperatureWarning(WinteringProvider winteringProvider) {
    if (winteringProvider.winteringTemperature != null &&
        (winteringProvider.winteringTemperature! < 5 ||
            winteringProvider.winteringTemperature! > 13)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Температура вне диапазона! Текущая: ${winteringProvider.winteringTemperature}°C'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addLogEntry(WinteringProvider winteringProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая запись'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Описание'),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              winteringProvider.addWinteringLogEntry(
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
