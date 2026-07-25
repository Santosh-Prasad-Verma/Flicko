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

  static const Color _brandGreen = Color(0xFF52B788);
  static const Color _textColor = Color(0xFFF4F4F5);
  static const Color _iconColor = Color(0xE6E4E4E7); // 0xFFE4E4E7 at 0.9
  static const Color _clearBg = Color(0x1AFFFFFF); // white at 0.1
  static const Color _clearIcon = Color(0xFFA1A1AA);

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode?.hasFocus ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF14141A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFocused
              ? _brandGreen.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: isFocused ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? _brandGreen.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: isFocused ? 16 : 10,
            spreadRadius: isFocused ? 1 : 0,
            offset: const Offset(0, 3),
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
            const SizedBox(width: 14),
          if (showSearchIcon)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.search_rounded,
                color: isFocused ? _brandGreen : _brandGreen.withValues(alpha: 0.7),
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
              cursorWidth: 2.0,
              cursorHeight: 18,
              style: GoogleFonts.outfit(
                color: _textColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox(width: 14);
              return GestureDetector(
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
              );
            },
          ),
        ],
      ),
    );
  }
}
