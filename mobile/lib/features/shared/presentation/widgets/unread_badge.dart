import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

enum BadgeSize { small, medium, large }

class UnreadBadge extends StatelessWidget {
  final String channelId;
  final int? count;
  final int? mentionCount;
  final BadgeSize size;
  final bool dot;

  const UnreadBadge({
    super.key,
    required this.channelId,
    this.count,
    this.mentionCount,
    this.size = BadgeSize.medium,
    this.dot = false,
  });

  static const _sizeMap = {
    BadgeSize.small: {'minWidth': 16.0, 'height': 16.0, 'fontSize': 10.0, 'padding': 3.0},
    BadgeSize.medium: {'minWidth': 20.0, 'height': 20.0, 'fontSize': 11.0, 'padding': 4.0},
    BadgeSize.large: {'minWidth': 24.0, 'height': 24.0, 'fontSize': 13.0, 'padding': 5.0},
  };

  int get _unreadCount => count ?? 0;
  int get _mentionCountVal => mentionCount ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_unreadCount <= 0 && _mentionCountVal <= 0) {
      return const SizedBox.shrink();
    }

    final hasMentions = _mentionCountVal > 0;
    final displayCount = hasMentions ? _mentionCountVal : _unreadCount;
    final sizeConfig = _sizeMap[size]!;

    final backgroundColor = hasMentions
        ? const Color(FlickoColors.blurple)
        : const Color(0x00ed4245);
    final displayText = displayCount > 99 ? '99+' : displayCount.toString();

    if (dot) {
      return Container(
        width: sizeConfig['height']! * 0.5,
        height: sizeConfig['height']! * 0.5,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        minWidth: sizeConfig['minWidth']!,
        minHeight: sizeConfig['height']!,
        maxHeight: sizeConfig['height']!,
      ),
      padding: EdgeInsets.symmetric(horizontal: sizeConfig['padding']!),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(sizeConfig['height']! / 2),
      ),
      child: Center(
        child: Text(
          displayText,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: sizeConfig['fontSize'],
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

class UnreadDot extends StatelessWidget {
  final bool visible;
  final Color? color;
  final double size;

  const UnreadDot({
    super.key,
    required this.visible,
    this.color,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? const Color(0x00ed4245),
        shape: BoxShape.circle,
      ),
    );
  }
}
