import 'dart:io';

/// Проверка наличия интернет-соединения
class NetworkInfo {
  /// Проверить наличие интернет-соединения
  Future<bool> get isConnected async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}
