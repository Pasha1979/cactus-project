/// Конфигурация маршрутов навигации
class RouteConfig {
  // Основные маршруты
  static const String home = '/';
  static const String plants = '/plants';
  static const String plantDetail = '/plant/detail';
  static const String qrManagement = '/qr-management';
  static const String settings = '/settings';
  static const String about = '/about';
  
  // Параметры маршрутов
  static const String plantIdParam = 'plantId';
  static const String qrCodeParam = 'qrCode';
  
  // Время анимации переходов
  static const int transitionDuration = 300; // миллисекунды
  
  // Типы переходов
  static const bool useCupertinoTransitions = false;
}
