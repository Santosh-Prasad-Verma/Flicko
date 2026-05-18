/// E2EE telemetry & metrics (Tasks 35-36, 45).
///
/// Privacy-respecting operational metrics — NEVER logs plaintext,
/// private keys, or message content. Only timing and error counts.
/// References: design.md §10, requirements.md R15
library;

import 'dart:async';

/// Metric event types for E2EE operations.
enum E2EEMetricType {
  encrypt,
  decrypt,
  x3dhInit,
  x3dhRespond,
  dhRatchetStep,
  walWrite,
  walRecover,
  prekeyRefill,
  sealedSenderSeal,
  sealedSenderUnseal,
  backupCreate,
  backupRestore,
  identityRotation,
  verificationComplete,
  error,
}

/// A single metric event with timing and metadata.
class E2EEMetricEvent {
  final E2EEMetricType type;
  final Duration duration;
  final bool success;
  final String? errorCode;
  final DateTime timestamp;

  const E2EEMetricEvent({
    required this.type,
    required this.duration,
    required this.success,
    this.errorCode,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'duration_ms': duration.inMilliseconds,
    'success': success,
    if (errorCode != null) 'error_code': errorCode,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Performance targets from requirements.md.
class E2EEPerformanceTargets {
  static const Duration encryptMax = Duration(milliseconds: 5);
  static const Duration decryptMax = Duration(milliseconds: 5);
  static const Duration x3dhMax = Duration(milliseconds: 60);
  static const Duration dhRatchetMax = Duration(milliseconds: 8);
  static const Duration walWriteMax = Duration(milliseconds: 10);

  /// Check if a metric meets its performance target.
  static bool meetsTarget(E2EEMetricType type, Duration duration) {
    switch (type) {
      case E2EEMetricType.encrypt:
      case E2EEMetricType.decrypt:
        return duration <= encryptMax;
      case E2EEMetricType.x3dhInit:
      case E2EEMetricType.x3dhRespond:
        return duration <= x3dhMax;
      case E2EEMetricType.dhRatchetStep:
        return duration <= dhRatchetMax;
      case E2EEMetricType.walWrite:
        return duration <= walWriteMax;
      default:
        return true; // No target defined
    }
  }
}

/// E2EE metrics collector.
///
/// Collects timing data and error counts for operational monitoring.
/// Telemetry is gated by feature flag E2EE_V2_TELEMETRY (Task 45).
class E2EEMetrics {
  final List<E2EEMetricEvent> _events = [];
  final StreamController<E2EEMetricEvent> _stream = StreamController.broadcast();
  bool _enabled = false;

  /// Enable or disable metrics collection (feature-flag gated).
  void setEnabled(bool enabled) => _enabled = enabled;
  bool get isEnabled => _enabled;

  /// Stream of metric events for real-time monitoring.
  Stream<E2EEMetricEvent> get events => _stream.stream;

  /// Record a timed operation.
  Future<T> measure<T>(E2EEMetricType type, Future<T> Function() operation) async {
    if (!_enabled) return operation();
    final sw = Stopwatch()..start();
    try {
      final result = await operation();
      sw.stop();
      _record(E2EEMetricEvent(
        type: type, duration: sw.elapsed, success: true, timestamp: DateTime.now().toUtc(),
      ));
      return result;
    } catch (e) {
      sw.stop();
      _record(E2EEMetricEvent(
        type: type, duration: sw.elapsed, success: false,
        errorCode: e.runtimeType.toString(), timestamp: DateTime.now().toUtc(),
      ));
      rethrow;
    }
  }

  void _record(E2EEMetricEvent event) {
    _events.add(event);
    _stream.add(event);
    // Keep bounded to prevent memory leaks.
    if (_events.length > 1000) _events.removeRange(0, 500);
  }

  /// Get aggregate stats for a metric type.
  E2EEMetricSummary summarize(E2EEMetricType type) {
    final matching = _events.where((e) => e.type == type).toList();
    if (matching.isEmpty) return E2EEMetricSummary.empty(type);
    final durations = matching.map((e) => e.duration.inMicroseconds).toList()..sort();
    final successes = matching.where((e) => e.success).length;
    return E2EEMetricSummary(
      type: type,
      count: matching.length,
      successCount: successes,
      p50: Duration(microseconds: durations[durations.length ~/ 2]),
      p99: Duration(microseconds: durations[(durations.length * 0.99).floor()]),
      max: Duration(microseconds: durations.last),
    );
  }

  void dispose() => _stream.close();
}

class E2EEMetricSummary {
  final E2EEMetricType type;
  final int count;
  final int successCount;
  final Duration p50;
  final Duration p99;
  final Duration max;

  const E2EEMetricSummary({required this.type, required this.count, required this.successCount, required this.p50, required this.p99, required this.max});

  factory E2EEMetricSummary.empty(E2EEMetricType type) => E2EEMetricSummary(type: type, count: 0, successCount: 0, p50: Duration.zero, p99: Duration.zero, max: Duration.zero);

  double get successRate => count == 0 ? 1.0 : successCount / count;
}
