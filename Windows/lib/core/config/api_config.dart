/// API константы
class ApiConstants {
  // Базовый URL Яндекс Диска
  static const String yandexDiskBaseUrl = 'https://cloud-api.yandex.net/v1/disk/resources';
  
  // Базовый URL GBIF API
  static const String gbifBaseUrl = 'https://api.gbif.org/v1';
  
  // OAuth2 константы
  static const String oauth2AuthorizeUrl = 'https://oauth.yandex.com/authorize';
  static const String oauth2TokenUrl = 'https://oauth.yandex.com/token';
  static const String yandexAuthEndpoint = 'https://oauth.yandex.com/authorize';
  
  // Yandex OAuth Credentials
  static const String yandexClientId = '066c5dd1fda94c15ac2dc248cdb0f1e8';
  static const String yandexClientSecret = 'c624749917a34e6a8579e5ff2685f0f7';
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
}
