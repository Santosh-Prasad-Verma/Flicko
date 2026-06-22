import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/activities/watch_together/proto/sync_frame.dart';
import 'package:mobile/features/activities/watch_together/sync/drift_engine.dart';

void main() {
  group('DriftEngine Tests', () {
    late DriftEngine engine;
    late int initialWallClock;

    setUp(() {
      engine = DriftEngine();
      initialWallClock = DateTime.now().millisecondsSinceEpoch;
    });

    test('should remain in sync when drift is below 150ms', () {
      final anchor = SyncFrame(
        version: 1,
        type: 'anchor',
        sessionId: 'session_1',
        hostId: 'host_1',
        positionMs: 10000,
        playing: true,
        rate: 1.0,
        wallClockMs: initialWallClock,
        seq: 1,
      );

      // 50ms drift ahead
      final action = engine.evaluate(
        localPositionMs: 10050,
        anchor: anchor,
        localSystemTimeMs: initialWallClock,
      );

      expect(action.type, DriftActionType.none);
      expect(action.targetRate, 1.0);
    });

    test('should trigger moderate drift rate adjustment (slowing down)', () {
      final anchor = SyncFrame(
        version: 1,
        type: 'anchor',
        sessionId: 'session_1',
        hostId: 'host_1',
        positionMs: 10000,
        playing: true,
        rate: 1.0,
        wallClockMs: initialWallClock,
        seq: 1,
      );

      // 200ms drift ahead -> should slow down to 0.95
      final action = engine.evaluate(
        localPositionMs: 10200,
        anchor: anchor,
        localSystemTimeMs: initialWallClock,
      );

      expect(action.type, DriftActionType.adjustRate);
      expect(action.targetRate, 0.95);
      expect(engine.isAdjustingRate, isTrue);
    });

    test('should trigger moderate drift rate adjustment (speeding up)', () {
      final anchor = SyncFrame(
        version: 1,
        type: 'anchor',
        sessionId: 'session_1',
        hostId: 'host_1',
        positionMs: 10000,
        playing: true,
        rate: 1.0,
        wallClockMs: initialWallClock,
        seq: 1,
      );

      // 200ms drift behind -> should speed up to 1.05
      final action = engine.evaluate(
        localPositionMs: 9800,
        anchor: anchor,
        localSystemTimeMs: initialWallClock,
      );

      expect(action.type, DriftActionType.adjustRate);
      expect(action.targetRate, 1.05);
      expect(engine.isAdjustingRate, isTrue);
    });

    test('should restore rate once drift is resolved', () {
      final anchor = SyncFrame(
        version: 1,
        type: 'anchor',
        sessionId: 'session_1',
        hostId: 'host_1',
        positionMs: 10000,
        playing: true,
        rate: 1.0,
        wallClockMs: initialWallClock,
        seq: 1,
      );

      // Step 1: Start adjusting rate (200ms ahead)
      engine.evaluate(
        localPositionMs: 10200,
        anchor: anchor,
        localSystemTimeMs: initialWallClock,
      );

      // Step 2: Now drift is 100ms -> should resolve and restore 1.0 rate
      final action = engine.evaluate(
        localPositionMs: 10100,
        anchor: anchor,
        localSystemTimeMs: initialWallClock,
      );

      expect(action.type, DriftActionType.none);
      expect(action.targetRate, 1.0);
      expect(engine.isAdjustingRate, isFalse);
    });

    test('should escalate to hard seek when rate adjustment times out (4s)', () {
      final anchor = SyncFrame(
        version: 1,
        type: 'anchor',
        sessionId: 'session_1',
        hostId: 'host_1',
        positionMs: 10000,
        playing: true,
        rate: 1.0,
        wallClockMs: initialWallClock,
        seq: 1,
      );

      // Start rate adjustment at t=0
      engine.evaluate(
        localPositionMs: 10200,
        anchor: anchor,
        localSystemTimeMs: initialWallClock,
      );

      // 4000ms later, still drifting ahead by 300ms -> escalate to hard seek
      final action = engine.evaluate(
        localPositionMs: 14300,
        anchor: anchor,
        localSystemTimeMs: initialWallClock + 4000,
      );

      expect(action.type, DriftActionType.hardSeek);
      expect(action.targetPositionMs, 14000); // 10000 + 4000
      expect(engine.isAdjustingRate, isFalse);
    });

    test('should trigger hard seek immediately if drift exceeds 500ms', () {
      final anchor = SyncFrame(
        version: 1,
        type: 'anchor',
        sessionId: 'session_1',
        hostId: 'host_1',
        positionMs: 10000,
        playing: true,
        rate: 1.0,
        wallClockMs: initialWallClock,
        seq: 1,
      );

      // 600ms drift ahead -> hard seek immediately
      final action = engine.evaluate(
        localPositionMs: 10600,
        anchor: anchor,
        localSystemTimeMs: initialWallClock,
      );

      expect(action.type, DriftActionType.hardSeek);
      expect(action.targetPositionMs, 10000);
      expect(engine.isAdjustingRate, isFalse);
    });
  });
}
