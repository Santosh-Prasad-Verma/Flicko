import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable full-pill search bar matching the custom theme requested:
/// - Smooth rounded stadium pill container (BorderRadius circular 28)
/// - Integrated left back arrow INSIDE the search box
/// - Teal cursor indicator (Color 0xFF52B788)
/// - Subtle translucent background & border matching app theme
class PillSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onBackPressed;
  final String hintText;
  final bool autofocus;
  final FocusNode? focusNode;

  static const Color brandTeal = Color(0xFF52B788);

  const PillSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onClear,
    this.onBackPressed,
    this.hintText = 'Search...',
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF141419).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back arrow inside the pill box
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBackPressed ?? () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.arrow_back_rounded,
                color: const Color(0xFFE4E4E7).withValues(alpha: 0.9),
                size: 21,
              ),
            ),
          ),
          // Text Input Field with vibrant teal cursor
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              cursorColor: brandTeal,
              cursorWidth: 2.2,
              cursorHeight: 20.0,
              cursorRadius: const Radius.circular(1.0),
              style: GoogleFonts.inter(
                color: const Color(0xFFF4F4F5),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // Clear button X when typing
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                controller.clear();
                if (onClear != null) {
                  onClear!();
                } else if (onChanged != null) {
                  onChanged!('');
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 14),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFA1A1AA),
                    size: 13,
                  ),
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
