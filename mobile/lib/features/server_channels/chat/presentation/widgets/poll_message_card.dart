import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/flicko_message.dart';

class PollMessageCard extends StatefulWidget {
  final FlickoMessage message;

  const PollMessageCard({super.key, required this.message});

  @override
  State<PollMessageCard> createState() => _PollMessageCardState();
}

class _PollMessageCardState extends State<PollMessageCard> {
  late Map<String, dynamic> _pollData;
  late List<dynamic> _options;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  @override
  void didUpdateWidget(covariant PollMessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.content != oldWidget.message.content) {
      _parseData();
    }
  }

  void _parseData() {
    try {
      _pollData = jsonDecode(widget.message.content);
      _options = _pollData['options'] as List<dynamic>? ?? [];
    } catch (e) {
      _pollData = {'question': 'Invalid Poll', 'endTime': ''};
      _options = [];
    }
  }

  bool _hasVoted(int index) {
    final option = Map<String, dynamic>.from(_options[index] as Map);
    final voters = option['voters'] as List<dynamic>? ?? [];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return voters.contains(userId);
  }

  Future<void> _handleVote(int index) async {
    if (_isVoting) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final endTimeStr = _pollData['endTime'] as String?;
    if (endTimeStr != null && endTimeStr.isNotEmpty) {
      final endTime = DateTime.tryParse(endTimeStr);
      if (endTime != null && DateTime.now().toUtc().isAfter(endTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This poll has ended.')),
        );
        return;
      }
    }

    setState(() => _isVoting = true);
    HapticFeedback.lightImpact();

    try {
      final multiSelect = _pollData['multiSelect'] == true;
      final newOptions = List<Map<String, dynamic>>.from(_options);

      // Deep copy each option to avoid reference mutations before saving
      for (int i = 0; i < newOptions.length; i++) {
        newOptions[i] = Map<String, dynamic>.from(newOptions[i]);
      }

      if (!multiSelect) {
        // Remove vote from all other options
        for (var opt in newOptions) {
          final voters = List<String>.from(opt['voters'] ?? []);
          voters.remove(userId);
          opt['voters'] = voters;
          opt['votes'] = voters.length;
        }
      }

      final targetOption = newOptions[index];
      final voters = List<String>.from(targetOption['voters'] ?? []);
      
      if (voters.contains(userId)) {
        voters.remove(userId);
      } else {
        voters.add(userId);
      }
      
      targetOption['voters'] = voters;
      targetOption['votes'] = voters.length;

      final newPollData = Map<String, dynamic>.from(_pollData);
      newPollData['options'] = newOptions;

      await Supabase.instance.client.rpc('vote_in_poll', params: {
        'message_uuid': widget.message.id,
        'new_content': jsonEncode(newPollData),
      });
          
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error voting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_options.isEmpty) {
      return Text('Invalid poll format', style: GoogleFonts.inter(color: const Color(FlickoColors.red)));
    }

    final question = _pollData['question'] as String? ?? 'Poll';
    
    // To calculate percentages accurately.
    int totalOverallVotes = _options.fold(0, (sum, opt) => sum + (Map<String, dynamic>.from(opt as Map)['votes'] as int? ?? 0));

    // Check if ended
    bool hasEnded = false;
    final endTimeStr = _pollData['endTime'] as String?;
    if (endTimeStr != null && endTimeStr.isNotEmpty) {
      final endTime = DateTime.tryParse(endTimeStr);
      if (endTime != null && DateTime.now().toUtc().isAfter(endTime)) {
        hasEnded = true;
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E0D).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(FlickoColors.brandLime).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(FlickoColors.brandLime).withOpacity(0.04),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, color: Color(FlickoColors.brandLime), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = Map<String, dynamic>.from(entry.value as Map);
            final text = opt['text'] as String?;
            final votes = opt['votes'] as int? ?? 0;
            final hasVoted = _hasVoted(idx);
            final percentage = totalOverallVotes > 0 ? (votes / totalOverallVotes) : 0.0;

            return GestureDetector(
              onTap: () => _handleVote(idx),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                height: 44,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF161917),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasVoted
                              ? const Color(FlickoColors.brandLime).withOpacity(0.4)
                              : const Color(FlickoColors.border).withOpacity(0.3),
                          width: 1.2,
                        ),
                      ),
                    ),
                    // Progress
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: hasVoted
                                  ? [
                                      const Color(FlickoColors.brandLime).withOpacity(0.35),
                                      const Color(FlickoColors.brandLime).withOpacity(0.12),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.08),
                                      Colors.white.withOpacity(0.04),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          if (hasVoted) ...[
                            const Icon(Icons.check_circle_rounded, size: 16, color: Color(FlickoColors.brandLime)),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              text ?? 'Option',
                              style: GoogleFonts.inter(
                                color: hasVoted
                                    ? const Color(FlickoColors.brandLime)
                                    : const Color(FlickoColors.textPrimary),
                                fontSize: 13.5,
                                fontWeight: hasVoted ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              color: hasVoted
                                  ? const Color(FlickoColors.brandLime)
                                  : const Color(FlickoColors.textSecondary),
                              fontSize: 13.5,
                              fontWeight: hasVoted ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.brandLime).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalOverallVotes votes',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.brandLime),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (hasEnded) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.danger).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ended',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(FlickoColors.danger),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
