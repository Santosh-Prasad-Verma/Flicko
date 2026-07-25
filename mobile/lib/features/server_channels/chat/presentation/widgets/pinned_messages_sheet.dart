import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/flicko_message.dart';

class PinnedMessagesSheet extends StatelessWidget {
  final List<FlickoMessage> pinnedMessages;
  final Function(FlickoMessage message)? onJumpToMessage;
  final Function(FlickoMessage message)? onUnpinMessage;
  final bool isLoading;

  const PinnedMessagesSheet({
    super.key,
    required this.pinnedMessages,
    this.onJumpToMessage,
    this.onUnpinMessage,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.push_pin_rounded,
                    color: Color(FlickoColors.brandLime),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Pinned Messages',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pinnedMessages.length}',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.brandLime),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Color(FlickoColors.bgTertiary), height: 1),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)),
              )
            else if (pinnedMessages.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.push_pin_outlined,
                      size: 48,
                      color: Color(FlickoColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Pinned Messages',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Long press any message and select "Pin Message" to pin it here.',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: pinnedMessages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final message = pinnedMessages[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgTertiary),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                message.author?.displayName ?? message.author?.username ?? 'User',
                                style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.brandLime),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(message.createdAt),
                                style: GoogleFonts.inter(
                                  color: const Color(FlickoColors.textMuted),
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              if (onUnpinMessage != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.push_pin_rounded,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Unpin Message',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    onUnpinMessage!(message);
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message.content,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          if (onJumpToMessage != null) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  onJumpToMessage!(message);
                                },
                                child: Text(
                                  'Jump to message →',
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.blurple),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
