import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

enum ButtonVariant { primary, secondary, danger, ghost }

enum ButtonSize { sm, md, lg }

class Button extends StatefulWidget {
  final String title;
  final VoidCallback onPress;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool disabled;
  final bool loading;
  final bool fullWidth;
  final String? accessibilityLabel;
  final String? accessibilityHint;

  const Button({
    super.key,
    required this.title,
    required this.onPress,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.disabled = false,
    this.loading = false,
    this.fullWidth = false,
    this.accessibilityLabel,
    this.accessibilityHint,
  });

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    if (!widget.disabled && !widget.loading) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handlePressUp() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _handleTap() {
    if (!widget.disabled && !widget.loading) {
      widget.onPress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.loading;

    return GestureDetector(
      onTapDown: (_) => _handlePressDown(),
      onTapUp: (_) => _handlePressUp(),
      onTapCancel: _handlePressUp,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Semantics(
              button: true,
              label: widget.accessibilityLabel ?? widget.title,
              hint: widget.accessibilityHint,
              enabled: !isDisabled,
              excludeSemantics: true,
              child: Container(
                width: widget.fullWidth ? double.infinity : null,
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: _getPadding(),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.loading) ...[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          color: widget.variant == ButtonVariant.ghost
                              ? const Color(FlickoColors.blurple)
                              : Colors.white,
                          fontSize: _getFontSize(),
                          fontWeight: _getFontWeight(),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.disabled || widget.loading) {
      return _getVariantColor().withValues(alpha: 0.5);
    }
    return _getVariantColor();
  }

  Color _getVariantColor() {
    switch (widget.variant) {
      case ButtonVariant.primary:
        return const Color(FlickoColors.blurple);
      case ButtonVariant.secondary:
        return const Color(FlickoColors.bgTertiary);
      case ButtonVariant.danger:
        return const Color(FlickoColors.danger);
      case ButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case ButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case ButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case ButtonSize.sm:
        return 14;
      case ButtonSize.md:
        return 16;
      case ButtonSize.lg:
        return 16;
    }
  }

  FontWeight _getFontWeight() {
    switch (widget.size) {
      case ButtonSize.sm:
        return FontWeight.w600;
      case ButtonSize.md:
        return FontWeight.w600;
      case ButtonSize.lg:
        return FontWeight.bold;
    }
  }
}
