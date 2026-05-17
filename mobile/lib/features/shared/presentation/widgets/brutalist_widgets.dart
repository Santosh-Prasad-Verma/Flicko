import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Brutalist-styled icon button with sharp edges and bold aesthetics.
/// Matches the design system used in discover screens.
class BrutalistIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final bool disabled;

  const BrutalistIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
    this.size = 44,
    this.iconSize = 20,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(FlickoColors.bgTertiary);
    final fgColor = iconColor ?? const Color(FlickoColors.textPrimary);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: disabled ? bgColor : const Color(FlickoColors.textPrimary),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: disabled ? const Color(FlickoColors.textMuted) : fgColor,
          size: iconSize,
        ),
      ),
    );
  }
}

/// Brutalist-styled text button with sharp edges.
class BrutalistTextButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final bool disabled;

  const BrutalistTextButton({
    super.key,
    required this.text,
    required this.onTap,
    this.backgroundColor,
    this.textColor,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(FlickoColors.bgTertiary);
    final fgColor = textColor ?? const Color(FlickoColors.textPrimary);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? bgColor.withValues(alpha: 0.5) : bgColor,
          border: Border.all(
            color: disabled ? bgColor : fgColor,
            width: 2,
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.robotoMono(
            color: disabled ? const Color(FlickoColors.textMuted) : fgColor,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Brutalist-styled full-width button with shadow effect.
class BrutalistButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? shadowColor;
  final bool isLoading;
  final bool disabled;
  final IconData? leadingIcon;

  const BrutalistButton({
    super.key,
    required this.text,
    required this.onTap,
    this.backgroundColor,
    this.textColor,
    this.shadowColor,
    this.isLoading = false,
    this.disabled = false,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(FlickoColors.blurple);
    final fgColor = textColor ?? Colors.white;
    final shadow = shadowColor ?? const Color(FlickoColors.textPrimary);

    return GestureDetector(
      onTap: (disabled || isLoading) ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: disabled ? bgColor.withValues(alpha: 0.5) : bgColor,
          border: Border.all(
            color: Colors.black,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: disabled ? Colors.transparent : shadow,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: fgColor,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, color: fgColor, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: GoogleFonts.spaceGrotesk(
                        color: fgColor,
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

/// Legal footer for brutalist-styled screens.
/// Displays app name, terms, privacy links, and copyright.
class BrutalistLegalFooter extends StatelessWidget {
  final bool showLinks;

  const BrutalistLegalFooter({
    super.key,
    this.showLinks = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: const Color(FlickoColors.textMuted).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                'FLICKO.CORE',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              if (showLinks) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLink('TERMS', () {}),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 1,
                      height: 12,
                      color: const Color(FlickoColors.textMuted).withValues(alpha: 0.3),
                    ),
                    _buildLink('PRIVACY', () {}),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 1,
                      height: 12,
                      color: const Color(FlickoColors.textMuted).withValues(alpha: 0.3),
                    ),
                    _buildLink('GUIDELINES', () {}),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                '© ${DateTime.now().year} FLICKO NETWORK',
                style: GoogleFonts.robotoMono(
                  color: const Color(FlickoColors.textMuted).withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: GoogleFonts.robotoMono(
          color: const Color(FlickoColors.textSecondary),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Brutalist-styled card container with shadow.
class BrutalistCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final Color? shadowColor;
  final EdgeInsetsGeometry? padding;
  final bool isPremium;

  const BrutalistCard({
    super.key,
    required this.child,
    this.borderColor,
    this.shadowColor,
    this.padding,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? const Color(FlickoColors.textPrimary);
    final shadow = shadowColor ?? const Color(FlickoColors.blurple);

    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border.all(
          color: isPremium ? const Color(FlickoColors.blurple) : border,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: isPremium ? const Color(FlickoColors.blurple) : shadow.withValues(alpha: 0.3),
            offset: const Offset(6, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Brutalist-styled section header.
class BrutalistSectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final IconData? leadingIcon;

  const BrutalistSectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  color: const Color(FlickoColors.blurple),
                  size: 18,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (actionText != null && onActionTap != null) ...[
          const SizedBox(width: 16),
          BrutalistTextButton(
            text: actionText!,
            onTap: onActionTap!,
          ),
        ],
      ],
    );
  }
}
