import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

enum UserStatus { online, idle, dnd, offline }

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final UserStatus status;
  final bool showStatus;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    this.status = UserStatus.offline,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _buildAvatar(),
          if (showStatus)
            Positioned(
              right: 0,
              bottom: 0,
              child: _buildStatusIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Container(
        decoration: const BoxDecoration(shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildFallback(),
          errorWidget: (context, url, error) => _buildFallback(),
        ),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.blurple),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final Color color;
    switch (status) {
      case UserStatus.online:
        color = const Color(FlickoColors.statusOnline);
      case UserStatus.idle:
        color = const Color(FlickoColors.statusIdle);
      case UserStatus.dnd:
        color = const Color(FlickoColors.statusDnd);
      case UserStatus.offline:
        color = const Color(FlickoColors.statusOffline);
    }

    return Container(
      width: size * 0.35,
      height: size * 0.35,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(FlickoColors.bgSecondary),
          width: size * 0.05,
        ),
      ),
    );
  }
}
