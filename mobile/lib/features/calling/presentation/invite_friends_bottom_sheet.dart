import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteFriendsBottomSheet extends StatefulWidget {
  const InviteFriendsBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const InviteFriendsBottomSheet(),
    );
  }

  @override
  State<InviteFriendsBottomSheet> createState() => _InviteFriendsBottomSheetState();
}

class _InviteFriendsBottomSheetState extends State<InviteFriendsBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _friends = [];
  bool _isLoading = true;
  final Set<String> _invitedNames = {};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final query = currentUserId != null
          ? Supabase.instance.client.from('profiles').select('id, username, display_name, avatar').neq('id', currentUserId).limit(20)
          : Supabase.instance.client.from('profiles').select('id, username, display_name, avatar').limit(20);
      final data = await query;
      if (mounted) {
        setState(() {
          _friends = (data as List).map((row) {
            final name = (row['display_name'] as String?)?.isNotEmpty == true
                ? row['display_name'] as String
                : (row['username'] as String? ?? 'Flicko User');
            final avatar = row['avatar'] as String? ?? '';
            return {'name': name, 'avatar': avatar};
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);
    const brandGreen = Color(FlickoColors.brandLime);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Invite a friend',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildShareActionTile(Icons.ios_share_rounded, 'Share Invite'),
                    _buildShareActionTile(Icons.link_rounded, 'Copy Link'),
                    _buildShareActionTile(Icons.qr_code_scanner_rounded, 'QR Code'),
                    _buildShareActionTile(Icons.chat_bubble_outline_rounded, 'Messages'),
                    _buildShareActionTile(Icons.mail_outline_rounded, 'Email'),
                    _buildShareActionTile(Icons.send_rounded, 'Telegram'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      icon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                      hintText: 'Invite friends to Flicko',
                      hintStyle: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Your invite link expires in 30 days. ',
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Text(
                        'Edit invite link.',
                        style: GoogleFonts.inter(
                          color: brandGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _friends.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final name = friend['name']!;
                    final avatar = friend['avatar']!;
                    final isInvited = _invitedNames.contains(name);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: bgTertiary,
                            backgroundImage: (avatar.isNotEmpty && (avatar.startsWith('http://') || avatar.startsWith('https://')))
                                ? NetworkImage(avatar)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isInvited) {
                                  _invitedNames.remove(name);
                                } else {
                                  _invitedNames.add(name);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: isInvited
                                    ? brandGreen
                                    : bgTertiary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                isInvited ? 'Sent' : 'Invite',
                                style: GoogleFonts.inter(
                                  color: isInvited ? Colors.black : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareActionTile(IconData icon, String label) {
    const bgTertiary = Color(FlickoColors.bgTertiary);
    const brandGreen = Color(FlickoColors.brandLime);

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: bgTertiary,
            ),
            child: Icon(icon, color: brandGreen, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
