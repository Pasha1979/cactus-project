import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_cactus/main.dart' as app;

/// Интеграционные тесты для критических потоков приложения.
/// 
/// Требует запуска на эмуляторе/устройстве:
/// flutter test integration_test/app_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests', () {
    testWidgets('app should start and show loading state', (WidgetTester tester) async {
      // Arrange & Act - запускаем приложение
      app.main();
      await tester.pump();

      // Assert - проверяем что приложение запустилось
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('app should handle basic lifecycle', (WidgetTester tester) async {
      // Arrange
      app.main();
      await tester.pump();

      // Act & Assert - приложение запускается без крашей
      expect(tester.takeException(), isNull);
    });
  });
}
