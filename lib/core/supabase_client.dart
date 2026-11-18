import 'package:supabase_flutter/supabase_flutter.dart';

/// Менеджер клиента Supabase (R-003, R-029).
///
/// Если ключи не переданы через env.json / --dart-define — приложение
/// работает в локальном режиме без облака.
class SupabaseClientManager {
  static bool _initialized = false;

  /// true, если Supabase инициализирован и [client] доступен.
  static bool get isInitialized => _initialized;

  /// Инициализация Supabase. При отсутствии ключей — пропуск (локальный режим).
  static Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty || anonKey.isEmpty) {
      return; // локальный режим без аккаунта (R-029)
    }

    await Supabase.initialize(url: url, publishableKey: anonKey);
    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase не инициализирован: задайте SUPABASE_URL и SUPABASE_ANON_KEY в env.json',
      );
    }
    return Supabase.instance.client;
  }
}
