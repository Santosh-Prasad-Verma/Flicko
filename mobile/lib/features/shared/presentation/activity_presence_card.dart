import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Activity Presence Card
/// Renders dynamic "Playing Game" or "Listening to Music" Rich Presence cards.
class ActivityPresenceCard extends StatelessWidget {
  final String activityName;
  final String? details;
  final IconData icon;

  const ActivityPresenceCard({
    super.key,
    required this.activityName,
    this.details,
    this.icon = Icons.sports_esports_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(FlickoColors.brandLime).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.brandLime).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(FlickoColors.brandLime), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activityName,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details != null && details!.isNotEmpty)
                  Text(
                    details!,
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
