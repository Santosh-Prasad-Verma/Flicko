import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/core/constants/flicko_colors.dart';

class LoadingSpinner extends StatelessWidget {
  final String? message;
  final bool fullScreen;

  const LoadingSpinner({
    super.key,
    this.message,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: Color(FlickoColors.blurple)),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Container(
        color: const Color(FlickoColors.bgPrimary),
        child: Center(child: content),
      );
    }

    return content;
  }
}
