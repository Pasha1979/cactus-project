import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/plant.dart';
import '../presentation/providers/providers.dart';

class AddPlantScreen extends StatefulWidget {
  const AddPlantScreen({super.key});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
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
      final provider = context.read<PlantCrudProvider>();
      _numberController.text =
          provider.getNextCustomNumber(year, _category).toString();
    }
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return 'Обязательное поле';
    final number = int.tryParse(value);
    if (number == null) return 'Введите число';
    final year = int.tryParse(_yearController.text);
    if (year == null) return 'Сначала укажите год';
    final provider = context.read<PlantCrudProvider>();
    return provider.isCustomNumberUnique(year, number, _category)
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
                onTap: () => Navigator.pop(ctx, year),
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
        debugPrint('Добавлено растение: ${newPlant.latinName}');
        context.pop(newPlant);
      } catch (e) {
        debugPrint('Ошибка в _saveForm: $e');
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
                    onPressed: _showYearPicker,
                  ),
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
                  hintText: 'Пример: 3 → ID: 23-003',
                ),
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
                    horizontal: 20, vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
