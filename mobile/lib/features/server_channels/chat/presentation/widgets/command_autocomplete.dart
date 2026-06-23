import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class CommandDefinition {
  final String name;
  final String description;
  final String botName;
  final List<dynamic> options;

  CommandDefinition({
    required this.name,
    required this.description,
    required this.botName,
    this.options = const [],
  });

  factory CommandDefinition.fromJson(Map<String, dynamic> json) {
    return CommandDefinition(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      botName: json['bot_name'] ?? '',
      options: json['options'] ?? [],
    );
  }
}

class CommandAutocomplete extends StatelessWidget {
  final List<CommandDefinition> commands;
  final String query;
  final Function(CommandDefinition command) onSelect;
  final VoidCallback onDismiss;

  const CommandAutocomplete({
    super.key,
    required this.commands,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
  });

  List<CommandDefinition> get _filteredCommands {
    if (query.isEmpty) return commands.take(10).toList();
    final lowerQuery = query.toLowerCase();
    return commands.where((cmd) {
      return cmd.name.toLowerCase().contains(lowerQuery) ||
             cmd.description.toLowerCase().contains(lowerQuery);
    }).take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCommands;

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgFloating),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(FlickoColors.bgTertiary),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Slash Commands',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(FlickoColors.textMuted),
                  ),
                ),
              ],
            ),
          ),

          // Command list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final cmd = filtered[index];
                return _buildCommandItem(cmd);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandItem(CommandDefinition cmd) {
    return GestureDetector(
      onTap: () => onSelect(cmd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(FlickoColors.bgTertiary).withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.blurple).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '/',
                style: TextStyle(
                  color: Color(FlickoColors.blurple),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '/${cmd.name}',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cmd.description,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
