import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:mobile/core/config/app_config.dart';

/// Provider for PresenceService
final presenceServiceProvider = Provider<PresenceService>((ref) {
  return PresenceService();
});

/// Provider for online status of a specific user
final userOnlineStatusProvider = StreamProvider.family<String, String>((ref, userId) {
  final presenceService = ref.watch(presenceServiceProvider);
  return presenceService.getUserStatus(userId);
});

/// Provider for typing status in a channel
final typingStatusProvider = StreamProvider.family<List<String>, String>((ref, channelId) {
  final presenceService = ref.watch(presenceServiceProvider);
  return presenceService.getTypingUsers(channelId);
});

/// Presence Service
/// 
/// Handles real-time user presence via WebSocket:
/// - Online/offline status tracking
/// - Status updates (online, idle, dnd, invisible)
/// - Typing indicators
/// - Activity tracking
class PresenceService {
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _typingTimer;
  
  String? _currentUserId;
  String _currentStatus = 'online';
  String? _currentChannelId;
  
  bool _connected = false;
  
  // Streams
  final _statusController = StreamController<Map<String, String>>.broadcast();
  final _typingController = StreamController<Map<String, List<String>>>.broadcast();
  final _activityController = StreamController<Map<String, dynamic>>.broadcast();
  
  /// Stream of all user status updates
  Stream<Map<String, String>> get onStatusUpdate => _statusController.stream;
  
  /// Stream of typing updates
  Stream<Map<String, List<String>>> get onTypingUpdate => _typingController.stream;
  
  /// Stream of activity updates
  Stream<Map<String, dynamic>> get onActivityUpdate => _activityController.stream;

