import 'dart:ui';

import 'package:flutter/material.dart';

/// A simple frosted-glass surface used across the app.
/// Wraps content in a [BackdropFilter] blur with a translucent fill
/// and a subtle hairline border so the layer behind shows through.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? tint;
  final double tintAlpha;
  final Color? borderColor;
  final double borderAlpha;
  final BoxConstraints? constraints;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blurSigma = 18,
    this.tint,
    this.tintAlpha = 0.08,
    this.borderColor,
    this.borderAlpha = 0.10,
    this.constraints,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = (tint ?? Colors.white).withValues(alpha: tintAlpha);
    final stroke = (borderColor ?? Colors.white).withValues(alpha: borderAlpha);

    Widget inner = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          constraints: constraints,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: stroke, width: 1),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      inner = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: inner,
        ),
      );
    }

    if (margin != null) {
      inner = Padding(padding: margin!, child: inner);
    }

    return inner;
  }
}
