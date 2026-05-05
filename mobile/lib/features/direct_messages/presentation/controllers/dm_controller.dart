import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/direct_messages/data/dm_repository.dart';
import 'package:mobile/features/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/data/models/user_model.dart';
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

final dmControllerProvider = StateNotifierProvider<DMController, DMState>((ref) {
  final repository = ref.watch(dmRepositoryProvider);
  final authState = ref.watch(authNotifierProvider);
  
  final controller = DMController(repository, ref);
  
  // Initialize when user is authenticated
  authState.maybeWhen(
    authenticated: (user, profile) {
      controller.init(user.id);
    },
    orElse: () {},
  );
  
  return controller;
});

class DMController extends StateNotifier<DMState> {
  final DMRepository _repository;
  final Ref _ref;
  RealtimeChannel? _subscription;
  String? _currentUserId;

  DMController(this._repository, this._ref) : super(DMState());

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
          // Pinned, Muted, Unread would come from other tables/preferences in a full implementation
        );
      }
    }
    
    return conversationMap.values.toList();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
