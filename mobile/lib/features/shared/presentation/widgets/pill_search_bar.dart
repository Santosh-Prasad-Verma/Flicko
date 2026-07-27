import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

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
    this.hintText = 'Search messages or friends...',
    this.autofocus = false,
    this.focusNode,
    this.showSearchIcon = true,
    this.showBackArrow = true,
  });

  static const Color _brandGreen = Color(FlickoColors.brandLime);
  static const Color _bgSecondary = Color(FlickoColors.bgSecondary);
  static const Color _border = Color(FlickoColors.border);

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode?.hasFocus ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFocused ? _brandGreen : _border,
          width: isFocused ? 1.5 : 1.0,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _brandGreen.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (showBackArrow) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onBackPressed,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white70,
                  size: 20,
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
                color: isFocused ? _brandGreen : Colors.white54,
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
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: Colors.white38,
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
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
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
