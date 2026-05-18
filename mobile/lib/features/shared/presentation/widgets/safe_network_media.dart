import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class SafeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final String? contentType;
  final String? fileName;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.contentType,
    this.fileName,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (_isGif) {
      return _GifPreview(
        url: imageUrl,
        fileName: fileName,
        width: width,
        height: height,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      maxWidthDiskCache: 800,
      placeholder: (context, url) => Container(
        width: width ?? 300,
        height: height ?? 200,
        color: const Color(FlickoColors.bgSecondary),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => Container(
        width: width ?? 300,
        height: height ?? 200,
        color: const Color(FlickoColors.bgSecondary),
        child: const Icon(Icons.broken_image,
            color: Color(FlickoColors.textMuted)),
      ),
    );
  }

  bool get _isGif {
    final type = contentType?.toLowerCase() ?? '';
    final name = fileName?.toLowerCase() ?? '';
    final url = imageUrl.toLowerCase();
    return type == 'image/gif' ||
        name.endsWith('.gif') ||
        Uri.tryParse(url)?.path.endsWith('.gif') == true;
  }
}

class _GifPreview extends StatelessWidget {
  final String url;
  final String? fileName;
  final double? width;
  final double? height;

  const _GifPreview({
    required this.url,
    this.fileName,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openGif(url),
      child: Container(
        width: width ?? 300,
        height: height ?? 160,
        constraints: const BoxConstraints(maxWidth: 300, minHeight: 120),
        padding: const EdgeInsets.all(16),
        color: const Color(FlickoColors.bgSecondary),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.gif_box,
              color: Color(FlickoColors.blurpleLight),
              size: 38,
            ),
            const SizedBox(height: 8),
            Text(
              fileName?.isNotEmpty == true ? fileName! : 'GIF attachment',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(FlickoColors.textPrimary),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to open',
              style: TextStyle(
                color: Color(FlickoColors.textMuted),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGif(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
