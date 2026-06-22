import '../proto/sync_frame.dart';

enum DriftActionType {
  none,
  adjustRate,
  hardSeek,
}

class DriftAction {
  final DriftActionType type;
  final double targetRate;
  final int targetPositionMs;
  final String reason;

  DriftAction({
    required this.type,
    this.targetRate = 1.0,
    this.targetPositionMs = 0,
    required this.reason,
  });

  @override
  String toString() => 'DriftAction(type: $type, targetRate: $targetRate, targetPositionMs: $targetPositionMs, reason: "$reason")';
}

class DriftEngine {
  // Config thresholds
  static const int hardSeekThresholdMs = 500;
  static const int rateAdjustThresholdMs = 150;
  static const int maxRateAdjustDurationMs = 4000;
  static const double rateAdjustDelta = 0.05; // 5% adjustment

  DateTime? _rateAdjustmentStartedAt;
  double _currentRateOverride = 1.0;

  double get currentRateOverride => _currentRateOverride;
  bool get isAdjustingRate => _rateAdjustmentStartedAt != null;

  DriftAction evaluate({
    required int localPositionMs,
    required SyncFrame anchor,
    required int localSystemTimeMs,
  }) {
    if (!anchor.playing) {
      // If host is paused, viewer should be paused and at the anchor position
      final drift = (localPositionMs - anchor.positionMs).abs();
      if (drift > hardSeekThresholdMs) {
        _resetRateAdjustment();
        return DriftAction(
          type: DriftActionType.hardSeek,
          targetPositionMs: anchor.positionMs,
          targetRate: 0.0,
          reason: 'Host is paused, high drift ($drift ms)',
        );
      }
      return DriftAction(
        type: DriftActionType.none,
        targetRate: 0.0,
        reason: 'Host is paused',
      );
    }

    // Host is playing
    // expected = anchor.position_ms + (now - anchor.wall_clock_ms) * anchor.rate
    final int elapsedSinceAnchor = localSystemTimeMs - anchor.wallClockMs;
    final int expectedPositionMs = anchor.positionMs + (elapsedSinceAnchor * anchor.rate).round();
    final int driftMs = localPositionMs - expectedPositionMs;
    final int absDriftMs = driftMs.abs();

    // 1. Check for hard seek threshold
    if (absDriftMs > hardSeekThresholdMs) {
      _resetRateAdjustment();
      return DriftAction(
        type: DriftActionType.hardSeek,
        targetPositionMs: expectedPositionMs,
        targetRate: anchor.rate,
        reason: 'High drift detected ($absDriftMs ms), hard seeking',
      );
    }

    // 2. Check if we are in active rate adjustment phase
    if (_rateAdjustmentStartedAt != null) {
      final int durationAdjusting = localSystemTimeMs - _rateAdjustmentStartedAt!.millisecondsSinceEpoch;

      if (absDriftMs < rateAdjustThresholdMs) {
        // Successfully converged! Revert rate to host rate
        _resetRateAdjustment();
        return DriftAction(
          type: DriftActionType.none,
          targetRate: anchor.rate,
          reason: 'Drift resolved ($absDriftMs ms), restoring normal rate',
        );
      }

      if (durationAdjusting >= maxRateAdjustDurationMs) {
        // Rate adjustment timed out and still drifting. Escalate to hard seek.
        _resetRateAdjustment();
        return DriftAction(
          type: DriftActionType.hardSeek,
          targetPositionMs: expectedPositionMs,
          targetRate: anchor.rate,
          reason: 'Rate adjustment timed out (4s), hard seeking',
        );
      }

      // Continue rate adjustment
      return DriftAction(
        type: DriftActionType.adjustRate,
        targetRate: _currentRateOverride,
        reason: 'Continuing rate adjustment ($absDriftMs ms drift)',
      );
    }

    // 3. Evaluate new rate adjustment window
    if (absDriftMs >= rateAdjustThresholdMs) {
      // Determine if viewer is ahead or behind host
      // If driftMs > 0, viewer is ahead (need to slow down: rate - 5%)
      // If driftMs < 0, viewer is behind (need to speed up: rate + 5%)
      final double adjustment = driftMs > 0 ? -rateAdjustDelta : rateAdjustDelta;
      _currentRateOverride = anchor.rate + adjustment;
      _rateAdjustmentStartedAt = DateTime.fromMillisecondsSinceEpoch(localSystemTimeMs);

      return DriftAction(
        type: DriftActionType.adjustRate,
        targetRate: _currentRateOverride,
        reason: 'Moderate drift ($absDriftMs ms), starting rate adjustment to $_currentRateOverride',
      );
    }

    // 4. In sync
    return DriftAction(
      type: DriftActionType.none,
      targetRate: anchor.rate,
      reason: 'In sync ($absDriftMs ms drift)',
    );
  }

  void _resetRateAdjustment() {
    _rateAdjustmentStartedAt = null;
    _currentRateOverride = 1.0;
  }

  void reset() {
    _resetRateAdjustment();
  }
}
