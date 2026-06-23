import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

enum AvatarSize { xs, sm, md, lg, xl }

enum StatusIndicator { online, idle, dnd, offline }

class Avatar extends StatelessWidget {
  final String? uri;
  final String? imageUrl;
  final String? name;
  final Object size;
  final StatusIndicator? status;
  final String? accessibilityLabel;

  const Avatar({
    super.key,
    this.uri,
    this.imageUrl,
    this.name,
    this.size = AvatarSize.md,
    this.status,
    this.accessibilityLabel,
  });

  static const _sizeMap = {
    AvatarSize.xs: 24.0,
    AvatarSize.sm: 32.0,
    AvatarSize.md: 40.0,
    AvatarSize.lg: 48.0,
    AvatarSize.xl: 64.0,
  };

  double get _dimension {
    final value = size;
    if (value is AvatarSize) return _sizeMap[value] ?? 40.0;
    if (value is num) return value.toDouble();
    return 40.0;
  }
  String get _resolvedUri => uri ?? imageUrl ?? '';
  String get _label => accessibilityLabel ?? name ?? 'Avatar';

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }

  Color get _statusColor {
    switch (status) {
      case StatusIndicator.online:
        return const Color(0x0023a559);
      case StatusIndicator.idle:
        return const Color(0x00f0b232);
      case StatusIndicator.dnd:
        return const Color(0x00f23f43);
      case StatusIndicator.offline:
        return const Color(0x0080848e);
      default:
        return const Color(0x0080848e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusSize = (_dimension * 0.3).round();

    return Semantics(
      label: _label,
      image: true,
      child: SizedBox(
        width: _dimension,
        height: _dimension,
        child: Stack(
          children: [
            Container(
              width: _dimension,
              height: _dimension,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgTertiary),
                shape: BoxShape.circle,
              ),
              child: _resolvedUri.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _resolvedUri,
                        width: _dimension,
                        height: _dimension,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              _initials,
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textPrimary),
                                fontSize: _dimension * 0.4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        _initials,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: _dimension * 0.4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            if (status != null)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: statusSize.toDouble(),
                  height: statusSize.toDouble(),
                  decoration: BoxDecoration(
                    color: _statusColor,
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
      ),
    );
  }
}
