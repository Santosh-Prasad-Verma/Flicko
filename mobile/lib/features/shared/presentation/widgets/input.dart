import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class Input extends StatefulWidget {
  final String? label;
  final String? error;
  final String? hint;
  final bool isPassword;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool enabled;
  final String? accessibilityLabel;
  final String? initialValue;

  const Input({
    super.key,
    this.label,
    this.error,
    this.hint,
    this.isPassword = false,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.accessibilityLabel,
    this.initialValue,
  });

  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  late bool _obscureText;
  late bool _isFocused;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _isFocused = false;
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null && widget.error!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: GoogleFonts.inter(
              color: hasError ? const Color(FlickoColors.danger) : const Color(FlickoColors.textSecondary),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Focus(
          onFocusChange: (focused) {
            setState(() {
              _isFocused = focused;
            });
          },
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: hasError 
                  ? const Color(FlickoColors.danger).withValues(alpha: 0.1)
                  : const Color(0xFF0C0C10).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: hasError
                    ? const Color(FlickoColors.danger)
                    : (_isFocused ? const Color(0xFF52B788) : Colors.white.withValues(alpha: 0.12)),
                width: 1.5,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF52B788).withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    obscureText: _obscureText,
                    enabled: widget.enabled,
                    keyboardType: widget.keyboardType,
                    maxLines: widget.isPassword ? 1 : widget.maxLines,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    cursorColor: const Color(0xFF52B788),
                    cursorWidth: 2.2,
                    cursorHeight: 20.0,
                    cursorRadius: const Radius.circular(1.0),
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onTap: () {
                      setState(() => _isFocused = true);
                    },
                  ),
                ),
              if (widget.isPassword)
                GestureDetector(
                  onTap: _toggleObscureText,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _obscureText ? 'Show' : 'Hide',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.blurple),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.error!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.danger),
              fontSize: 12,
            ),
          ),
        ] else if (widget.hint != null && !hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.hint!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