  /// Initialize presence service
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    await _connect();
  }

  /// Connect to WebSocket server
  Future<void> _connect() async {
    if (_connected || _currentUserId == null) return;

    try {
      // Get Supabase realtime token
      final supabase = Supabase.instance.client;
      final token = supabase.realtime.headers['apikey'] ?? AppConfig.supabaseAnonKey;
      
      // Connect to WebSocket
      final wsUrl = _buildWebSocketUrl(token);
      
      _channel = IOWebSocketChannel.connect(
        wsUrl,
        headers: {
          'apikey': token,
          'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}',
        },
      );

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('🔌 WebSocket closed');
          _scheduleReconnect();
        },
      );

      // Send join presence
      _joinPresence();
      
      // Start heartbeat
      _startHeartbeat();

      _connected = true;
      debugPrint('✅ PresenceService connected');
    } catch (e) {
      debugPrint('❌ Error connecting to WebSocket: $e');
      _scheduleReconnect();
    }
  }

  /// Build WebSocket URL
  String _buildWebSocketUrl(String token) {
    final url = AppConfig.supabaseUrl.replaceFirst('https://', 'wss://');
    return '$url/realtime/v1/websocket?apikey=$token&vsn=1.0.0';
  }

  /// Join presence channel
  void _joinPresence() {
    if (_currentUserId == null) return;

    final message = {
      'topic': 'phoenix',
      'event': 'heartbeat',
      'payload': {},
      'ref': DateTime.now().millisecondsSinceEpoch,
    };

    _sendMessage(message);
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final event = data['event'] as String?;
      final payload = data['payload'] as Map<String, dynamic>?;

      switch (event) {
        case 'presence_state':
          _handlePresenceState(payload ?? {});
          break;
        case 'presence_diff':
          _handlePresenceDiff(payload ?? {});
          break;
        case 'typing':
          _handleTypingUpdate(payload ?? {});
          break;
        case 'activity':
          _activityController.add(payload ?? {});
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling WebSocket message: $e');
    }
  }

  /// Handle presence state update
  void _handlePresenceState(Map<String, dynamic> payload) {
    final presenceMap = <String, String>{};
    
    payload.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final metas = value['metas'] as List<dynamic>?;
        if (metas != null && metas.isNotEmpty) {
          final meta = metas.first as Map<String, dynamic>;
          presenceMap[key] = meta['status'] as String? ?? 'offline';
        }
      }
    });

    _statusController.add(presenceMap);
  }

  /// Handle presence diff (joins/leaves)
  void _handlePresenceDiff(Map<String, dynamic> payload) {
    final joins = payload['joins'] as Map<String, dynamic>? ?? {};
    final leaves = payload['leaves'] as Map<String, dynamic>? ?? {};

    final diff = <String, String>{};

    joins.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final metas = value['metas'] as List<dynamic>?;
        if (metas != null && metas.isNotEmpty) {
          final meta = metas.first as Map<String, dynamic>;
          diff[key] = meta['status'] as String? ?? 'online';
        }
      }
    });

    leaves.forEach((key, _) {
      diff[key] = 'offline';
    });

    _statusController.add(diff);
  }

  /// Handle typing indicator update
  void _handleTypingUpdate(Map<String, dynamic> payload) {
    final channelId = payload['channel_id'] as String?;
    final users = payload['users'] as List<dynamic>? ?? [];

    if (channelId != null) {
      _typingController.add({
        channelId: users.cast<String>(),
      });
    }
  }

  /// Send message to WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('❌ Error sending WebSocket message: $e');
    }
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendMessage({
        'topic': 'phoenix',
        'event': 'heartbeat',
        'payload': {},
        'ref': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// Schedule reconnection
  void _scheduleReconnect() {
    _connected = false;
    Timer(const Duration(seconds: 5), _connect);
  }

  /// Update user status
  Future<void> updateStatus(String status) async {
    if (_currentUserId == null) return;

    _currentStatus = status;

    _sendMessage({
      'topic': 'presence',
      'event': 'update_status',
      'payload': {
        'user_id': _currentUserId,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });

    // Also update in Supabase
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('user_status').upsert({
        'user_id': _currentUserId,
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Error updating status in Supabase: $e');
    }
  }

  /// Set typing status for a channel
  Future<void> setTyping(String channelId, bool isTyping) async {
    if (_currentUserId == null) return;

    _currentChannelId = channelId;

    _sendMessage({
      'topic': 'channel:$channelId',
      'event': 'typing',
      'payload': {
        'user_id': _currentUserId,
        'channel_id': channelId,
        'is_typing': isTyping,
      },
    });

    // Clear typing after delay
    if (isTyping) {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 5), () {
        setTyping(channelId, false);
      });
    }
  }

  /// Get user status stream
  Stream<String> getUserStatus(String userId) {
    return _statusController.stream
        .map((statuses) => statuses[userId] ?? 'offline')
        .distinct();
  }

  /// Get typing users for a channel
  Stream<List<String>> getTypingUsers(String channelId) {
    return _typingController.stream
        .map((typing) => typing[channelId] ?? [])
        .distinct();
  }

  /// Get current user status
  String get currentStatus => _currentStatus;

  /// Check if connected
  bool get isConnected => _connected;

  /// Disconnect
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _typingTimer?.cancel();
    
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
    
    debugPrint('🔌 PresenceService disconnected');
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _statusController.close();
    _typingController.close();
    _activityController.close();
  }
}

/// User presence model
class UserPresence {
  final String userId;
  final String status;
  final DateTime lastSeen;
  final String? currentActivity;

  UserPresence({
    required this.userId,
    required this.status,
    required this.lastSeen,
    this.currentActivity,
  });

  factory UserPresence.fromMap(Map<String, dynamic> map) {
    return UserPresence(
      userId: map['user_id'] as String,
      status: map['status'] as String? ?? 'offline',
      lastSeen: DateTime.parse(map['last_seen'] as String? ?? DateTime.now().toIso8601String()),
      currentActivity: map['current_activity'] as String?,
    );
  }

  bool get isOnline => status == 'online';
  bool get isIdle => status == 'idle';
  bool get isDnd => status == 'dnd';
  bool get isInvisible => status == 'invisible';
}

/// Typing indicator model
class TypingIndicator {
  final String channelId;
  final List<String> userIds;
  final DateTime timestamp;

  TypingIndicator({
    required this.channelId,
    required this.userIds,
    required this.timestamp,
  });

  factory TypingIndicator.fromMap(Map<String, dynamic> map) {
    return TypingIndicator(
      channelId: map['channel_id'] as String,
      userIds: (map['user_ids'] as List<dynamic>?)?.cast<String>() ?? [],
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  bool get hasTypers => userIds.isNotEmpty;
}
