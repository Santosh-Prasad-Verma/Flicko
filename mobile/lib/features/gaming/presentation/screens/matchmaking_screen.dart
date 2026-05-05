import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class MatchmakingScreen extends StatefulWidget {
  final String activityName;

  const MatchmakingScreen({
    super.key,
    required this.activityName,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  // Lobbies & Matchmaking state
  bool _isPublic = true;
  String _difficulty = 'Medium';
  int _maxPlayers = 2;
  int _timeLimit = 10; // in minutes
  String _theme = 'Midnight Classic';

  final List<Map<String, dynamic>> _players = [
    {
      'name': 'You (Owner)',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=150&auto=format&fit=crop',
      'ping': '34ms',
      'isHost': true,
      'isBot': false,
      'ready': true,
    }
  ];

  final List<Map<String, String>> _chatMessages = [
    {'sender': 'System', 'text': 'Match lobby created. Waiting for other players...'}
  ];
  final TextEditingController _chatController = TextEditingController();

  void _addBot() {
    if (_players.length >= _maxPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lobby is already full!'),
          backgroundColor: Color(FlickoColors.danger),
        ),
      );
      return;
    }
    setState(() {
      _players.add({
        'name': 'Flicko Bot ($_difficulty)',
        'avatar': 'https://images.unsplash.com/photo-1531297484001-80022131f5a1?q=80&w=150&auto=format&fit=crop',
        'ping': '0ms',
        'isHost': false,
        'isBot': true,
        'ready': true,
      });
    });
  }

  void _removePlayer(int index) {
    if (index == 0) return; // Cannot remove host
    setState(() {
      _players.removeAt(index);
    });
  }

  void _sendMessage() {
    if (_chatController.text.trim().isEmpty) return;
    setState(() {
      _chatMessages.add({
        'sender': 'You',
        'text': _chatController.text.trim(),
      });
      _chatController.clear();
    });
  }

  void _startGame() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting ${widget.activityName} activity match!'),
        backgroundColor: const Color(FlickoColors.success),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${widget.activityName.toUpperCase()} HUB',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: Color(FlickoColors.textPrimary),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildLobbyPanel()),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildChatAndSettingsPanel()),
                    ],
                  )
                : ListView(
                    children: [
                      _buildLobbyPanel(),
                      const SizedBox(height: 16),
                      _buildChatAndSettingsPanel(),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildLobbyPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(FlickoColors.bgTertiary),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activity Matchmaking',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(FlickoColors.textPrimary),
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Private',
                    style: TextStyle(
                      color: Color(FlickoColors.textSecondary),
                      fontSize: 12,
                    ),
                  ),
                  Switch.adaptive(
                    value: _isPublic,
                    activeTrackColor: const Color(FlickoColors.blurple),
                    onChanged: (val) {
                      setState(() {
                        _isPublic = val;
                      });
                    },
                  ),
                  const Text(
                    'Public',
                    style: TextStyle(
                      color: Color(FlickoColors.textSecondary),
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          // Lobby info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgPrimary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.hub_outlined, color: Color(FlickoColors.blurple), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match ID',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(FlickoColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'FLICKO-LOBBY-40593',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(FlickoColors.textPrimary).withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.blurple),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.share, size: 16, color: Colors.white),
                  label: const Text('Invite', style: TextStyle(color: Colors.white, fontSize: 12)),
                  onPressed: () {},
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PLAYERS IN LOBBY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(FlickoColors.textMuted),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: _players.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final player = _players[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.bgPrimary),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: player['isHost'] ? const Color(FlickoColors.blurple).withValues(alpha: 0.4) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(player['avatar']),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  player['name'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(FlickoColors.textPrimary),
                                  ),
                                ),
                                if (player['isHost']) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.star, color: Color(FlickoColors.gold), size: 14),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.wifi, size: 12, color: Color(FlickoColors.green)),
                                const SizedBox(width: 4),
                                Text(
                                  player['ping'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(FlickoColors.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (player['isBot'] || !player['isHost'])
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(FlickoColors.danger), size: 18),
                          onPressed: () => _removePlayer(index),
                        )
                      else if (!player['isBot'] && player['isHost'])
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(FlickoColors.green).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'READY',
                                style: TextStyle(
                                  color: Color(FlickoColors.green),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.bgTertiary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
              label: const Text(
                'ADD BOT AI PLAYER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
              onPressed: _addBot,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatAndSettingsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(FlickoColors.bgTertiary),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MATCH SETTINGS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(FlickoColors.textMuted),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsDropdown(
            label: 'Bot Difficulty',
            value: _difficulty,
            items: ['Easy', 'Medium', 'Expert'],
            onChanged: (val) {
              if (val != null) {
                setState(() => _difficulty = val);
              }
            },
          ),
          const SizedBox(height: 8),
          _buildSettingsDropdown(
            label: 'Board Theme',
            value: _theme,
            items: ['Midnight Classic', 'Light Glow', 'Glassmorphic Green'],
            onChanged: (val) {
              if (val != null) {
                setState(() => _theme = val);
              }
            },
          ),
          const SizedBox(height: 8),
          _buildSettingsDropdown(
            label: 'Max Players',
            value: '$_maxPlayers Players',
            items: ['2 Players', '4 Players', '8 Players'],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _maxPlayers = int.parse(val.split(' ')[0]);
                });
              }
            },
          ),
          const SizedBox(height: 8),
          _buildSettingsDropdown(
            label: 'Time Limit',
            value: '$_timeLimit mins',
            items: ['5 mins', '10 mins', '15 mins', '30 mins'],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _timeLimit = int.parse(val.split(' ')[0]);
                });
              }
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'LOBBY CHAT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(FlickoColors.textMuted),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgPrimary),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, idx) {
                        final msg = _chatMessages[idx];
                        final isSystem = msg['sender'] == 'System';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${msg['sender']}: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSystem ? const Color(FlickoColors.yellow) : const Color(FlickoColors.blurpleLight),
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: msg['text'],
                                  style: const TextStyle(
                                    color: Color(FlickoColors.textPrimary),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(color: Color(FlickoColors.textPrimary), fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(color: Color(FlickoColors.textMuted), fontSize: 13),
                            filled: true,
                            fillColor: const Color(FlickoColors.bgSecondary),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(FlickoColors.blurple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.blurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _startGame,
              child: const Text(
                'START ACTIVITY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgPrimary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(FlickoColors.textPrimary),
            ),
          ),
          DropdownButton<String>(
            value: value,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(FlickoColors.textPrimary),
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            underline: const SizedBox.shrink(),
            dropdownColor: const Color(FlickoColors.bgSecondary),
            iconEnabledColor: const Color(FlickoColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
