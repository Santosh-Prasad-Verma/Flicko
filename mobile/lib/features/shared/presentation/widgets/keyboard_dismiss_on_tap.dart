import 'package:flutter/material.dart';

/// Helper widget to dismiss keyboard on tap anywhere on the screen.
/// Uses [GestureDetector] with [HitTestBehavior.translucent] to capture taps.
class KeyboardDismissOnTap extends StatelessWidget {
  final Widget child;
  
  const KeyboardDismissOnTap({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
