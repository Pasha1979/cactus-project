import 'package:flutter/material.dart';
import 'ui_state.dart';

/// Виджет для декларативного отображения [UiState].
///
/// Пример:
/// ```dart
/// UiStateBuilder<List<Plant>>(
///   state: context.watch<PlantCrudProvider>().plantsState,
///   onLoading: () => const Center(child: CircularProgressIndicator()),
///   onSuccess: (plants) => PlantList(plants: plants),
///   onError: (message, retry) => ErrorCard(message: message, onRetry: retry),
/// )
/// ```
class UiStateBuilder<T> extends StatelessWidget {

  const UiStateBuilder({
    super.key,
    required this.state,
    required this.onLoading,
    required this.onSuccess,
    required this.onError,
  });
  final UiState<T> state;
  final Widget Function() onLoading;
  final Widget Function(T data) onSuccess;
  final Widget Function(String message, VoidCallback? retry) onError;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      UiLoading() => onLoading(),
      UiSuccess(data: final data) => onSuccess(data),
      UiError(message: final msg, onRetry: final retry) => onError(msg, retry),
    };
  }
}

/// Готовая карточка ошибки с кнопкой «Повторить».
class ErrorCard extends StatelessWidget {

  const ErrorCard({
    super.key,
    required this.message,
    this.onRetry,
  });
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
