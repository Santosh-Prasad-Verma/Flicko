import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';

class GroupDM {
  final String id;
  final String? name;
  final List<GroupDMParticipant> participants;
  final String? lastMessageAt;

  GroupDM({
    required this.id,
    this.name,
    required this.participants,
    this.lastMessageAt,
  });

  factory GroupDM.fromJson(Map<String, dynamic> json) {
    return GroupDM(
      id: json['id'] as String,
      name: json['name'] as String?,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((p) => GroupDMParticipant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessageAt: json['last_message_at'] as String?,
    );
  }
}

class GroupDMParticipant {
  final String userId;
  final String username;
  final String? displayName;

  GroupDMParticipant({
    required this.userId,
    required this.username,
    this.displayName,
  });

  factory GroupDMParticipant.fromJson(Map<String, dynamic> json) {
    return GroupDMParticipant(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
    );
  }
}

class GroupDMListScreen extends ConsumerStatefulWidget {
  const GroupDMListScreen({super.key});

  @override
  ConsumerState<GroupDMListScreen> createState() => _GroupDMListScreenState();
}

class _GroupDMListScreenState extends ConsumerState<GroupDMListScreen> {
  bool _isLoading = true;
  List<GroupDM> _groups = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGroupDMs();
  }

  Future<void> _loadGroupDMs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await Supabase.instance.client
          .from('group_dms')
          .select('*, group_dm_participants(user_id, username, display_name)')
          .eq('user_id', user.id);

      setState(() {
        _groups = (response as List)
            .map((g) => GroupDM.fromJson(g as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleGroupPress(GroupDM group) {
    // Navigate to group DM chat
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(group.name ?? 'Group DM')),
          body: const Center(child: Text('Group DM Chat - Coming Soon')),
        ),
      ),
    );
  }

  void _handleCreateGroup() {
    // Navigate to create group screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create Group - Coming Soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getDisplayName(GroupDM group) {
    final user = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    if (group.name != null && group.name!.isNotEmpty) {
      return group.name!;
    }

    final participantNames = group.participants
        .where((p) => p.userId != user?.id)
        .map((p) => p.displayName ?? p.username)
        .join(', ');
    return participantNames.isNotEmpty ? participantNames : 'Group DM';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Group Messages',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(FlickoColors.blurple)),
            onPressed: _handleCreateGroup,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SafeArea(
        child: DMListSkeleton(count: 6),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text(
              'Error loading groups',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGroupDMs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 48, color: Color(FlickoColors.textMuted)),
            const SizedBox(height: 16),
            Text(
              'No group conversations yet',
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
      onRefresh: _loadGroupDMs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groups.length,
        itemBuilder: (context, index) => _buildGroupCard(_groups[index]),
      ),
    );
  }

  Widget _buildGroupCard(GroupDM group) {
    return GestureDetector(
      onTap: () => _handleGroupPress(group),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgTertiary),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people,
                color: Color(FlickoColors.textSecondary),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDisplayName(group),
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.participants.length} members',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(FlickoColors.textMuted),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
