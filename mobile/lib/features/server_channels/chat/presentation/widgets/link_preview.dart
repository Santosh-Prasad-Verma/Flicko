import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Link Preview Widget
///
/// Shows rich preview for URLs shared in messages.
/// Mirrors the React Native LinkPreview component.
class LinkPreview extends StatelessWidget {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  const LinkPreview({
    super.key,
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  /// Extracts preview data from a URL (placeholder for actual implementation)
  /// In production, this would use a link preview service or Open Graph scraping
  static Future<LinkPreviewData> fetchPreview(String url) async {
    // Placeholder implementation
    // In production, use a service like:
    // - LinkPreview API
    // - OpenGraph.io
    // - Microlink
    // - Or backend scraping
    
    return LinkPreviewData(
      url: url,
      title: null,
      description: null,
      imageUrl: null,
      siteName: _extractDomain(url),
    );
  }

  static String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = title != null || description != null || imageUrl != null;
    
    if (!hasPreview) {
      return _buildSimpleLink();
    }

    return GestureDetector(
      onTap: () => _openUrl(),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(FlickoColors.bgTertiary),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: double.infinity,
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 150,
                    color: const Color(FlickoColors.bgTertiary),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 150,
                    color: const Color(FlickoColors.bgTertiary),
                    child: const Icon(
                      Icons.link,
                      color: Color(FlickoColors.textMuted),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
            
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Site name
                  if (siteName != null)
                    Text(
                      siteName!.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  
                  // Title
                  if (title != null) ...[
                    if (siteName != null) const SizedBox(height: 4),
                    Text(
                      title!,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  // Description
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 12,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  // URL
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.link,
                        size: 14,
                        color: Color(FlickoColors.blurple),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          url,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.blurple),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleLink() {
    return GestureDetector(
      onTap: () => _openUrl(),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.link,
              size: 14,
              color: Color(FlickoColors.blurple),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                url,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.blurple),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Data class for link preview information
class LinkPreviewData {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });
}

/// Link Preview Card - Used for invite links, etc.
class InviteLinkPreview extends StatelessWidget {
  final String serverName;
  final String? serverIcon;
  final int? memberCount;
  final VoidCallback onJoin;

  const InviteLinkPreview({
    super.key,
    required this.serverName,
    this.serverIcon,
    this.memberCount,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(FlickoColors.blurple),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Server icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.blurple),
                borderRadius: BorderRadius.circular(12),
              ),
              child: serverIcon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: serverIcon!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        serverName.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            
            // Server info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INVITE TO SERVER',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    serverName,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (memberCount != null)
                    Text(
                      '$memberCount members',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            
            // Join button
            ElevatedButton(
              onPressed: onJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.success),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                'Join',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
