import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/server_model.dart';

class ServerView extends StatelessWidget {
  final ServerModel server;

  const ServerView({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(FlickoColors.bgPrimary),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.tag,
              size: 80,
              color: Color(FlickoColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'No channel selected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a channel to start chatting',
              style: TextStyle(
                color: Color(FlickoColors.textMuted),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
