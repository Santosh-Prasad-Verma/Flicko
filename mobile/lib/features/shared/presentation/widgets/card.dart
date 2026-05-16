import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

enum CardElevation { none, subtle, medium, heavy }

class Card extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPress;
  final CardElevation elevation;
  final String? accessibilityLabel;
  final EdgeInsetsGeometry? margin;

  const Card({
    super.key,
    required this.child,
    this.onPress,
    this.elevation = CardElevation.subtle,
    this.accessibilityLabel,
    this.margin,
  });

  @override
  State<Card> createState() => _CardState();
}

class _CardState extends State<Card> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    if (widget.onPress != null) {
      _controller.forward();
    }
  }

  void _handlePressUp() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final hasShadow = widget.elevation != CardElevation.none;
    final shadow = _getShadow();

    final cardContent = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(FlickoColors.border)),
        boxShadow: hasShadow ? [shadow] : [],
      ),
      padding: const EdgeInsets.all(16),
      child: widget.child,
    );

    if (widget.onPress == null) {
      return Semantics(
        label: widget.accessibilityLabel,
        child: cardContent,
      );
    }

    return GestureDetector(
      onTapDown: (_) => _handlePressDown(),
      onTapUp: (_) => _handlePressUp(),
      onTapCancel: _handlePressUp,
      onTap: widget.onPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Semantics(
              button: true,
              label: widget.accessibilityLabel,
              child: cardContent,
            ),
          );
        },
      ),
    );
  }

  BoxShadow _getShadow() {
    switch (widget.elevation) {
      case CardElevation.none:
        return const BoxShadow(color: Colors.transparent);
      case CardElevation.subtle:
        return BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        );
      case CardElevation.medium:
        return BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        );
      case CardElevation.heavy:
        return BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 16,
          offset: const Offset(0, 8),
        );
    }
  }
}
