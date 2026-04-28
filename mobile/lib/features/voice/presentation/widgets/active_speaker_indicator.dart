import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';

class ActiveSpeakerIndicator extends ConsumerWidget {
  final String participantSid;
  final Widget child;

  const ActiveSpeakerIndicator({
    super.key,
    required this.participantSid,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSpeaking = ref.watch(voiceControllerProvider.select(
      (state) => state.speakingParticipants.contains(participantSid),
    ));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSpeaking 
            ? const Color(FlickoColors.green) 
            : Colors.transparent,
          width: 2,
        ),
      ),
      child: child,
    );
  }
}
