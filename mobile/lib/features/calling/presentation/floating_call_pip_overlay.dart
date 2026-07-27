import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Floating Active Call / Voice PIP Overlay (Draggable avatar card)
/// Displays when user minimizes the call screen to navigate elsewhere in the app.
class FloatingCallPipOverlay extends StatefulWidget {
  final String userName;
  final String? avatarUrl;
  final bool isSpeaking;
  final VoidCallback? onTapExpand;
  final VoidCallback? onClose;

  const FloatingCallPipOverlay({
    super.key,
    required this.userName,
    this.avatarUrl,
    this.isSpeaking = true,
    this.onTapExpand,
    this.onClose,
  });

  /// Static helper to show PIP overlay via Flutter Navigator/Overlay
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String userName,
    String? avatarUrl,
    bool isSpeaking = true,
    required VoidCallback onTapExpand,
    VoidCallback? onClose,
  }) {
    hide();
    final overlayState = Overlay.of(context, rootOverlay: true);
    _currentEntry = OverlayEntry(
      builder: (context) => FloatingCallPipOverlay(
        userName: userName,
        avatarUrl: avatarUrl,
        isSpeaking: isSpeaking,
        onTapExpand: () {
          hide();
          onTapExpand();
        },
        onClose: () {
          hide();
          onClose?.call();
        },
      ),
    );
    overlayState.insert(_currentEntry!);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  @override
  State<FloatingCallPipOverlay> createState() => _FloatingCallPipOverlayState();
}

class _FloatingCallPipOverlayState extends State<FloatingCallPipOverlay> {
  Offset _position = const Offset(240, 120);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const accentBlurple = Color(FlickoColors.blurple);
    const bgCard = Color(FlickoColors.bgSecondary);
    const voiceGreen = Color(0xFF43B581);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(10.0, size.width - 140.0),
              (_position.dy + details.delta.dy).clamp(40.0, size.height - 180.0),
            );
          });
        },
        onTap: widget.onTapExpand,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centered avatar circle with glowing speaking ring
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isSpeaking ? voiceGreen : Colors.transparent,
                      width: 3.5,
                    ),
                    boxShadow: widget.isSpeaking
                        ? [
                            BoxShadow(
                              color: voiceGreen.withValues(alpha: 0.4),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(FlickoColors.bgSecondary),
                    backgroundImage: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty && widget.avatarUrl!.startsWith('http'))
                        ? NetworkImage(widget.avatarUrl!)
                        : null,
                    child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty || !widget.avatarUrl!.startsWith('http'))
                        ? const Icon(Icons.face_rounded, size: 38, color: Colors.white70)
                        : null,
                  ),
                ),

                // Active speaking indicator dot (bottom of avatar)
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: voiceGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.userName.length > 8
                              ? '${widget.userName.substring(0, 7)}...'
                              : widget.userName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Close / Dismiss button (top right)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
