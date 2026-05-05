import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

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
    final spinner = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(FlickoColors.blurple)),
        ),
        if (message != null) ...[
          const SizedBox(height: FlickoSpacing.md),
          Text(
            message!,
            style: const TextStyle(color: Color(FlickoColors.textSecondary)),
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Scaffold(
        
        body: Center(child: spinner),
      );
    }

    return Center(child: spinner);
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FlickoSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: const Color(FlickoColors.bgTertiary),
            ),
            const SizedBox(height: FlickoSpacing.lg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(FlickoColors.textPrimary),
                  ),
            ),
            const SizedBox(height: FlickoSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(FlickoColors.textMuted),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
