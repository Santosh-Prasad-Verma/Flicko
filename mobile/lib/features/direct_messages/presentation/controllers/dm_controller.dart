import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/direct_messages/data/dm_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'dart:developer' as dev;

class DMState {
  final List<DMConversation> conversations;
  final bool isLoading;
  final String? error;

  DMState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  DMState copyWith({
    List<DMConversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return DMState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final dmControllerProvider = NotifierProvider<DMController, DMState>(DMController.new);

class DMController extends Notifier<DMState> {
  late DMRepository _repository;
  RealtimeChannel? _subscription;
  String? _currentUserId;

  @override
  DMState build() {
    _repository = ref.watch(dmRepositoryProvider);
    final userId = ref.watch(currentUserIdProvider);

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    // Initialize when user is authenticated
    if (userId != null) {
      Future.microtask(() => init(userId));
    }

    return DMState();
  }

  Future<void> init(String userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;

    await fetchConversations();
    _setupSubscription(userId);
  }

  Future<void> fetchConversations() async {
    if (_currentUserId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await _repository.fetchRecentMessages(_currentUserId!);
      final conversations = _transformMessagesToConversations(messages, _currentUserId!);
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      dev.log('Error fetching DM conversations: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _setupSubscription(String userId) {
    _subscription?.unsubscribe();
    _subscription = _repository.subscribeToDMs(userId, () {
      fetchConversations();
    });
  }

  List<DMConversation> _transformMessagesToConversations(List<DMMessage> messages, String currentUserId) {
    final conversationMap = <String, DMConversation>{};

    for (final msg in messages) {
      final otherUserId = msg.senderId == currentUserId ? msg.recipientId : msg.senderId;
      final otherUser = msg.senderId == currentUserId ? msg.recipient : msg.sender;

      if (otherUser == null) continue;

      if (!conversationMap.containsKey(otherUserId)) {
        conversationMap[otherUserId] = DMConversation(
          id: otherUserId,
          participant: otherUser,
          lastMessage: msg.content,
          lastMessageAt: msg.createdAt,
        );
      }
    }

    return conversationMap.values.toList();
  }
}
