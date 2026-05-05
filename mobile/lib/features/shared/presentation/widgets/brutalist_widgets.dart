import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrutalistColors {
  static const Color lime = Color(0xFFCBEF17);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);
}

class BrutalistCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Offset shadowOffset;
  final double borderWidth;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double? width;
  final double? height;

  const BrutalistCard({
    super.key,
    required this.child,
    this.backgroundColor = BrutalistColors.black,
    this.borderColor = BrutalistColors.white,
    this.shadowColor = BrutalistColors.white,
    this.shadowOffset = const Offset(6, 6),
    this.borderWidth = 3.0,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(color: shadowColor, offset: shadowOffset),
        ],
      ),
      child: child,
    );
  }
}

class BrutalistButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final Color? shadowColor;
  final bool isLoading;
  final double? width;
  final EdgeInsets padding;
  final Widget? icon;

  const BrutalistButton({
    super.key,
    required this.text,
    required this.onTap,
    this.color = BrutalistColors.lime,
    this.textColor = BrutalistColors.black,
    this.shadowColor,
    this.isLoading = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(vertical: 20),
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: width ?? double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: BrutalistColors.black, width: 3),
          boxShadow: [
            BoxShadow(
              color: shadowColor ?? (color == BrutalistColors.lime ? BrutalistColors.white : BrutalistColors.lime),
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 3, color: BrutalistColors.black),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      icon!,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class BrutalistIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double size;
  final double padding;

  const BrutalistIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.backgroundColor = BrutalistColors.black,
    this.borderColor = BrutalistColors.white,
    this.shadowColor = BrutalistColors.lime,
    this.size = 20,
    this.padding = 10,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(color: shadowColor, offset: const Offset(3, 3)),
          ],
        ),
        child: Icon(icon, size: size, color: borderColor),
      ),
    );
  }
}

class BrutalistLegalFooter extends StatelessWidget {
  const BrutalistLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(height: 2, color: BrutalistColors.grey),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'END_MANIFEST',
                style: GoogleFonts.robotoMono(
                  color: BrutalistColors.white.withValues(alpha: 0.2),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Container(height: 2, color: BrutalistColors.grey),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'ALL NETWORK DATA IS SUBJECT TO COMMUNITY GUIDELINES. SYSTEM_V4.0.0_STABLE',
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoMono(
            color: BrutalistColors.white.withValues(alpha: 0.3),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
