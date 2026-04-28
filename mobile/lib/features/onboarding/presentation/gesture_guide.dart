import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Gesture data model
class _GestureItem {
  final IconData icon;
  final String gesture;
  final String description;
  final _GestureAnimation animation;

  const _GestureItem({
    required this.icon,
    required this.gesture,
    required this.description,
    required this.animation,
  });
}

enum _GestureAnimation {
  swipeRight,
  swipeLeft,
  longPress,
  doubleTap,
  pinch,
  swipeDown,
}

const _kGestureGuideKey = 'flicko_gesture_guide_seen';

/// All gesture items
const _gestures = [
  _GestureItem(
    icon: Icons.arrow_forward,
    gesture: 'Swipe Right',
    description: 'Open the channel list and server sidebar',
    animation: _GestureAnimation.swipeRight,
  ),
  _GestureItem(
    icon: Icons.arrow_back,
    gesture: 'Swipe Left',
    description: 'Open the member list',
    animation: _GestureAnimation.swipeLeft,
  ),
  _GestureItem(
    icon: Icons.fingerprint,
    gesture: 'Long Press Message',
    description: 'Open message actions (reply, edit, delete, react)',
    animation: _GestureAnimation.longPress,
  ),
  _GestureItem(
    icon: Icons.touch_app,
    gesture: 'Double Tap Message',
    description: 'Quick-react with your default emoji',
    animation: _GestureAnimation.doubleTap,
  ),
  _GestureItem(
    icon: Icons.zoom_out_map,
    gesture: 'Pinch on Media',
    description: 'Zoom in on images and videos',
    animation: _GestureAnimation.pinch,
  ),
  _GestureItem(
    icon: Icons.keyboard_arrow_down,
    gesture: 'Swipe Down',
    description: 'Dismiss modals and overlays',
    animation: _GestureAnimation.swipeDown,
  ),
];

/// Gesture Guide Overlay
///
/// First-time onboarding overlay showing available gestures with animated
/// finger-dot demonstrations. Page-based with dots navigation.
/// Matches `mobile/components/onboarding/GestureGuide.tsx`.
class GestureGuide extends StatefulWidget {
  /// Force show even if already seen
  final bool forceShow;
  final VoidCallback? onDismiss;

  const GestureGuide({
    super.key,
    this.forceShow = false,
    this.onDismiss,
  });

  /// Reset the "seen" flag so guide shows again
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kGestureGuideKey);
  }

  /// Show as a dialog overlay
  static Future<void> show(BuildContext context, {bool forceShow = true}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: false,
      builder: (_) => GestureGuide(forceShow: forceShow),
    );
  }

  @override
  State<GestureGuide> createState() => _GestureGuideState();
}

class _GestureGuideState extends State<GestureGuide> {
  int _page = 0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    if (widget.forceShow) {
      setState(() => _visible = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kGestureGuideKey) ?? false;
    if (!seen && mounted) {
      setState(() => _visible = true);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGestureGuideKey, true);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onDismiss?.call();
    }
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page < _gestures.length - 1) {
      setState(() => _page++);
    } else {
      _dismiss();
    }
  }

  void _prev() {
    if (_page > 0) {
      HapticFeedback.selectionClick();
      setState(() => _page--);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final gesture = _gestures[_page];
    final isLast = _page == _gestures.length - 1;

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(_page),
          width: MediaQuery.of(context).size.width - 48,
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgFloating),
            borderRadius: BorderRadius.circular(FlickoRadius.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Gesture visual
                SizedBox(
                  height: 100,
                  width: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(gesture.icon, size: 40,
                          color: const Color(FlickoColors.blurple)),
                      Positioned(
                        bottom: 0,
                        child: _GestureAnimatedDot(
                            animation: gesture.animation),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FlickoSpacing.md),

                // Title
                Text(
                  gesture.gesture,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: FlickoSpacing.sm),

                // Description
                Text(
                  gesture.description,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textSecondary),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: FlickoSpacing.xl),

                // Page dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_gestures.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: active ? 20 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(FlickoColors.blurple)
                            : const Color(FlickoColors.textMuted)
                                .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: FlickoSpacing.xl),

                // Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_page > 0)
                      GestureDetector(
                        onTap: _prev,
                        child: Row(
                          children: [
                            const Icon(Icons.chevron_left,
                                size: 20,
                                color: Color(FlickoColors.textSecondary)),
                            Text(
                              'Back',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textSecondary),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(FlickoColors.blurple),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FlickoSpacing.xl,
                          vertical: FlickoSpacing.sm + 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(FlickoRadius.md),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLast ? 'Got it!' : 'Next',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right,
                                size: 20, color: Colors.white),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated finger dot that demonstrates different gestures
class _GestureAnimatedDot extends StatefulWidget {
  final _GestureAnimation animation;

  const _GestureAnimatedDot({required this.animation});

  @override
  State<_GestureAnimatedDot> createState() => _GestureAnimatedDotState();
}

class _GestureAnimatedDotState extends State<_GestureAnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _setupAnimation();
  }

  void _setupAnimation() {
    switch (widget.animation) {
      case _GestureAnimation.swipeRight:
        _offsetAnimation = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(16, 0),
        ).animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeInOut));
        _scaleAnimation = AlwaysStoppedAnimation(1.0);
        break;
      case _GestureAnimation.swipeLeft:
        _offsetAnimation = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-16, 0),
        ).animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeInOut));
        _scaleAnimation = AlwaysStoppedAnimation(1.0);
        break;
      case _GestureAnimation.swipeDown:
        _offsetAnimation = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, 10),
        ).animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeInOut));
        _scaleAnimation = AlwaysStoppedAnimation(1.0);
        break;
      case _GestureAnimation.longPress:
        _offsetAnimation = AlwaysStoppedAnimation(Offset.zero);
        _scaleAnimation = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.85), weight: 40),
          TweenSequenceItem(
              tween: ConstantTween(0.85), weight: 30),
          TweenSequenceItem(
              tween: Tween(begin: 0.85, end: 1.0), weight: 30),
        ]).animate(_controller);
        break;
      case _GestureAnimation.doubleTap:
        _offsetAnimation = AlwaysStoppedAnimation(Offset.zero);
        _scaleAnimation = TweenSequence<double>([
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.8), weight: 12),
          TweenSequenceItem(
              tween: Tween(begin: 0.8, end: 1.0), weight: 12),
          TweenSequenceItem(
              tween: ConstantTween(1.0), weight: 8),
          TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.8), weight: 12),
          TweenSequenceItem(
              tween: Tween(begin: 0.8, end: 1.0), weight: 12),
          TweenSequenceItem(
              tween: ConstantTween(1.0), weight: 44),
        ]).animate(_controller);
        break;
      case _GestureAnimation.pinch:
        _offsetAnimation = AlwaysStoppedAnimation(Offset.zero);
        _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _offsetAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.blurple).withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(FlickoColors.blurple),
                  width: 2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
