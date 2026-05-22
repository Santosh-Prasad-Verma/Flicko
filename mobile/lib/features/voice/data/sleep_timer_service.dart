import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sleep timer state
class SleepTimerState {
  final bool isActive;
  final DateTime? endTime;
  final Duration? remaining;
  final SleepTimerAction action;

  const SleepTimerState({
    this.isActive = false,
    this.endTime,
    this.remaining,
    this.action = SleepTimerAction.pause,
  });

  SleepTimerState copyWith({
    bool? isActive,
    DateTime? endTime,
    Duration? remaining,
    SleepTimerAction? action,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      endTime: endTime ?? this.endTime,
      remaining: remaining ?? this.remaining,
      action: action ?? this.action,
    );
  }
}

/// Action to perform when timer ends
enum SleepTimerAction {
  pause,
  stop,
  exitApp,
}

/// Service for sleep timer functionality
final sleepTimerProvider =
    NotifierProvider<SleepTimerNotifier, SleepTimerState>(SleepTimerNotifier.new);

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _timer;
  VoidCallback? _onTrigger;

  @override
  SleepTimerState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const SleepTimerState();
  }

  void setCallback(VoidCallback onTrigger) {
    _onTrigger = onTrigger;
  }

  void start(Duration duration, SleepTimerAction action) {
    _timer?.cancel();
    
    final endTime = DateTime.now().add(duration);
    
    state = SleepTimerState(
      isActive: true,
      endTime: endTime,
      remaining: duration,
      action: action,
    );

    // Update remaining time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = endTime.difference(DateTime.now());
      
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        _trigger();
      } else {
        state = state.copyWith(remaining: remaining);
      }
    });
  }

  void startAfterTrack(SleepTimerAction action) {
    // Will trigger after current track ends
    // The player needs to call triggerAfterTrack() when track ends
    state = SleepTimerState(
      isActive: true,
      action: action,
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = const SleepTimerState();
  }

  void extend(Duration additional) {
    if (!state.isActive || state.endTime == null) return;
    
    _timer?.cancel();
    
    final newEndTime = state.endTime!.add(additional);
    final newRemaining = newEndTime.difference(DateTime.now());
    
    state = state.copyWith(
      endTime: newEndTime,
      remaining: newRemaining,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = newEndTime.difference(DateTime.now());
      
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        _trigger();
      } else {
        state = state.copyWith(remaining: remaining);
      }
    });
  }

  void triggerAfterTrack() {
    if (state.isActive && state.endTime == null) {
      // This was an "after track" timer
      _trigger();
    }
  }

  void _trigger() {
    _timer?.cancel();
    _timer = null;
    
    final action = state.action;
    state = const SleepTimerState();
    
    _onTrigger?.call();
    
    dev.log('Sleep timer triggered: $action', name: 'sleep-timer');
  }
}
