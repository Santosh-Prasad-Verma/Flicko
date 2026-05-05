import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class _ThreadViewScreenState extends ConsumerState<ThreadViewScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _thread;
  List<FlickoMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  FlickoMessage? _replyTo;
  int _currentPage = 1;
  bool _hasNextPage = false;
  late final AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _listController.dispose();
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
    _listController.forward(from: 0);
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
      
      if (reset && !_isLoading) {
        _listController.forward(from: 0);
      }
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
      onEdit: () {
        // Edit is handled inline by EnhancedMessageItem
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
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
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
                      color: const Color(FlickoColors.blurpleLight).withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    _thread?['name'] ?? 'Loading...',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                if (_thread != null)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            color: Color(FlickoColors.textMuted), size: 12),
                        const SizedBox(width: 6),
                        Text(
                          '${_thread?['message_count'] ?? 0}',
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textSecondary),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E1F22),
              Color(FlickoColors.bgTertiary),
            ],
          ),
        ),
        child: Column(
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
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Color(FlickoColors.textMuted),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to the beginning of the thread',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No messages yet. Say hi!',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 14,
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
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
          bottom: 16,
        ),
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
          final message = _messages[index];
          final prevMessage = index > 0 ? _messages[index - 1] : null;

          bool isContinuation = false;
          if (prevMessage != null && 
              prevMessage.authorId == message.authorId &&
              prevMessage.type != 'system') {
            final diff = message.createdAt.difference(prevMessage.createdAt).abs();
            if (diff.inMinutes < 5) {
              isContinuation = true;
            }
          }

          // Staggered animation
          final animation = CurvedAnimation(
            parent: _listController,
            curve: Interval(
              (index / (_messages.length.clamp(1, 15))).clamp(0.0, 1.0),
              1.0,
              curve: Curves.easeOutCubic,
            ),
          );

          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - animation.value)),
                child: Opacity(
                  opacity: animation.value,
                  child: child,
                ),
              );
            },
            child: EnhancedMessageItem(
              message: message,
              isContinuation: isContinuation,
              onReactionToggle: (emoji) => _toggleReaction(message.id, emoji),
              onLongPress: () => _onMessageLongPress(message),
              onEdit: (newContent) async {
                try {
                  await Supabase.instance.client
                      .from('messages')
                      .update({'content': newContent})
                      .eq('id', message.id);
                  _loadMessages(reset: false);
                } catch (e) {
                  // Error
                }
              },
              onDelete: () => _deleteMessage(message.id),
              onReply: () => setState(() => _replyTo = message),
              onCopy: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied to clipboard', style: GoogleFonts.inter()),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgPrimary).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
        ),
      ),
      child: EnhancedMessageInput(
        onSend: (content, {attachments, gifUrl, stickerUrl}) {
          _sendMessage(content);
        },
        replyToName: _replyTo?.author?.displayName ?? _replyTo?.author?.username,
        onCancelReply: () => setState(() => _replyTo = null),
      ),
    );
  }
}
