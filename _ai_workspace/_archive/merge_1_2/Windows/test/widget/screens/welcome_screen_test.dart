import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:my_cactus/presentation/providers/cloud_storage_provider.dart';
import 'package:my_cactus/presentation/providers/providers.dart';
import 'package:my_cactus/screens/welcome_screen.dart';

import 'welcome_screen_test.mocks.dart';

@GenerateMocks([WeatherProvider, CloudStorageProvider])
void main() {
  group('WelcomeScreen Widget Tests', () {
    late MockWeatherProvider mockWeatherProvider;
    late MockCloudStorageProvider mockCloudStorageProvider;

    setUp(() {
      mockWeatherProvider = MockWeatherProvider();
      mockCloudStorageProvider = MockCloudStorageProvider();

      when(mockWeatherProvider.initLocation()).thenAnswer((_) async {});
      when(mockCloudStorageProvider.isConnected).thenReturn(false);
    });

    Widget buildTestableWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<WeatherProvider>.value(
            value: mockWeatherProvider,
          ),
          ChangeNotifierProvider<CloudStorageProvider>.value(
            value: mockCloudStorageProvider,
          ),
        ],
        child: const MaterialApp(
          home: WelcomeScreen(),
        ),
      );
    }

    testWidgets('should render WelcomeScreen with title', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Assert
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('should have skip button', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Assert - ищем кнопки
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('should have checkbox for remember me', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Assert - ищем checkbox
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('should call initLocation on build', (WidgetTester tester) async {
      // Arrange & Act
      await tester.pumpWidget(buildTestableWidget());
      await tester.pump();

      // Assert
      verify(mockWeatherProvider.initLocation()).called(1);
    });
  });
}
