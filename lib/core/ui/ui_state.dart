/// Универсальный sealed-класс состояний UI операции.
///
/// Используется во всех провайдерах для явного моделирования
/// loading / success / error состояний.
///
/// Пример:
/// ```dart
/// final state = context.watch<PlantCrudProvider>().uiState;
/// return switch (state) {
///   UiLoading() => const CircularProgressIndicator(),
///   UiSuccess(data: final plants) => PlantList(plants: plants),
///   UiError(message: final msg, onRetry: final retry) => ErrorWidget(msg, retry),
/// };
/// ```
sealed class UiState<T> {
  const UiState();
}

/// Данные загружаются / операция выполняется.
final class UiLoading<T> extends UiState<T> {
  const UiLoading();
}

/// Данные успешно загружены / операция завершена.
final class UiSuccess<T> extends UiState<T> {
  const UiSuccess(this.data);
  final T data;
}

/// Произошла ошибка. Содержит сообщение и callback для повтора.
final class UiError<T> extends UiState<T> {

  const UiError(this.message, {this.onRetry});
  final String message;
  final VoidCallback? onRetry;
}

/// Псевдоним для callback без параметров.
typedef VoidCallback = void Function();
