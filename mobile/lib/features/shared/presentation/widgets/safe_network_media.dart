import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          width: width ?? 300,
          height: height ?? 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: width ?? 300,
            height: height ?? 200,
            color: const Color(FlickoColors.bgSecondary),
            child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => Container(
            width: width ?? 300,
            height: height ?? 200,
            color: const Color(FlickoColors.bgSecondary),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gif_box_rounded,
                    color: Color(FlickoColors.textMuted), size: 38),
                SizedBox(height: 8),
                Text('Failed to load GIF',
                    style: TextStyle(
                        color: Color(FlickoColors.textMuted), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            fileName ?? 'GIF',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
              errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
