import 'package:flutter/material.dart';
import 'failures.dart';

/// Виджет для отображения ошибок в UI
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final void Function(Failure)? onError;
  final Widget Function(Failure)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Failure? _failure;

  void _reset() {
    setState(() {
      _failure = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failure != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_failure!);
      }

      return DefaultErrorWidget(
        failure: _failure!,
        onRetry: _reset,
      );
    }

    return widget.child;
  }
}

/// Виджет по умолчанию для отображения ошибок
class DefaultErrorWidget extends StatelessWidget {
  final Failure failure;
  final VoidCallback? onRetry;

  const DefaultErrorWidget({
    super.key,
    required this.failure,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Произошла ошибка',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                failure.message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (failure.code != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Код ошибки: ${failure.code}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              if (onRetry != null)
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Повторить'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
