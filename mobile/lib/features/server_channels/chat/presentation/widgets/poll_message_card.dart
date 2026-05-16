import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/constants/flicko_colors.dart';
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
    final option = _options[index] as Map<String, dynamic>;
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

      await Supabase.instance.client
          .from('messages')
          .update({'content': jsonEncode(newPollData)})
          .eq('id', widget.message.id);
          
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
    int totalOverallVotes = _options.fold(0, (sum, opt) => sum + ((opt as Map)['votes'] as int? ?? 0));

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(FlickoColors.bgTertiary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll, color: Color(FlickoColors.blurple), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value as Map<String, dynamic>;
            final text = opt['text'] as String?;
            final votes = opt['votes'] as int? ?? 0;
            final hasVoted = _hasVoted(idx);
            final percentage = totalOverallVotes > 0 ? (votes / totalOverallVotes) : 0.0;

            return GestureDetector(
              onTap: () => _handleVote(idx),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 40,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgTertiary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    // Progress
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: hasVoted 
                                ? const Color(FlickoColors.blurple).withValues(alpha: 0.4) 
                                : const Color(FlickoColors.textMuted).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          if (hasVoted) ...[
                            const Icon(Icons.check_circle, size: 16, color: Color(FlickoColors.textPrimary)),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              text ?? 'Option',
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textPrimary),
                                fontSize: 14,
                                fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textPrimary),
                              fontSize: 14,
                              fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
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
              Text(
                '$totalOverallVotes votes',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                ),
              ),
              if (hasEnded) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgTertiary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ended',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(FlickoColors.textMuted),
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
