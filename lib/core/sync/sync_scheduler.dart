import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/feature_flags.dart';
import '../logger/app_logger.dart';
import 'sync_engine.dart';
import 'sync_outbox.dart';

/// Авто-синхронизация (задача 2.5).
///
/// Три триггера:
/// - debounce: [SyncOutbox.enqueue] → таймер (повторные enqueue сбрасывают его);
/// - resume: приложение вернулось на передний план → sync;
/// - periodic: таймер с интервалом.
///
/// Включается флагом [FeatureFlag.enableAutoCloudSync] (локально через
/// FeatureFlags.setLocalOverride — UI добавится позже).
/// Без аккаунта движок делает no-op (R-008).
class SyncScheduler with WidgetsBindingObserver {
  SyncScheduler({
    required SyncEngine engine,
    required SyncOutbox outbox,
    this.debounce = const Duration(seconds: 5),
    this.periodic = const Duration(seconds: 60),
    bool Function()? enabledCheck,
  })  : _engine = engine,
        _outbox = outbox,
        _enabledCheck = enabledCheck ??
            (() => FeatureFlags.isEnabled(FeatureFlag.enableAutoCloudSync));

  final SyncEngine _engine;
  final SyncOutbox _outbox;
  final Duration debounce;
  final Duration periodic;
  final bool Function() _enabledCheck;

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _started = false;

  bool get _enabled => _enabledCheck();

  /// Подключить триггеры. Безопасен при повторном вызове.
  void start() {
    if (_started) return;
    _started = true;
    _outbox.onEnqueue = _onEnqueue;
    WidgetsBinding.instance.addObserver(this);
    _restartPeriodic();
  }

  void _restartPeriodic() {
    _periodicTimer?.cancel();
    if (_enabled) {
      _periodicTimer = Timer.periodic(periodic, (_) => _trigger('periodic'));
    }
  }

  /// Отключить триггеры (dispose).
  void stop() {
    _started = false;
    _outbox.onEnqueue = null;
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _onEnqueue() {
    if (!_enabled) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => _trigger('debounce'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartPeriodic();
      _trigger('resume');
    }
  }

  Future<void> _trigger(String source) async {
    if (!_enabled) return;
    try {
      await _engine.sync();
    } catch (e, st) {
      AppLogger.error(
        'Auto-sync ($source) не удался',
        tag: 'SYNC',
        error: e,
        stackTrace: st,
      );
    }
  }
}
