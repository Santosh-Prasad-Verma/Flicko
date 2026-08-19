import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'dart:convert';
import 'package:mobile/data/clients/supabase_client.dart';

Future<void> showPollCreatorModal(
  BuildContext context, {
  required String channelId,
  required String serverId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _PollCreatorModal(
      channelId: channelId,
      serverId: serverId,
    ),
  );
}

class _PollCreatorModal extends StatefulWidget {
  final String channelId;
  final String serverId;

  const _PollCreatorModal({
    required this.channelId,
    required this.serverId,
  });

  @override
  State<_PollCreatorModal> createState() => _PollCreatorModalState();
}

class _PollCreatorModalState extends State<_PollCreatorModal> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _multiSelect = false;
  int _durationHours = 24; // Default to 24 hours
  bool _isSubmitting = false;

  void _addOption() {
    if (_optionControllers.length < 10) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _createPoll() async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a question and at least 2 options.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      // Calculate end time
      final endTime = DateTime.now().add(Duration(hours: _durationHours)).toUtc().toIso8601String();

      final pollData = {
        'question': question,
        'options': options.map((o) => {'text': o, 'votes': 0}).toList(),
        'multiSelect': _multiSelect,
        'endTime': endTime,
      };

      await client.from('messages').insert({
        'channel_id': widget.channelId,
        'author_id': userId,
        'content': jsonEncode(pollData),
        'type': 'poll',
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating poll: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      margin: EdgeInsets.only(top: kToolbarHeight),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Create Poll',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(FlickoColors.textMuted)),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView(
              children: [
                // Question
                Text(
                  'QUESTION',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _questionController,
                  style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                  decoration: InputDecoration(
                    hintText: 'Ask a question...',
                    hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                    filled: true,
                    fillColor: const Color(FlickoColors.bgTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ANSWERS',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\${_optionControllers.length}/10',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                ...List.generate(
                  _optionControllers.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _optionControllers[index],
                            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                            decoration: InputDecoration(
                              hintText: 'Option \${index + 1}',
                              hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                              filled: true,
                              fillColor: const Color(FlickoColors.bgTertiary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        if (_optionControllers.length > 2) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Color(FlickoColors.red)),
                            onPressed: () => _removeOption(index),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                
                if (_optionControllers.length < 10)
                  TextButton.icon(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
                    label: Text(
                      'Add an option',
                      style: GoogleFonts.inter(color: const Color(FlickoColors.blurple)),
                    ),
                    style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  ),
                  
                const SizedBox(height: 24),
                
                // Settings
                Text(
                  'SETTINGS',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text('Allow multiple answers', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
                  value: _multiSelect,
                  onChanged: (v) => setState(() => _multiSelect = v),
                  activeThumbColor: const Color(FlickoColors.blurple),
                  contentPadding: EdgeInsets.zero,
                ),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Duration', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
                  trailing: DropdownButton<int>(
                    value: _durationHours,
                    dropdownColor: const Color(FlickoColors.bgSecondary),
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 Hour')),
                      DropdownMenuItem(value: 24, child: Text('24 Hours')),
                      DropdownMenuItem(value: 72, child: Text('3 Days')),
                      DropdownMenuItem(value: 168, child: Text('1 Week')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _durationHours = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          ElevatedButton(
            onPressed: _isSubmitting ? null : _createPoll,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Post Poll', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
