import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/plant.dart';
import 'package:provider/provider.dart';
import '../presentation/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/llifle_service.dart';
import '../core/utils/translation_utils.dart';
import '../core/logger/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

class EditPlantScreen extends StatefulWidget {

  const EditPlantScreen({
    super.key,
    required this.plant,
  });
  final Plant plant;

  @override
  State<EditPlantScreen> createState() => _EditPlantScreenState();
}

class _EditPlantScreenState extends State<EditPlantScreen> {
  late Plant _editedPlant;
  final TextEditingController _latinNameController = TextEditingController();
  final Map<String, String> _speciesCache = {};
  final Map<String, String> _habitatCache = {};
  final Map<String, String> _descriptionCache = {};
  final Map<String, String> _countryCache = {};
  final Map<String, String> _synonymsCache = {};
  final Map<String, String> _countryMapping = {};
  final Map<String, String> _englishToRussianMapping = {};
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _habitatController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _synonymsController = TextEditingController();
  final TextEditingController _careTipsController = TextEditingController();

  void _buildEnglishToRussianMapping() {
    _countryMapping.forEach((russianName, englishName) {
      _englishToRussianMapping[englishName.toLowerCase()] = russianName;
    });
  }

  bool _isLoadingFlag = false;
  String? _flagUrl;
  bool _isFetchingDescription = false;
  bool _isLoadingCountry = false;
  Timer? _debounceTimer;
  bool _isFetchingHabitat = false;
  bool _isFetchingSynonyms = false;
  bool _isFetchingCareTips = false;
  bool _isTranslatingHabitat = false;
  bool _isTranslatingDescription = false;
  bool _isTranslatingCareTips = false;
  final Map<String, String> _careTipsCache = {};

