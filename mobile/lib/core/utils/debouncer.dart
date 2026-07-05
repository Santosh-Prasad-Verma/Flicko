import 'dart:async';
import 'package:flutter/foundation.dart';

/// Lightweight debouncer for search queries, API calls, and UI input throttling.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Runs [action] after [delay] milliseconds.
  /// If called again before [delay] expires, cancels previous timer.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending debounced action.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Lightweight throttler for high-frequency events (e.g. typing indicators, scroll listeners).
class Throttler {
  final Duration interval;
  DateTime? _lastRun;

  Throttler({this.interval = const Duration(seconds: 2)});

  /// Executes [action] only if at least [interval] has passed since last execution.
  void run(VoidCallback action) {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      action();
    }
  }

  void reset() {
    _lastRun = null;
  }
}
