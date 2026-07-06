import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PillSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onBackPressed;
  final String hintText;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool showSearchIcon;
  final bool showBackArrow;

  const PillSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.onBackPressed,
    this.hintText = 'Search...',
    this.autofocus = false,
    this.focusNode,
    this.showSearchIcon = true,
    this.showBackArrow = true,
  });

  static const Color _barBg = Color(0xFF111116);
  static const Color _brandGreen = Color(0xFF52B788);
  static const Color _textColor = Color(0xFFF4F4F5);
  static const Color _hintColor = Color(0x4DFFFFFF); // white at 0.3
  static const Color _iconColor = Color(0xE6E4E4E7); // 0xFFE4E4E7 at 0.9
  static const Color _clearBg = Color(0x1AFFFFFF); // white at 0.1
  static const Color _clearIcon = Color(0xFFA1A1AA);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _barBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBackArrow) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onBackPressed,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: _iconColor,
                  size: 21,
                ),
              ),
            ),
          ] else
            const SizedBox(width: 16),
          if (showSearchIcon)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.search_rounded,
                color: _brandGreen,
                size: 20,
              ),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              cursorColor: _brandGreen,
              cursorWidth: 2.2,
              cursorHeight: 20,
              style: GoogleFonts.inter(
                color: _textColor,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: _hintColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onClear?.call();
              },
              child: Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: _clearBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: _clearIcon,
                  size: 13,
                ),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
