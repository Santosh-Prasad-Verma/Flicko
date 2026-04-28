import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class Modal extends StatefulWidget {
  final bool visible;
  final VoidCallback onClose;
  final String? title;
  final Widget child;
  final bool dismissible;

  const Modal({
    super.key,
    required this.visible,
    required this.onClose,
    this.title,
    required this.child,
    this.dismissible = true,
  });

  @override
  State<Modal> createState() => _ModalState();
}

class _ModalState extends State<Modal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(Modal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _controller.forward();
    } else if (!widget.visible && oldWidget.visible) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleClose() {
    if (widget.dismissible) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: GestureDetector(
            onTap: _handleClose,
            child: Container(
              color: Colors.black.withValues(alpha: _fadeAnimation.value),
              child: GestureDetector(
                onTap: () {},
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value * MediaQuery.of(context).size.height),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgSecondary),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border.all(color: const Color(FlickoColors.border)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onVerticalDragEnd: (details) {
                              if (details.primaryVelocity != null &&
                                  details.primaryVelocity! > 500 &&
                                  widget.dismissible) {
                                widget.onClose();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(FlickoColors.textMuted).withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          if (widget.title != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title!,
                                      style: GoogleFonts.inter(
                                        color: const Color(FlickoColors.textPrimary),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _handleClose,
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '✕',
                                        style: GoogleFonts.inter(
                                          color: const Color(FlickoColors.textSecondary),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: widget.child,
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).padding.bottom),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
