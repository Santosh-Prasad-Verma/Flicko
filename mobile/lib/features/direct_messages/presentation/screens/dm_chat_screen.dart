import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_chat_controller.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_controller.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/message_bubble.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/dm_chat_input.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';
import 'package:mobile/features/e2ee/application/identity_change_alert_provider.dart';
import 'package:mobile/features/e2ee/presentation/identity_change_banner.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/core/services/presence_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/calling/presentation/incoming_call_overlay.dart';
import 'package:mobile/features/calling/services/call_signaling_service.dart';
import 'package:mobile/features/calling/services/webrtc_call_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/store/data/warp_service.dart';
import 'package:mobile/features/shared/presentation/widgets/entrance_warp_overlay.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/features/server_channels/chat/presentation/widgets/pinned_messages_sheet.dart';

class DMChatScreen extends ConsumerStatefulWidget {
  final String userId;

  const DMChatScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<DMChatScreen> createState() => _DMChatScreenState();
}

class _DMChatScreenState extends ConsumerState<DMChatScreen> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<CallSignalPayload>? _signalSub;
  CallSignalingService? _signalingService;
  String? _myUserId;
  String? _participantName;
  String? _participantAvatarUrl;
  bool _showEntranceWarp = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  bool _isSummarizing = false;
  String? _chatSummary;
  String? _summaryError;

  Future<void> _handleCatchMeUp(List<DMMessage> messages, String participantName) async {
    if (messages.isEmpty) {
      setState(() {
        _summaryError = 'No messages to summarize.';
      });
      return;
    }

    setState(() {
      _isSummarizing = true;
      _chatSummary = null;
      _summaryError = null;
    });

    try {
      final recentMessages = messages.take(40).toList();
      final messagesJson = recentMessages.map((m) {
        final senderName = m.senderId == _myUserId ? 'Me' : participantName;
        return {
          'sender': senderName,
          'content': m.content,
        };
      }).toList().reversed.toList();

      if (!AppConfig.hasApiBaseUrl) {
        throw Exception('API base URL is not configured.');
      }

      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl.endsWith('/') ? AppConfig.apiBaseUrl : '${AppConfig.apiBaseUrl}/',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ""}',
        },
      ));

      final response = await dio.post(
        'api/v1/ai/summary/chat',
        data: {'messages': messagesJson},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map && data.containsKey('summary')) {
          setState(() {
            _chatSummary = data['summary'] as String;
            _isSummarizing = false;
          });
        } else {
          throw Exception('Failed to parse summary response');
        }
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) {
          errorMsg = data['error']?.toString() ?? e.message ?? e.toString();
        } else if (data is String && data.isNotEmpty) {
          errorMsg = data;
        } else {
          errorMsg = e.message ?? e.toString();
        }
      }
      setState(() {
        _summaryError = 'Aura could not summarize the conversation: $errorMsg';
        _isSummarizing = false;
      });
    }
  }

  Widget _buildCatchMeUpSection(List<DMMessage> messages, String participantName) {
    if (!_isSummarizing && _chatSummary == null && _summaryError == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(FlickoColors.brandLime).withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(FlickoColors.brandLime).withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Material(
                  color: const Color(0xFF0F0F12).withValues(alpha: 0.6),
                  child: InkWell(
                    onTap: () => _handleCatchMeUp(messages, participantName),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: Color(FlickoColors.brandLime)),
                          const SizedBox(width: 8),
                          Text(
                            'Catch me up',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: const Color(0xFF0F0F12).withValues(alpha: 0.75),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: Color(FlickoColors.brandLime)),
                    const SizedBox(width: 8),
                    Text(
                      _isSummarizing ? 'Aura is reading...' : 'Aura Summary',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    if (!_isSummarizing)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSummarizing = false;
                            _chatSummary = null;
                            _summaryError = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white60),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isSummarizing)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(FlickoColors.brandLime)),
                        minHeight: 2,
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(3, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: i == 0 ? 0.95 : (i == 1 ? 0.85 : 0.6),
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  )
                else if (_summaryError != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _summaryError!,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleCatchMeUp(messages, participantName),
                          icon: const Icon(Icons.refresh, size: 14, color: Color(FlickoColors.brandLime)),
                          label: Text(
                            'Retry',
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(FlickoColors.brandLime),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.3)),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (_chatSummary != null)
                  Text(
                    _chatSummary!,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    Future.microtask(() {
      final authState = ref.read(authNotifierProvider);
      _myUserId = authState.maybeWhen(
        authenticated: (user, _) => user.id,
        orElse: () => null,
      );
      if (_myUserId == null) return;

      _signalingService = ref.read(callSignalingServiceProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _signalSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _currentUserName() {
    return ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, profile) =>
              profile?.displayName ??
              profile?.username ??
              user.email?.split('@').first ??
              'Flicko User',
          orElse: () => 'Flicko User',
        );
  }

  String? _currentUserAvatarUrl() {
    return ref.read(authNotifierProvider).maybeWhen(
          authenticated: (_, profile) => profile?.avatarUrl,
          orElse: () => null,
        );
  }

  void _showCallUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in again before starting a call.')),
    );
  }

  // ignore: unused_element
  void _handleCallSignal(CallSignalPayload signal) {
    if (!mounted) return;

    switch (signal.signal) {
      case CallSignal.ring:
        // Incoming call — show the incoming call screen.
        final convoState = ref.read(dmControllerProvider);
        // ignore: unused_local_variable
        final conversation = convoState.conversations
            .cast<DMConversation?>()
            .firstWhere((c) => c?.id == signal.callerId, orElse: () => null);
        final callerName = signal.callerName;
        final callerAvatar = signal.callerAvatarUrl;
        final myName = _currentUserName();
        final myAvatar = _currentUserAvatarUrl();

        final isVideo = signal.callType == 'video';
        if (isVideo) {
          CallOverlay.showIncomingVideo(
            context,
            callerName: callerName,
            callerAvatarUrl: callerAvatar,
            onAccept: () {
              _sendSignal(
                signal: CallSignal.accept,
                calleeId: signal.callerId,
                callerId: _myUserId!,
                callerName: myName,
                callerAvatarUrl: myAvatar,
                roomName: signal.roomName,
                callType: signal.callType,
              );
              CallOverlay.acceptCall(
                context,
                peerName: callerName,
                peerAvatarUrl: callerAvatar,
                isVideo: true,
                roomName: signal.roomName,
                myUserId: _myUserId!,
                peerUserId: signal.callerId,
                isCaller: false,
                onHangUp: () => _sendSignal(
                  signal: CallSignal.end,
                  calleeId: signal.callerId,
                  callerId: _myUserId!,
                  callerName: myName,
                  callerAvatarUrl: myAvatar,
                  roomName: signal.roomName,
                  callType: signal.callType,
                ),
              );
            },
            onDecline: () {
              _sendSignal(
                signal: CallSignal.decline,
                calleeId: signal.callerId,
                callerId: _myUserId!,
                callerName: myName,
                callerAvatarUrl: myAvatar,
                roomName: signal.roomName,
                callType: signal.callType,
              );
            },
          );
        } else {
          CallOverlay.showIncoming(
            context,
            callerName: callerName,
            callerAvatarUrl: callerAvatar,
            callType: signal.callType,
            onAccept: () {
              _sendSignal(
                signal: CallSignal.accept,
                calleeId: signal.callerId,
                callerId: _myUserId!,
                callerName: myName,
                callerAvatarUrl: myAvatar,
                roomName: signal.roomName,
                callType: signal.callType,
              );
              CallOverlay.acceptCall(
                context,
                peerName: callerName,
                peerAvatarUrl: callerAvatar,
                isVideo: false,
                roomName: signal.roomName,
                myUserId: _myUserId!,
                peerUserId: signal.callerId,
                isCaller: false,
                onHangUp: () => _sendSignal(
                  signal: CallSignal.end,
                  calleeId: signal.callerId,
                  callerId: _myUserId!,
                  callerName: myName,
                  callerAvatarUrl: myAvatar,
                  roomName: signal.roomName,
                  callType: signal.callType,
                ),
              );
            },
            onDecline: () {
              _sendSignal(
                signal: CallSignal.decline,
                calleeId: signal.callerId,
                callerId: _myUserId!,
                callerName: myName,
                callerAvatarUrl: myAvatar,
                roomName: signal.roomName,
                callType: signal.callType,
              );
            },
          );
        }
        break;

      case CallSignal.accept:
        // Caller side: callee accepted. Join the room.
        final peerName = signal.callerName.isNotEmpty
            ? signal.callerName
            : (_participantName ?? 'Friend');
        CallOverlay.acceptCall(
          context,
          peerName: peerName,
          peerAvatarUrl: signal.callerAvatarUrl ?? _participantAvatarUrl,
          isVideo: signal.callType == 'video',
          roomName: signal.roomName,
          myUserId: _myUserId!,
          peerUserId: signal.callerId,
          isCaller: true,
          onHangUp: () => _sendSignal(
            signal: CallSignal.end,
            calleeId: signal.callerId,
            callerId: _myUserId!,
            callerName: _currentUserName(),
            callerAvatarUrl: _currentUserAvatarUrl(),
            roomName: signal.roomName,
            callType: signal.callType,
          ),
        );
        break;

      case CallSignal.decline:
        // Caller side: callee declined. Dismiss the outgoing screen.
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${signal.callerName} declined the call')),
          );
        }
        break;

      case CallSignal.cancel:
        // Callee side: caller hung up before answer.
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        break;

      case CallSignal.end:
        // Either side: call ended.
        ref.read(webRtcCallServiceProvider).endCall(notifyPeer: false);
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        break;

      case CallSignal.connected:
        // Call connected / established.
        break;
    }
  }

  Future<void> _sendSignal({
    required CallSignal signal,
    required String calleeId,
    required String callerId,
    String callerName = '',
    String? callerAvatarUrl,
    required String roomName,
    required String callType,
  }) async {
    _signalingService ??= ref.read(callSignalingServiceProvider);
    if (_signalingService == null) return;

    final payload = CallSignalPayload(
      signal: signal,
      callerId: callerId,
      callerName: callerName,
      callerAvatarUrl: callerAvatarUrl,
      calleeId: calleeId,
      callType: callType,
      roomName: roomName,
    );

    await _signalingService!.sendSignal(payload);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(dmChatControllerProvider(widget.userId).notifier)
          .fetchMessages(loadMore: true);
    }
  }

  void _startVoiceCall(String name, String? avatarUrl) {
    if (_myUserId == null || _myUserId!.isEmpty) {
      _showCallUnavailable();
      return;
    }
    _participantName = name;
    _participantAvatarUrl = avatarUrl;
    final myName = _currentUserName();
    final myAvatar = _currentUserAvatarUrl();

    final roomName = CallSignalingService.roomNameForDM(
      _myUserId!,
      widget.userId,
    );

    _sendSignal(
      signal: CallSignal.ring,
      calleeId: widget.userId,
      callerId: _myUserId!,
      callerName: myName,
      callerAvatarUrl: myAvatar,
      roomName: roomName,
      callType: 'voice',
    );

    CallOverlay.showOutgoing(
      context,
      calleeName: name,
      calleeAvatarUrl: avatarUrl,
      callType: 'voice',
      onCancel: () {
        _sendSignal(
          signal: CallSignal.cancel,
          calleeId: widget.userId,
          callerId: _myUserId!,
          callerName: myName,
          callerAvatarUrl: myAvatar,
          roomName: roomName,
          callType: 'voice',
        );
      },
    );
  }

  void _startVideoCall(String name, String? avatarUrl) {
    if (_myUserId == null || _myUserId!.isEmpty) {
      _showCallUnavailable();
      return;
    }
    _participantName = name;
    _participantAvatarUrl = avatarUrl;
    final myName = _currentUserName();
    final myAvatar = _currentUserAvatarUrl();

    final roomName = CallSignalingService.roomNameForDM(
      _myUserId!,
      widget.userId,
    );

    _sendSignal(
      signal: CallSignal.ring,
      calleeId: widget.userId,
      callerId: _myUserId!,
      callerName: myName,
      callerAvatarUrl: myAvatar,
      roomName: roomName,
      callType: 'video',
    );

    CallOverlay.showOutgoingVideo(
      context,
      calleeName: name,
      calleeAvatarUrl: avatarUrl,
      onCancel: () {
        _sendSignal(
          signal: CallSignal.cancel,
          calleeId: widget.userId,
          callerId: _myUserId!,
          callerName: myName,
          callerAvatarUrl: myAvatar,
          roomName: roomName,
          callType: 'video',
        );
      },
    );
  }

  void _showProfileOptions(
      String? userId, String name, String? avatarUrl, String onlineStatus) {
    if (userId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.textMuted),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // User info
                Row(
                  children: [
                    UserAvatar(
                      imageUrl: avatarUrl,
                      name: name,
                      size: 52,
                      status: onlineStatus,
                      showStatus: true,
                      userId: userId,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Color(FlickoColors.textPrimary),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getStatusColor(onlineStatus),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getStatusLabel(onlineStatus),
                                style: TextStyle(
                                  color: _getStatusColor(onlineStatus),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Actions
                _BottomSheetAction(
                  icon: Icons.person_rounded,
                  label: 'View Profile',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/profile/$userId');
                  },
                ),
                _BottomSheetAction(
                  icon: Icons.call_rounded,
                  label: 'Voice Call',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startVoiceCall(name, avatarUrl);
                  },
                ),
                _BottomSheetAction(
                  icon: Icons.videocam_rounded,
                  label: 'Video Call',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startVideoCall(name, avatarUrl);
                  },
                ),
                _BottomSheetAction(
                  icon: Icons.block_rounded,
                  label: 'Block User',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DMChatState>(dmChatControllerProvider(widget.userId), (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });
    final state = ref.watch(dmChatControllerProvider(widget.userId));
    final convoState = ref.watch(dmControllerProvider);
    final conversation =
        convoState.conversations.cast<DMConversation?>().firstWhere(
              (c) => c?.id == widget.userId,
              orElse: () => null,
            );

    final participant = state.participant ?? conversation?.participant;
    final participantName =
        participant?.displayName ?? participant?.username ?? 'Chat';
    final onlineStatus = participant?.onlineStatus ?? 'offline';
    final equippedWarp = ref.watch(equippedWarpProvider).value;

    final myId = ref.watch(currentUserIdProvider) ?? '';
    final conversationId = [myId, widget.userId]..sort();
    final conversationIdStr = conversationId.join('_');
    final typingUsersAsync = ref.watch(typingStatusProvider(conversationIdStr));
    final isOtherUserTyping = typingUsersAsync.maybeWhen(
      data: (users) => users.contains(widget.userId),
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: Stack(
        children: [
          Column(
            children: [
              // ── CHAT APP BAR ──
              SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 6, 8, 12),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgPrimary),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(FlickoColors.border)
                            .withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Color(FlickoColors.textPrimary), size: 22),
                      ),

                      // Tappable avatar + name + status / Search field
                      Expanded(
                        child: _isSearching
                            ? TextField(
                                controller: _searchController,
                                autofocus: true,
                                onChanged: (_) => setState(() {}),
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Search DM messages...',
                                  hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14),
                                  border: InputBorder.none,
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _showProfileOptions(
                                  participant?.id,
                                  participantName,
                                  participant?.avatarUrl,
                                  onlineStatus,
                                ),
                                child: Row(
                                  children: [
                                    if (participant != null)
                                      UserAvatar(
                                        imageUrl: participant.avatarUrl,
                                        name: participantName,
                                        size: 36,
                                        status: onlineStatus,
                                        showStatus: true,
                                        userId: participant.id,
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            participantName,
                                            style: const TextStyle(
                                              color: Color(FlickoColors.textPrimary),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.1,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            _getStatusLabel(onlineStatus),
                                            style: TextStyle(
                                              color: _getStatusColor(onlineStatus),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      // Search action
                      _AppBarAction(
                        icon: _isSearching ? Icons.close : Icons.search_rounded,
                        onTap: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 4),

                      // Pinned messages action
                      _AppBarAction(
                        icon: Icons.push_pin_outlined,
                        onTap: () {
                          final messages = ref.read(dmChatControllerProvider(conversationIdStr)).messages;
                          final pinned = messages
                              .where((m) => m.reactions.any((r) => r.emoji == '📌'))
                              .map((m) => FlickoMessage(
                                    id: m.id,
                                    authorId: m.senderId,
                                    author: m.sender,
                                    content: m.content,
                                    createdAt: m.createdAt,
                                    pinned: true,
                                  ))
                              .toList();
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (ctx) => PinnedMessagesSheet(
                              pinnedMessages: pinned,
                              onJumpToMessage: (msg) {
                                final idx = messages.indexWhere((m) => m.id == msg.id);
                                if (idx >= 0 && _scrollController.hasClients) {
                                  _scrollController.animateTo(
                                    idx * 80.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),

                      // Voice call button
                      _AppBarAction(
                        icon: Icons.call_rounded,
                        onTap: () => _startVoiceCall(
                            participantName, participant?.avatarUrl),
                      ),
                      const SizedBox(width: 4),
                      // Video call button
                      _AppBarAction(
                        icon: Icons.videocam_rounded,
                        onTap: () => _startVideoCall(
                            participantName, participant?.avatarUrl),
                      ),
                    ],
                  ),
                ),
              ),

              // ── IDENTITY CHANGE BANNER ──
              // Shown only when the peer's published fingerprint differs
              // from the one we last pinned. First-contact is auto-ack'd
              // by [identityChangeAlertProvider].
              Consumer(
                builder: (context, ref, _) {
                  final alertAsync =
                      ref.watch(identityChangeAlertProvider(widget.userId));
                  return alertAsync.maybeWhen(
                    data: (alert) {
                      if (alert == null) return const SizedBox.shrink();
                      return IdentityChangeBanner(
                        alert: alert,
                        onTrusted: () => ref.invalidate(
                            identityChangeAlertProvider(widget.userId)),
                        onDismiss: () => ref.invalidate(
                            identityChangeAlertProvider(widget.userId)),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),

              // ── CATCH UP ──
              _buildCatchMeUpSection(state.messages, participantName),

              // ── MESSAGES ──
              Expanded(
                child: state.isLoading && state.messages.isEmpty
                    ? const MessageListSkeleton(count: 6)
                    : Builder(
                        builder: (context) {
                          final filteredDMMessages = _isSearching && _searchController.text.trim().isNotEmpty
                              ? state.messages.where((m) => m.content.toLowerCase().contains(_searchController.text.trim().toLowerCase())).toList()
                              : state.messages;

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
                            reverse: true,
                            itemCount: filteredDMMessages.length + (state.hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredDMMessages.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                      color: Color(FlickoColors.emeraldGreen),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }
                              final message = filteredDMMessages[index];
                              final senderName = message.sender?.displayName ??
                                  message.sender?.username ??
                                  'Unknown';
                              return MessageBubble(
                                message: message,
                                onTapProfile: () {
                                  _showProfileOptions(
                                    message.sender?.id,
                                    senderName,
                                    message.sender?.avatarUrl,
                                    message.sender?.onlineStatus ?? 'offline',
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),

              // ── TYPING INDICATOR ──
              if (isOtherUserTyping)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(FlickoColors.brandLime),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$participantName is typing...',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textSecondary),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── INPUT ──
              DMChatInput(
                onSend: (content, {attachments, gifUrl, stickerUrl}) {
                  var messageContent = content;
                  if (gifUrl != null) messageContent = gifUrl;
                  if (stickerUrl != null) messageContent = stickerUrl;

                  ref
                      .read(dmChatControllerProvider(widget.userId).notifier)
                      .sendMessage(
                        messageContent,
                        localAttachments: attachments,
                      );
                },
                onTypingStart: () {
                  if (myId.isNotEmpty) {
                    final ids = [myId, widget.userId]..sort();
                    ref.read(presenceServiceProvider).setTyping(ids.join('_'), true);
                  }
                },
                onTypingStop: () {
                  if (myId.isNotEmpty) {
                    final ids = [myId, widget.userId]..sort();
                    ref.read(presenceServiceProvider).setTyping(ids.join('_'), false);
                  }
                },
              ),
            ],
          ),
          if (_showEntranceWarp && equippedWarp != null)
            EntranceWarpOverlay(
              warpId: equippedWarp.id,
              onComplete: () {
                setState(() {
                  _showEntranceWarp = false;
                });
              },
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return const Color(FlickoColors.statusOnline);
      case 'idle':
        return const Color(FlickoColors.statusIdle);
      case 'dnd':
        return const Color(FlickoColors.statusDnd);
      default:
        return const Color(FlickoColors.statusOffline);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'online':
        return 'Online';
      case 'idle':
        return 'Idle';
      case 'dnd':
        return 'Do Not Disturb';
      default:
        return 'Offline';
    }
  }
}

/// Clean app-bar action button
class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AppBarAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgTertiary),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(FlickoColors.border),
              width: 1,
            ),
          ),
          child: Icon(icon,
              color: const Color(FlickoColors.textPrimary), size: 20),
        ),
      ),
    );
  }
}

/// Bottom sheet action row
class _BottomSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _BottomSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(FlickoColors.danger)
        : const Color(FlickoColors.textPrimary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
