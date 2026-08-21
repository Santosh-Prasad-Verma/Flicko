import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/enhanced_message_item.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/message_actions.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/enhanced_message_input.dart';
import 'package:mobile/data/models/flicko_message.dart';

class ThreadViewScreen extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;
  final String threadId;

  const ThreadViewScreen({
    super.key,
    required this.serverId,
    required this.channelId,
    required this.threadId,
  });

  @override
  ConsumerState<ThreadViewScreen> createState() => _ThreadViewScreenState();
}

class _ThreadViewScreenState extends ConsumerState<ThreadViewScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _thread;
  List<FlickoMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  FlickoMessage? _replyTo;
  String? _editingMessageId;
  int _currentPage = 1;
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadThread(),
      _loadMessages(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadThread() async {
    try {
      final response = await Supabase.instance.client
          .from('threads')
          .select('*')
          .eq('id', widget.threadId)
          .single();
      setState(() => _thread = response);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadMessages({bool reset = true}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _messages = [];
      });
    }

    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('*, author:profiles(id, username, display_name, avatar)')
          .eq('thread_id', widget.threadId)
          .order('created_at', ascending: true)
          .range((_currentPage - 1) * 50, _currentPage * 50 - 1);

      final newMessages = (response as List)
          .map((m) => FlickoMessage.fromJson(m as Map<String, dynamic>))
          .toList();

      setState(() {
        if (reset) {
          _messages = newMessages;
        } else {
          _messages.addAll(newMessages);
        }
        _hasNextPage = newMessages.length == 50;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreMessages() {
    if (_hasNextPage && !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
      return _loadMessages(reset: false);
    }
    return Future.value();
  }

  Future<void> _sendMessage(String content) async {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    if (user == null) return;

    try {
      await Supabase.instance.client.from('messages').insert({
        'channel_id': widget.channelId,
        'thread_id': widget.threadId,
        'author_id': user.id,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _loadMessages(reset: true);
      await _loadThread();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('id', messageId);
      await _loadMessages(reset: true);
      await _loadThread();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _editMessage(String messageId, String newContent) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({
            'content': newContent,
            'edited': true,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
      await _loadMessages(reset: true);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    if (user == null) return;

    try {
      final existing = await Supabase.instance.client
          .from('reactions')
          .select('id')
          .eq('message_id', messageId)
          .eq('user_id', user.id)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existing != null) {
        await Supabase.instance.client
            .from('reactions')
            .delete()
            .eq('id', existing['id']);
      } else {
        await Supabase.instance.client.from('reactions').insert({
          'message_id': messageId,
          'user_id': user.id,
          'emoji': emoji,
        });
      }

      await _loadMessages(reset: true);
    } catch (e) {
      // Handle error
    }
  }

  void _onMessageLongPress(FlickoMessage message) {
    final currentUserId = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user.id,
      orElse: () => '',
    );

    context.showMessageActions(
      message: message,
      currentUserId: currentUserId,
      onReaction: (emoji) => _toggleReaction(message.id, emoji),
      onReply: () => setState(() => _replyTo = message),
      onEdit: () => setState(() => _editingMessageId = message.id),
      onPin: () async {
        try {
          await Supabase.instance.client.rpc('pin_message', params: {
            'message_uuid': message.id,
            'pin_status': !message.pinned,
          });
          await _loadMessages(reset: true);
        } catch (e) {
          // Handle error
        }
      },
      onDelete: () => _deleteMessage(message.id),
      onCopy: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied to clipboard', style: GoogleFonts.inter()),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgTertiary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thread',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              _thread?['name'] ?? 'Thread',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    color: Color(FlickoColors.textMuted), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${_thread?['message_count'] ?? 0}',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(FlickoColors.blurple),
                    ),
                  )
                : _buildMessageList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Color(FlickoColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _messages.length + 1,
        itemBuilder: (context, index) {
          if (index == _messages.length) {
            return _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(FlickoColors.blurple),
                      ),
                    ),
                  )
                : const SizedBox();
          }
          return EnhancedMessageItem(
            message: _messages[index],
            isContinuation: false,
            onReactionToggle: (emoji) => _toggleReaction(_messages[index].id, emoji),
            onReply: () => setState(() => _replyTo = _messages[index]),
            onEdit: (newContent) {
              _editMessage(_messages[index].id, newContent);
              setState(() => _editingMessageId = null);
            },
            onEditCancel: () => setState(() => _editingMessageId = null),
            isEditing: _editingMessageId == _messages[index].id,
            onDelete: () => _deleteMessage(_messages[index].id),
            onLongPress: () => _onMessageLongPress(_messages[index]),
            onCopy: () {},
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgPrimary),
        border: Border(
          top: BorderSide(color: Color(FlickoColors.border), width: 1),
        ),
      ),
      child: EnhancedMessageInput(
        serverId: widget.serverId,
        replyToName: _replyTo?.author?.displayName ?? _replyTo?.author?.username,
        onSend: (content, {attachments, gifUrl, stickerUrl}) {
          _sendMessage(content);
        },
        onCancelReply: () => setState(() => _replyTo = null),
      ),
    );
  }
}
