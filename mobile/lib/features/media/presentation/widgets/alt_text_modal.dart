import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Alt Text Modal
///
/// Shown before sending an image so users can add alt text descriptions
/// for accessibility. Also includes an ALT badge for images that have descriptions.
/// Matches `mobile/components/media/AltTextModal.tsx`.
class AltTextModal extends StatefulWidget {
  final String imageUri;
  final String? initialAltText;
  final ValueChanged<String> onSave;

  const AltTextModal({
    super.key,
    required this.imageUri,
    required this.onSave,
    this.initialAltText,
  });

  /// Convenience method to show as a bottom sheet
  static Future<String?> show(
    BuildContext context, {
    required String imageUri,
    String? initialAltText,
  }) async {
    String? result;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AltTextModal(
        imageUri: imageUri,
        initialAltText: initialAltText,
        onSave: (text) {
          result = text;
          Navigator.of(context).pop();
        },
      ),
    );
    return result;
  }

  @override
  State<AltTextModal> createState() => _AltTextModalState();
}

class _AltTextModalState extends State<AltTextModal> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAltText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    HapticFeedback.lightImpact();
    widget.onSave(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(FlickoSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.textMuted).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: FlickoSpacing.lg),

              // Title
              Text(
                'Add Description',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: FlickoSpacing.xs),
              Text(
                'Describe this image for people who use screen readers.',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: FlickoSpacing.md),

              // Image preview
              ClipRRect(
                borderRadius: BorderRadius.circular(FlickoRadius.lg),
                child: Image.network(
                  widget.imageUri,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: double.infinity,
                    height: 160,
                    color: const Color(FlickoColors.bgTertiary),
                    child: const Center(
                      child: Icon(Icons.broken_image,
                          color: Color(FlickoColors.textMuted), size: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FlickoSpacing.md),

              // Text field
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 1000,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 15,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe this image...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: const Color(FlickoColors.bgTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FlickoRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(FlickoSpacing.md),
                  counterStyle: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: FlickoSpacing.md),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.bgTertiary),
                      padding: const EdgeInsets.symmetric(
                        horizontal: FlickoSpacing.xl,
                        vertical: FlickoSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FlickoRadius.md),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: FlickoSpacing.sm),
                  ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.blurple),
                      padding: const EdgeInsets.symmetric(
                        horizontal: FlickoSpacing.xl,
                        vertical: FlickoSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FlickoRadius.md),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ALT badge shown on images that have alt text.
/// Positioned at bottom-left of the image container.
class AltBadge extends StatelessWidget {
  final String altText;
  final VoidCallback? onTap;

  const AltBadge({
    super.key,
    required this.altText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (altText.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 8,
      left: 8,
      child: GestureDetector(
        onTap: onTap ??
            () {
              // Show alt text in a snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    altText,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  ),
                  backgroundColor: const Color(FlickoColors.bgSecondary),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FlickoRadius.md),
                  ),
                ),
              );
            },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgPrimary).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(FlickoRadius.sm),
          ),
          child: Text(
            'ALT',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