  void _onCountryChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchFlag(value.trim());
    });
  }

  @override
  void initState() {
    super.initState();
    _editedPlant = widget.plant;
    _latinNameController.text = _editedPlant.latinName;
    _countryController.text = _editedPlant.country ?? '';
    _habitatController.text = _editedPlant.habitat ?? '';
    _descriptionController.text = _editedPlant.description ?? '';
    _synonymsController.text = _editedPlant.synonyms ?? '';
    _careTipsController.text = _editedPlant.careTips ?? '';
    if (_editedPlant.countryFlag != null) {
      _flagUrl = _editedPlant.countryFlag;
    }
    _loadCache();
    _loadCountryMapping().then((_) {
      _buildEnglishToRussianMapping();
      if (_editedPlant.country != null && _editedPlant.country!.isNotEmpty) {
        AppLogger.api('Инициализация флага для: ${_editedPlant.country}', tag: 'EDIT_PLANT');
        _fetchFlag(_editedPlant.country!);
      }
    });
  }

  @override
  void dispose() {
    _latinNameController.dispose();
    _countryController.dispose();
    _habitatController.dispose();
    _descriptionController.dispose();
    _synonymsController.dispose();
    _careTipsController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCountryMapping() async {
    try {
      final String data =
          await rootBundle.loadString('assets/country_mapping.json');
      final dynamic jsonMap = jsonDecode(data);
      if (jsonMap is Map) {
        _countryMapping.clear();
        jsonMap.forEach((key, value) {
          if (key is String && value is String) {
            _countryMapping[key] = value;
          } else {
            AppLogger.warning('Некорректная пара в JSON: $key: $value', tag: 'EDIT_PLANT');
          }
        });
        AppLogger.api('Country mapping загружен: ${_countryMapping.length} стран', tag: 'EDIT_PLANT');
        AppLogger.api('Доступные страны: ${_countryMapping.keys.toList()}', tag: 'EDIT_PLANT');
      } else {
        throw Exception('JSON не является объектом Map');
      }
    } catch (e) {
      AppLogger.error('Ошибка загрузки country_mapping.json: $e', tag: 'EDIT_PLANT');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки списка стран: $e')),
        );
      }
    }
  }

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final speciesKeys = prefs.getKeys().where((k) => k.startsWith('species_'));
    for (var key in speciesKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        _speciesCache[key.replaceFirst('species_', '')] = value;
      }
    }
    final habitatKeys = prefs.getKeys().where((k) => k.startsWith('habitat_'));
    for (var key in habitatKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        _habitatCache[key.replaceFirst('habitat_', '')] = value;
      }
    }
    final descriptionKeys =
        prefs.getKeys().where((k) => k.startsWith('description_'));
    for (var key in descriptionKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        _descriptionCache[key.replaceFirst('description_', '')] = value;
      }
    }
    final countryKeys = prefs.getKeys().where((k) => k.startsWith('country_'));
    for (var key in countryKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        _countryCache[key.replaceFirst('country_', '')] = value;
      }
    }
    final synonymsKeys =
        prefs.getKeys().where((k) => k.startsWith('synonyms_'));
    for (var key in synonymsKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        _synonymsCache[key.replaceFirst('synonyms_', '')] = value;
      }
    }
    final careTipsKeys =
        prefs.getKeys().where((k) => k.startsWith('careTips_'));
    for (var key in careTipsKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        _careTipsCache[key.replaceFirst('careTips_', '')] = value;
      }
    }
  }

  void _fetchFlag(String countryName) async {
    if (countryName.isEmpty) return;

    AppLogger.api('Запрос флага для страны: "$countryName"', tag: 'EDIT_PLANT');
    setState(() => _isLoadingFlag = true);

    final englishName = _translateRussianToEnglish(countryName);
    AppLogger.api('Отправка запроса с английским названием: "$englishName"', tag: 'EDIT_PLANT');

    try {
      final response = await http.get(
        Uri.parse(
            'https://restcountries.com/v3.1/name/$englishName?fields=flags',),
        headers: {
          'User-Agent': 'MyCactusApp/1.0 (contact@example.com)',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final flagUrl = data[0]['flags']['png'];
        AppLogger.api('Флаг найден: $flagUrl', tag: 'EDIT_PLANT');
        setState(() {
          _flagUrl = flagUrl;
          _editedPlant = _editedPlant.copyWith(
            country: countryName,
            countryFlag: flagUrl,
          );
          _countryController.text = countryName;
        });
      } else {
        AppLogger.error('Ошибка API: ${response.statusCode}, тело: ${response.body}', tag: 'EDIT_PLANT');
        setState(() {
          _flagUrl = null;
          _editedPlant =
              _editedPlant.copyWith(country: countryName, countryFlag: null);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Флаг для "$countryName" не найден')),
        );
      }
    } catch (e) {
      AppLogger.error('Исключение при загрузке флага: $e', tag: 'EDIT_PLANT');
      if (mounted) {
        setState(() {
          _flagUrl = null;
          _editedPlant =
              _editedPlant.copyWith(country: countryName, countryFlag: null);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка загрузки флага для "$countryName": $e'),),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFlag = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SelectableText(
          _latinNameController.text, // Используем текст из контроллера
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (_flagUrl == null && _countryController.text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Флаг не найден! Проверьте название страны'),),
                );
                return;
              }
              // Обновляем растение с новым названием
              _editedPlant = _editedPlant.copyWith(
                latinName: _latinNameController.text.trim(),
              );
              context.read<PlantCrudProvider>()
                  .updatePlant(_editedPlant.permanentId, _editedPlant);
              Navigator.pop(
                  context, _editedPlant,); // Возвращаем обновленное растение
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Новое поле для редактирования latinName
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _latinNameController,
                  decoration: const InputDecoration(
                    labelText: 'Латинское название',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_florist, color: Colors.green),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите название';
                    }
                    final parts = value.trim().split(' ');
                    if (parts.length < 2) {
                      return 'Укажите род и вид (например, "Gymnocalycium bayrianum")';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _editedPlant =
                          _editedPlant.copyWith(latinName: value.trim());
                    });
                  },
                ),
              ),
            ),
            _buildCountryField(),
            _buildHabitatField(),
            _buildDescriptionField(),
            _buildSynonymsField(),
            _buildCareTipsField(),
            _buildFloweringField(),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _countryController,
                decoration: InputDecoration(
                  labelText: 'Страна',
                  prefixIcon: const Icon(Icons.flag, color: Colors.green),
                  suffixIcon: _isLoadingFlag || _isLoadingCountry
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : (_flagUrl != null && _flagUrl!.isNotEmpty)
                          ? Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: CachedNetworkImage(
                                imageUrl: _flagUrl!,
                                width: 40,
                                height: 30,
                                placeholder: (_, __) => const SizedBox(width: 40, height: 30),
                                errorWidget: (_, __, ___) => const SizedBox(width: 40, height: 30),
                              ),
                            )
                          : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onCountryChanged,
              ),
            ),
            AnimatedSearchIcon(
              isLoading: _isLoadingCountry,
              onPressed: () => _fetchCountryFromWeb(forceRefresh: false),
              tooltip: 'Найти страну на Llifle.com',
            ),
            AnimatedRefreshIcon(
              isLoading: _isLoadingCountry,
              onPressed: () => _fetchCountryFromWeb(forceRefresh: true),
              tooltip: 'Обновить данные о стране',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitatField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Естественный ареал',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                AnimatedSearchIcon(
                  isLoading: _isFetchingHabitat,
                  onPressed: () => _fetchHabitatFromWeb(forceRefresh: false),
                  tooltip: 'Загрузить ареал с Llifle.com',
                ),
                AnimatedRefreshIcon(
                  isLoading: _isFetchingHabitat,
                  onPressed: () => _fetchHabitatFromWeb(forceRefresh: true),
                  tooltip: 'Обновить данные об ареале',
                ),
                AnimatedTranslateIcon(
                  isLoading: _isTranslatingHabitat,
                  onPressed: _translateHabitat,
                  tooltip: 'Перевести на русский',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _habitatController,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit, size: 20),
              ),
              onChanged: (value) =>
                  _editedPlant = _editedPlant.copyWith(habitat: value),
            ),
            if (_isFetchingHabitat || _isTranslatingHabitat)
              const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Описание',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                AnimatedSearchIcon(
                  isLoading: _isFetchingDescription,
                  onPressed: () =>
                      _fetchDescriptionFromWeb(forceRefresh: false),
                  tooltip: 'Загрузить описание с Llifle.com',
                ),
                AnimatedRefreshIcon(
                  isLoading: _isFetchingDescription,
                  onPressed: () => _fetchDescriptionFromWeb(forceRefresh: true),
                  tooltip: 'Обновить описание',
                ),
                AnimatedTranslateIcon(
                  isLoading: _isTranslatingDescription,
                  onPressed: _translateDescription,
                  tooltip: 'Перевести на русский',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit, size: 20),
              ),
              onChanged: (value) =>
                  _editedPlant = _editedPlant.copyWith(description: value),
            ),
            if (_isFetchingDescription || _isTranslatingDescription)
              const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSynonymsField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Синонимы',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                AnimatedSearchIcon(
                  isLoading: _isFetchingSynonyms,
                  onPressed: () => _fetchSynonymsFromWeb(forceRefresh: false),
                  tooltip: 'Загрузить синонимы с Llifle.com',
                ),
                AnimatedRefreshIcon(
                  isLoading: _isFetchingSynonyms,
                  onPressed: () => _fetchSynonymsFromWeb(forceRefresh: true),
                  tooltip: 'Обновить данные о синонимах',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _synonymsController,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit, size: 20),
              ),
              onChanged: (value) =>
                  _editedPlant = _editedPlant.copyWith(synonyms: value),
            ),
            if (_isFetchingSynonyms) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildCareTipsField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Особенности ухода',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                AnimatedSearchIcon(
                  isLoading: _isFetchingCareTips,
                  onPressed: () => _fetchCareTipsFromWeb(forceRefresh: false),
                  tooltip: 'Загрузить особенности ухода с Llifle.com',
                ),
                AnimatedRefreshIcon(
                  isLoading: _isFetchingCareTips,
                  onPressed: () => _fetchCareTipsFromWeb(forceRefresh: true),
                  tooltip: 'Обновить данные об уходе',
                ),
                AnimatedTranslateIcon(
                  isLoading: _isTranslatingCareTips,
                  onPressed: _translateCareTips,
                  tooltip: 'Перевести на русский',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _careTipsController,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit, size: 20),
              ),
              onChanged: (value) =>
                  _editedPlant = _editedPlant.copyWith(careTips: value),
            ),
            if (_isFetchingCareTips || _isTranslatingCareTips)
              const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloweringField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          initialValue: _editedPlant.floweringPeriod,
          decoration: const InputDecoration(
            labelText: 'Период цветения',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today, color: Colors.green),
          ),
          onChanged: (value) =>
              _editedPlant = _editedPlant.copyWith(floweringPeriod: value),
        ),
      ),
    );
  }

  Future<void> _fetchDescriptionFromWeb({bool forceRefresh = false}) async {
    if (_editedPlant.latinName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите латинское название растения')),
        );
      }
      return;
    }

    final latinNameLower = _editedPlant.latinName.toLowerCase();
    if (!forceRefresh && _descriptionCache.containsKey(latinNameLower)) {
      setState(() {
        _editedPlant = _editedPlant.copyWith(
            description: _descriptionCache[latinNameLower],);
        _descriptionController.text = _descriptionCache[latinNameLower]!;
      });
      return;
    }

    setState(() => _isFetchingDescription = true);

    try {
      final plantData =
          await LlifleService().fetchPlantData(_editedPlant.latinName);
      if (plantData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не найдено: ${_editedPlant.latinName}'),
              action: SnackBarAction(
                label: 'Поиск',
                onPressed: () async {
                  final uri = Uri.parse(
                      'http://www.llifle.info/custom_search_engine?q=${_editedPlant.latinName}',);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ),
          );
        }
        return;
      }

      final description = plantData['description'] as String? ??
          ''; // Полный из parseLlifleData
      if (mounted && description.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('description_$latinNameLower', description);
        _descriptionCache[latinNameLower] = description;

        setState(() {
          _editedPlant = _editedPlant.copyWith(description: description);
          _descriptionController.text = description;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Описание не найдено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки описания: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: () => _fetchDescriptionFromWeb(forceRefresh: true),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingDescription = false);
      }
    }
  }

  Future<void> _fetchHabitatFromWeb({bool forceRefresh = false}) async {
    if (_editedPlant.latinName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите латинское название растения')),
        );
      }
      return;
    }

    final latinNameLower = _editedPlant.latinName.toLowerCase();
    if (!forceRefresh && _habitatCache.containsKey(latinNameLower)) {
      setState(() {
        _editedPlant =
            _editedPlant.copyWith(habitat: _habitatCache[latinNameLower]);
        _habitatController.text = _habitatCache[latinNameLower]!;
      });
      return;
    }

    setState(() => _isFetchingHabitat = true);

    try {
      final plantData =
          await LlifleService().fetchPlantData(_editedPlant.latinName);
      if (plantData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не найдено: ${_editedPlant.latinName}'),
              action: SnackBarAction(
                label: 'Поиск',
                onPressed: () async {
                  final uri = Uri.parse(
                      'http://www.llifle.info/custom_search_engine?q=${_editedPlant.latinName}',);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ),
          );
        }
        return;
      }

      final habitat = plantData['habitat'] ?? ''; // Полный из parseLlifleData
      if (mounted) {
        if (habitat.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Данные об ареале не найдены')),
          );
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('habitat_$latinNameLower', habitat);
          _habitatCache[latinNameLower] = habitat;

          setState(() {
            _editedPlant = _editedPlant.copyWith(habitat: habitat);
            _habitatController.text = habitat;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки ареала: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: () => _fetchHabitatFromWeb(forceRefresh: true),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingHabitat = false);
      }
    }
  }

  Future<void> _fetchCountryFromWeb({bool forceRefresh = false}) async {
    if (_editedPlant.latinName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите латинское название')),
        );
      }
      return;
    }

    final latinNameLower = _editedPlant.latinName.toLowerCase();
    if (!forceRefresh && _countryCache.containsKey(latinNameLower)) {
      final translatedCountry =
          _translateEnglishToRussian(_countryCache[latinNameLower]!);
      setState(() {
        _editedPlant = _editedPlant.copyWith(country: translatedCountry);
        _countryController.text = translatedCountry;
        _fetchFlag(translatedCountry);
      });
      return;
    }

    setState(() => _isLoadingCountry = true);

    try {
      final plantData =
          await LlifleService().fetchPlantData(_editedPlant.latinName);
      if (plantData == null) {
        if (mounted) {
          _showCountryNotFoundSnackBar();
        }
        return;
      }

      final country = plantData['country'] ?? ''; // Первая из parseLlifleData
      if (mounted) {
        if (country.isEmpty) {
          _showCountryNotFoundSnackBar();
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('country_$latinNameLower', country);
        _countryCache[latinNameLower] = country;

        final translatedCountry = _translateEnglishToRussian(country);
        setState(() {
          _editedPlant = _editedPlant.copyWith(country: translatedCountry);
          _countryController.text = translatedCountry;
          _fetchFlag(translatedCountry);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки страны: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: () => _fetchCountryFromWeb(forceRefresh: true),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCountry = false);
      }
    }
  }

  Future<void> _fetchSynonymsFromWeb({bool forceRefresh = false}) async {
    if (_editedPlant.latinName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите латинское название растения')),
        );
      }
      return;
    }

    final latinNameLower = _editedPlant.latinName.toLowerCase();
    if (!forceRefresh && _synonymsCache.containsKey(latinNameLower)) {
      setState(() {
        _editedPlant =
            _editedPlant.copyWith(synonyms: _synonymsCache[latinNameLower]);
        _synonymsController.text = _synonymsCache[latinNameLower]!;
      });
      return;
    }

    setState(() => _isFetchingSynonyms = true);

    try {
      final plantData =
          await LlifleService().fetchPlantData(_editedPlant.latinName);
      if (plantData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Растение не найдено: ${_editedPlant.latinName}'),
              action: SnackBarAction(
                label: 'Поиск',
                onPressed: () async {
                  final uri = Uri.parse(
                      'http://www.llifle.info/custom_search_engine?q=${_editedPlant.latinName}',);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ),
          );
        }
        return;
      }

      final synonyms = plantData['synonyms'] ?? ''; // Строка из parseLlifleData
      if (mounted) {
        if (synonyms.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Синонимы отсутствуют')),
          );
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('synonyms_$latinNameLower', synonyms);
          _synonymsCache[latinNameLower] = synonyms;

          setState(() {
            _editedPlant = _editedPlant.copyWith(synonyms: synonyms);
            _synonymsController.text = synonyms;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки синонимов: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: () => _fetchSynonymsFromWeb(forceRefresh: true),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingSynonyms = false);
      }
    }
  }

  Future<void> _fetchCareTipsFromWeb({bool forceRefresh = false}) async {
    if (_editedPlant.latinName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите латинское название растения')),
        );
      }
      return;
    }

    final latinNameLower = _editedPlant.latinName.toLowerCase();
    if (!forceRefresh && _careTipsCache.containsKey(latinNameLower)) {
      setState(() {
        _editedPlant =
            _editedPlant.copyWith(careTips: _careTipsCache[latinNameLower]);
        _careTipsController.text = _careTipsCache[latinNameLower]!;
      });
      return;
    }

    setState(() => _isFetchingCareTips = true);

    try {
      final plantData =
          await LlifleService().fetchPlantData(_editedPlant.latinName);
      if (plantData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Растение не найдено: ${_editedPlant.latinName}'),
              action: SnackBarAction(
                label: 'Поиск',
                onPressed: () async {
                  final uri = Uri.parse(
                      'http://www.llifle.info/custom_search_engine?q=${_editedPlant.latinName}',);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            ),
          );
        }
        return;
      }

      final careTips = plantData['careTips'] ?? ''; // Полный из parseLlifleData
      if (mounted) {
        if (careTips.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Особенности ухода отсутствуют')),
          );
        } else {
          final cleanedCareTips = careTips
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim(); // Очистка как раньше
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('careTips_$latinNameLower', cleanedCareTips);
          _careTipsCache[latinNameLower] = cleanedCareTips;

          setState(() {
            _editedPlant = _editedPlant.copyWith(careTips: cleanedCareTips);
            _careTipsController.text = cleanedCareTips;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Ошибка загрузки особенностей ухода: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: () => _fetchCareTipsFromWeb(forceRefresh: true),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingCareTips = false);
      }
    }
  }

  void _showCountryNotFoundSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Страна не найдена на llifle.info')),
    );
  }

  Future<void> _translateHabitat() async {
    if (_habitatController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текст для перевода отсутствует')),
        );
      }
      return;
    }

    setState(() => _isTranslatingHabitat = true);

    try {
      final translatedText = await translateText(_habitatController.text);
      if (mounted) {
        setState(() {
          _editedPlant = _editedPlant.copyWith(habitat: translatedText);
          _habitatController.text = translatedText;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка перевода: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTranslatingHabitat = false);
      }
    }
  }

  Future<void> _translateDescription() async {
    if (_descriptionController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текст для перевода отсутствует')),
        );
      }
      return;
    }

    setState(() => _isTranslatingDescription = true);

    try {
      final translatedText = await translateText(_descriptionController.text);
      if (mounted) {
        setState(() {
          _editedPlant = _editedPlant.copyWith(description: translatedText);
          _descriptionController.text = translatedText;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка перевода: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTranslatingDescription = false);
      }
    }
  }

  Future<void> _translateCareTips() async {
    if (_careTipsController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текст для перевода отсутствует')),
        );
      }
      return;
    }

    setState(() => _isTranslatingCareTips = true);

    try {
      final translatedText = await translateText(_careTipsController.text);
      if (mounted) {
        setState(() {
          _editedPlant = _editedPlant.copyWith(careTips: translatedText);
          _careTipsController.text = translatedText;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка перевода: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTranslatingCareTips = false);
      }
    }
  }

  String _translateRussianToEnglish(String russianCountryName) {
    final lowerCaseName = russianCountryName.trim().toLowerCase();
    for (var entry in _countryMapping.entries) {
      if (entry.key.toLowerCase() == lowerCaseName) {
        AppLogger.api('Перевод: "$russianCountryName" -> "${entry.value}"', tag: 'EDIT_PLANT');
        return entry.value;
      }
    }
    AppLogger.warning('Перевод не найден для: "$russianCountryName". Доступные страны: ${_countryMapping.keys.toList()}', tag: 'EDIT_PLANT');
    return russianCountryName;
  }

  String _translateEnglishToRussian(String englishCountryName) {
    final lowerCaseName = englishCountryName.trim().toLowerCase();
    return _englishToRussianMapping[lowerCaseName] ?? englishCountryName;
  }
}

class AnimatedRefreshIcon extends StatelessWidget {

  const AnimatedRefreshIcon({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.tooltip,
  });
  final bool isLoading;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).primaryColor,
              ),
            )
          : const Icon(Icons.refresh, color: Colors.orangeAccent),
      onPressed: isLoading ? null : onPressed,
      tooltip: tooltip,
    );
  }
}

class AnimatedSearchIcon extends StatelessWidget {

  const AnimatedSearchIcon({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.tooltip,
  });
  final bool isLoading;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).primaryColor,
              ),
            )
          : const Icon(Icons.search, color: Colors.orangeAccent),
      onPressed: isLoading ? null : onPressed,
      tooltip: tooltip,
    );
  }
}

class AnimatedTranslateIcon extends StatelessWidget {

  const AnimatedTranslateIcon({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.tooltip,
  });
  final bool isLoading;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).primaryColor,
              ),
            )
          : const Icon(Icons.translate, color: Colors.orangeAccent),
      onPressed: isLoading ? null : onPressed,
      tooltip: tooltip,
    );
  }
}
