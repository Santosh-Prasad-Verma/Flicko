import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OnlineFriendsRow extends StatelessWidget {
  final List<UserModel> friends;
  final Function(UserModel) onFriendTap;

  const OnlineFriendsRow({
    super.key,
    required this.friends,
    required this.onFriendTap,
  });

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: FlickoSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: friends.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: FlickoSpacing.md),
        itemBuilder: (context, index) {
          final friend = friends[index];
          return _OnlineFriendItem(
            user: friend,
            onTap: () => onFriendTap(friend),
          );
        },
      ),
    );
  }
}

class _OnlineFriendItem extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _OnlineFriendItem({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(FlickoColors.bgSecondary),
                  border: Border.all(
                    color: const Color(FlickoColors.border),
                    width: 1.5,
                  ),
                  boxShadow: user.onlineStatus == 'online'
                      ? const [
                          BoxShadow(
                            color: Color(FlickoColors.emeraldGreen),
                            blurRadius: 14,
                            spreadRadius: -6,
                          ),
                        ]
                      : null,
                  image: user.avatarUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(user.avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: user.avatarUrl == null
                    ? const Icon(Icons.person,
                        color: Color(FlickoColors.textMuted))
                    : null,
              ),
              Positioned(
                right: 2,
                bottom: -1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _getStatusColor(user.onlineStatus),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(FlickoColors.bgPrimary),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              user.displayName ?? user.username,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: const Color(FlickoColors.textPrimary),
                    fontWeight: FontWeight.w600,
                    overflow: TextOverflow.ellipsis,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
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
}
