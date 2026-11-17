/// API константы
class ApiConstants {
  // Базовый URL Яндекс Диска
  static const String yandexDiskBaseUrl = 'https://cloud-api.yandex.net/v1/disk/resources';
  
  // Базовый URL GBIF API
  static const String gbifBaseUrl = 'https://api.gbif.org/v1';
  static const String gbifOccurrenceSearchUrl = 'https://api.gbif.org/v1/occurrence/search';
  
  // OAuth2 константы
  static const String oauth2AuthorizeUrl = 'https://oauth.yandex.com/authorize';
  static const String oauth2TokenUrl = 'https://oauth.yandex.com/token';
  static const String yandexAuthEndpoint = 'https://oauth.yandex.com/authorize';
  
  // Yandex OAuth Credentials
  static const String yandexClientId = String.fromEnvironment('YANDEX_CLIENT_ID');
  static const String yandexClientSecret = String.fromEnvironment('YANDEX_CLIENT_SECRET');
  static const String yandexRedirectUri = 'mycactus://callback';
  static const String yandexTokenEndpoint = 'https://oauth.yandex.com/token';
  
  // Заголовки
  static const String authorizationHeader = 'Authorization';
  static const String contentTypeHeader = 'Content-Type';
  static const String acceptHeader = 'Accept';
  
  // Типы контента
  static const String jsonContentType = 'application/json';
  static const String multipartFormDataContentType = 'multipart/form-data';
  
  // Параметры API
  static const String limitParam = 'limit';
  static const String offsetParam = 'offset';
  static const String fieldsParam = 'fields';
  static const String expandParam = 'expand';
  
  // Значения по умолчанию
  static const int defaultLimit = 100;
  static const int defaultOffset = 0;
  
  // Таймауты (в секундах)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;

  // OpenWeather API Key
  static const String openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY');
  static const String openWeatherBaseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // Translation API (Lingvanex/Backenster)
  static const String translationApiUrl = 'https://api-b2b.backenster.com/b1/api/v3/translate/';
  static const String translationApiToken = String.fromEnvironment('TRANSLATION_API_TOKEN');
  static const String translationApiReferer = String.fromEnvironment('TRANSLATION_API_REFERER', defaultValue: 'https://lingvanex.com/translate/');

  // Llifle API
  static const String llifleBaseUrl = 'https://llifle.com';
  static const String llifleReferer = 'https://llifle.com/';
  static const String llifleSearchUrl = 'https://llifle.com/Encyclopedia/CACTI/Species/all/1/100/?filter=';
  static const String llifleSpeciesUrl = 'https://llifle.com/Encyclopedia/CACTI/Family/Cactaceae/';
  static const String lliflePhotosUrl = 'https://llifle.com/photos/';

  // App URLs
  static const String privacyPolicyUrl = 'https://github.com/PaveUA/my-cactus/blob/main/PRIVACY.md';
  static const String supportEmail = 'mycactus.support@gmail.com';

  // OpenStreetMap
  static const String openStreetMapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String openStreetMapUrl = 'https://www.openstreetmap.org/?mlat={lat}&mlon={lon}#map=15/{lat}/{lon}';
  /// true, если ключ передан через env.json / --dart-define и непуст
  static bool isKeyConfigured(String key) => key.isNotEmpty;

  /// Сообщение при отсутствии ключа: запуск без env.json
  static String keyNotConfiguredMessage(String keyName) =>
      'Ключ $keyName не настроен (env.json)';
}
