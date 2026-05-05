import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:centrifuge/centrifuge.dart' as centrifuge;
import '../data/game_api_client.dart';

// --- Mock Models for Context ---
class GameState {
  final String fen;
  final int moveNum;
  
  GameState({required this.fen, required this.moveNum});
  
  GameState applyLocalMove(String move) {
    // Optimistic UI logic: applies move locally and bumps local sequence number
    return GameState(fen: fen, moveNum: moveNum + 1); 
  }
}

class GameStateUpdate {
  final String type;
  final int moveNum;
  final GameState state;

  GameStateUpdate(this.type, this.moveNum, this.state);

  factory GameStateUpdate.fromJsonBytes(List<int> bytes) {
    final Map<String, dynamic> json = jsonDecode(utf8.decode(bytes));
    return GameStateUpdate(
      json['type'] as String,
      json['moveNum'] as int,
      GameState(fen: json['fen'] as String, moveNum: json['moveNum'] as int)
    );
  }
}

// --- Dependencies ---

final centrifugoClientProvider = Provider<centrifuge.Client>((ref) {
  // Use WS connection to Centrifugo gateway.
  // Ideally this URL comes from a config/env file.
  final client = centrifuge.createClient('ws://localhost:8000/connection/websocket');
  
  // Connect the client immediately
  client.connect();

  ref.onDispose(() {
    client.disconnect();
  });

  return client;
});


// --- StreamNotifier Implementation ---
class ChessGameNotifier extends FamilyStreamNotifier<GameState, String> {
  int _localMoveNum = 0;
  late String _gameId;
  centrifuge.Subscription? _subscription;

  GameApiClient get _api => ref.read(gameApiProvider);
  centrifuge.Client get _centrifugoClient => ref.read(centrifugoClientProvider);

  @override
  Stream<GameState> build(String arg) async* {
    _gameId = arg;
    
    // 1. Initial State Sync via REST API
    final initialState = await _api.getGameState(_gameId);
    _localMoveNum = initialState.moveNum;
    yield initialState;

    // 2. Centrifugo Subscription
    final channel = 'game:$_gameId';
    _subscription = _centrifugoClient.newSubscription(channel);
    
    _subscription!.publication.listen((event) {
      _handleRealtimeEvent(event);
    });

    await _subscription!.subscribe();

    // 3. Teardown
    ref.onDispose(() {
      _subscription?.unsubscribe();
      _centrifugoClient.removeSubscription(_subscription!);
    });
  }

  void _handleRealtimeEvent(centrifuge.PublicationEvent event) {
    try {
      final update = GameStateUpdate.fromJsonBytes(event.data);
      
      if (update.type == 'MOVE_ACCEPTED') {
        // Sequence Gap Detection (Strict Event-Driven Resilience)
        if (update.moveNum == _localMoveNum + 1) {
          // Normal sequential event
          _localMoveNum = update.moveNum;
          state = AsyncValue.data(update.state);
        } else if (update.moveNum > _localMoveNum + 1) {
          // Gap detected (packet loss/reconnect)! Discard event and full sync.
          _triggerFullSync();
        } else {
          // Received older/duplicate packet. Discard gracefully.
        }
      } else if (update.type == 'MOVE_REJECTED') {
        // Backend detected invalid move, revert to true state
        _triggerFullSync();
      }
    } catch (e) {
      // Ignore invalid payloads
    }
  }

  Future<void> _triggerFullSync() async {
    try {
      final authoritativeState = await _api.getGameState(_gameId);
      _localMoveNum = authoritativeState.moveNum;
      state = AsyncValue.data(authoritativeState);
    } catch (e) {
      // Retain previous state but optionally log error
    }
  }

  // Called by UI when user locally executes a turn
  Future<void> makeOptimisticMove(String moveStr) async {
    if (!state.hasValue) return;
    
    final previousState = state.requireValue;
    
    // 1. Optimistic UI update instantly renders the move for zero-latency feel
    final optimisticState = previousState.applyLocalMove(moveStr);
    state = AsyncValue.data(optimisticState);

    // 2. Fire backend REST request wrapped in guard
    final result = await AsyncValue.guard(() async {
      await _api.submitMove(_gameId, moveStr);
      // Wait for WS confirmation, keep optimistic state for now
      return optimisticState; 
    });

    // 3. Fallback on network/validation failure
    if (result.hasError) {
      // Conflicting reality or request failure -> rollback to authoritative server state
      state = AsyncValue.data(previousState);
    }
  }
}

// Global Provider
final chessGameProvider = StreamNotifierProvider.family<ChessGameNotifier, GameState, String>(() {
  return ChessGameNotifier();
});
