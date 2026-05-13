import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

Future<String> translateText(String text,
    {String from = 'en', String to = 'ru',}) async {
  const int maxLength = 2000; // Ограничение для надежности
  debugPrint('Начало перевода текста: "$text" (длина: ${text.length})');
  debugPrint('Язык исходного текста: $from, язык перевода: $to');
  if (text.length <= maxLength) {
    return _translateSingle(text, from, to);
  } else {
    debugPrint('Текст слишком длинный, разбиваем на части...');
    List<String> parts = _splitText(text, maxLength);
    List<String> translatedParts = [];
    for (String part in parts) {
      debugPrint('Перевод части: "$part"');
      String translatedPart = await _translateSingle(part, from, to);
      translatedParts.add(translatedPart);
      await Future.delayed(const Duration(seconds: 3)); // Задержка 3 секунды
    }
    return translatedParts.join(' ');
  }
}

Future<String> _translateSingle(String text, String from, String to) async {
  const url = 'https://api-b2b.backenster.com/b1/api/v3/translate/';
  const token =
      'Bearer a_25rccaCYcBC9ARqMODx2BV2M0wNZgDCEl3jryYSgYZtF1a702PVi4sxqi2AmZWyCcw4x209VXnCYwesx';

  // Формируем тело запроса
  final requestBody = {
    'from': from,
    'to': to,
    'text': text,
    'platform': 'dp',
  };

  try {
    // Отправляем POST-запрос к API Lingvanex
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': token,
        'Referer': 'https://lingvanex.com/translate/',
        'Connection': 'keep-alive',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    debugPrint('Получен HTTP-ответ: статус ${response.statusCode}');
    if (response.statusCode != 200) {
      debugPrint('Ошибка загрузки: ${response.statusCode}');
      throw Exception('Не удалось выполнить перевод: ${response.statusCode}');
    }

    // Парсим JSON-ответ
    final data = jsonDecode(response.body);
    if (data['result'] == null) {
      debugPrint('Некорректный JSON-ответ: $data');
      throw Exception('Некорректный ответ от API');
    }

    // Извлекаем переведенный текст
    final translatedText = data['result'] as String;
    if (translatedText.isEmpty) {
      debugPrint('Переведенный текст пустой');
      throw Exception('Переведенный текст пустой');
    }

    debugPrint('Переведённый текст: "$translatedText"');
    return translatedText;
  } catch (e) {
    debugPrint('Ошибка перевода через Lingvanex: $e');
    // В случае ошибки возвращаем исходный текст
    debugPrint('Не удалось перевести текст, возвращаем исходный: "$text"');
    return text;
  }
}

List<String> _splitText(String text, int maxLength) {
  List<String> parts = [];
  while (text.isNotEmpty) {
    if (text.length <= maxLength) {
      parts.add(text);
      break;
    }
    int splitIndex = text.lastIndexOf('.', maxLength);
    if (splitIndex == -1 || splitIndex < maxLength / 2) {
      splitIndex = text.lastIndexOf(' ', maxLength);
    }
    if (splitIndex == -1 || splitIndex < maxLength / 2) {
      splitIndex = maxLength;
    }
    parts.add(text.substring(0, splitIndex).trim());
    text = text.substring(splitIndex).trim();
  }
  return parts;
}
