import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Message Component Renderer
/// Renders Rich Embeds & Interactive Action Row Components (Buttons & Dropdowns) inside chat messages.
class MessageComponentRenderer extends StatelessWidget {
  final List<dynamic>? embeds;
  final List<dynamic>? components;
  final Function(String customId)? onComponentPressed;

  const MessageComponentRenderer({
    super.key,
    this.embeds,
    this.components,
    this.onComponentPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasEmbeds = embeds != null && embeds!.isNotEmpty;
    final hasComponents = components != null && components!.isNotEmpty;

    if (!hasEmbeds && !hasComponents) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Embed Cards
        if (hasEmbeds)
          ...embeds!.map((e) {
            final map = e as Map<String, dynamic>;
            final colorHex = map['color'] as String? ?? '#7C3AED';
            Color sideColor = const Color(FlickoColors.brandLime);
            try {
              sideColor = Color(int.parse(colorHex.replaceFirst('#', '0xff')));
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(top: 6, bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: sideColor, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (map['author'] != null && (map['author'] as String).isNotEmpty)
                    Text(map['author'] as String, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  if (map['title'] != null && (map['title'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(map['title'] as String, style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                  if (map['description'] != null && (map['description'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(map['description'] as String, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                  ],
                  if (map['footer'] != null && (map['footer'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(map['footer'] as String, style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                  ],
                ],
              ),
            );
          }),

        // Interactive Action Row Buttons
        if (hasComponents)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: components!.map((c) {
                final btn = c as Map<String, dynamic>;
                final label = btn['label'] as String? ?? 'Action';
                final customId = btn['custom_id'] as String? ?? 'action_btn';

                return ElevatedButton(
                  onPressed: () => onComponentPressed?.call(customId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.bgTertiary),
                    foregroundColor: const Color(FlickoColors.brandLime),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
