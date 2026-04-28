import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// A wrapper around [Image.file] or [Image.network] that checks for
/// file existence, empty files, and loading errors.
class SafeImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  const SafeImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.color,
    this.borderRadius,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return _buildPlaceholder();
    }

    final isNetwork = path!.startsWith('http');
    final child = isNetwork ? _buildNetworkImage() : _buildFileImage();

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }

    return child;
  }

  Widget _buildFileImage() {
    final file = File(path!);
    if (!file.existsSync() || file.lengthSync() == 0) {
      return _buildPlaceholder();
    }

    return Image.file(
      file,
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  Widget _buildNetworkImage() {
    return Image.network(
      path!,
      width: width,
      height: height,
      fit: fit,
      color: color,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildPlaceholder(isLoading: true);
      },
    );
  }

  Widget _buildPlaceholder({bool isLoading = false}) {
    return Container(
      width: width,
      height: height,
      color: const Color(FlickoColors.bgTertiary),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(FlickoColors.textMuted),
                ),
              )
            : placeholder ??
                const Icon(
                  Icons.image_not_supported_outlined,
                  color: Color(FlickoColors.textMuted),
                  size: 20,
                ),
      ),
    );
  }
}
