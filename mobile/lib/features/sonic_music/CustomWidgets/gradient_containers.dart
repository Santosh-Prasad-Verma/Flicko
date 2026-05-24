/*
 *  This file is part of BlackHole (https://github.com/Sangwan5688/BlackHole).
 * 
 * BlackHole is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * BlackHole is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with BlackHole.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * Copyright (c) 2021-2023, Ankit Sangwan
 */

import 'dart:ui';
import 'package:mobile/features/sonic_music/Helpers/config.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class GradientContainer extends StatefulWidget {
  final Widget? child;
  final bool? opacity;
  const GradientContainer({required this.child, this.opacity});
  @override
  _GradientContainerState createState() => _GradientContainerState();
}

class _GradientContainerState extends State<GradientContainer> {
  MyTheme currentTheme = GetIt.I<MyTheme>();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? [
                  const Color(0xFF150B29), // Rich Deep Purple
                  const Color(0xFF07040A), // Black
                  const Color(0xFF07040A), // Black
                ]
              : [
                  const Color(0xfff5f9ff),
                  Colors.white,
                ],
        ),
      ),
      child: widget.child,
    );
  }
}

class BottomGradientContainer extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  const BottomGradientContainer({
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius,
  });
  @override
  _BottomGradientContainerState createState() =>
      _BottomGradientContainerState();
}

class _BottomGradientContainerState extends State<BottomGradientContainer> {
  MyTheme currentTheme = GetIt.I<MyTheme>();
  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? const BorderRadius.all(Radius.circular(15.0));
    return Container(
      margin: widget.margin ?? const EdgeInsets.fromLTRB(25, 0, 25, 25),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: widget.padding ?? const EdgeInsets.fromLTRB(10, 15, 10, 15),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [
                        Colors.black.withOpacity(0.7),
                        const Color(0xFF130924).withOpacity(0.5),
                      ]
                    : [
                        Colors.white.withOpacity(0.85),
                        Colors.white.withOpacity(0.6),
                      ],
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class GradientCard extends StatefulWidget {
  final Widget child;
  final BorderRadius? radius;
  final double? elevation;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final List<Color>? gradientColors;
  final AlignmentGeometry? gradientBegin;
  final AlignmentGeometry? gradientEnd;
  const GradientCard({
    required this.child,
    this.radius,
    this.elevation,
    this.margin,
    this.padding,
    this.gradientColors,
    this.gradientBegin,
    this.gradientEnd,
  });
  @override
  _GradientCardState createState() => _GradientCardState();
}

class _GradientCardState extends State<GradientCard> {
  MyTheme currentTheme = GetIt.I<MyTheme>();
  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.radius ?? BorderRadius.circular(10.0);
    return Card(
      elevation: widget.elevation ?? 3,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      margin: widget.margin ?? EdgeInsets.zero,
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.0,
              ),
              gradient: LinearGradient(
                begin: widget.gradientBegin ?? Alignment.topLeft,
                end: widget.gradientEnd ?? Alignment.bottomRight,
                colors: widget.gradientColors ??
                    (Theme.of(context).brightness == Brightness.dark
                        ? [
                            Colors.white.withOpacity(0.06),
                            Colors.white.withOpacity(0.01),
                          ]
                        : [
                            Colors.white.withOpacity(0.8),
                            Colors.white.withOpacity(0.4),
                          ]),
              ),
            ),
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
