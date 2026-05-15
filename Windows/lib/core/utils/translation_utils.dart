import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logger/app_logger.dart';
import '../config/api_config.dart';

Future<String> translateText(String text,
    {String from = 'en', String to = 'ru',}) async {
  const int maxLength = 2000; // Ограничение для надежности
  AppLogger.api('Начало перевода текста: "$text" (длина: ${text.length})', tag: 'TRANSLATION');
  AppLogger.api('Язык исходного текста: $from, язык перевода: $to', tag: 'TRANSLATION');
  if (text.length <= maxLength) {
    return _translateSingle(text, from, to);
  } else {
    AppLogger.api('Текст слишком длинный, разбиваем на части...', tag: 'TRANSLATION');
    List<String> parts = _splitText(text, maxLength);
    List<String> translatedParts = [];
    for (String part in parts) {
      AppLogger.api('Перевод части: "$part"', tag: 'TRANSLATION');
      String translatedPart = await _translateSingle(part, from, to);
      translatedParts.add(translatedPart);
      await Future.delayed(const Duration(seconds: 3)); // Задержка 3 секунды
    }
    return translatedParts.join(' ');
  }
}

Future<String> _translateSingle(String text, String from, String to) async {
  const url = ApiConstants.translationApiUrl;
  const token = ApiConstants.translationApiToken;

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
        'Referer': ApiConstants.translationApiReferer,
        'Connection': 'keep-alive',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 10));

    AppLogger.api('Получен HTTP-ответ: статус ${response.statusCode}', tag: 'TRANSLATION');
    if (response.statusCode != 200) {
      AppLogger.error('Ошибка загрузки: ${response.statusCode}', tag: 'TRANSLATION');
      throw Exception('Не удалось выполнить перевод: ${response.statusCode}');
    }

    // Парсим JSON-ответ
    final data = jsonDecode(response.body);
    if (data['result'] == null) {
      AppLogger.error('Некорректный JSON-ответ: $data', tag: 'TRANSLATION');
      throw Exception('Некорректный ответ от API');
    }

    // Извлекаем переведенный текст
    final translatedText = data['result'] as String;
    if (translatedText.isEmpty) {
      AppLogger.warning('Переведенный текст пустой', tag: 'TRANSLATION');
      throw Exception('Переведенный текст пустой');
    }

    AppLogger.api('Переведённый текст: "$translatedText"', tag: 'TRANSLATION');
    return translatedText;
  } catch (e) {
    AppLogger.error('Ошибка перевода через Lingvanex: $e', tag: 'TRANSLATION');
    // В случае ошибки возвращаем исходный текст
    AppLogger.warning('Не удалось перевести текст, возвращаем исходный: "$text"', tag: 'TRANSLATION');
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
