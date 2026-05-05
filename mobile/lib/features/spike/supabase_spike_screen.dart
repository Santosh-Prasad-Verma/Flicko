import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/config/app_config.dart';

class SupabaseSpikeScreen extends StatefulWidget {
  const SupabaseSpikeScreen({super.key});

  @override
  State<SupabaseSpikeScreen> createState() => _SupabaseSpikeScreenState();
}

class _SupabaseSpikeScreenState extends State<SupabaseSpikeScreen> {
  bool _isInit = false;
  String? _errorMessage;

  RealtimeChannel? _channel;
  final List<String> _messages = [];
  final List<String> _onlineUsers = [];
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSupabase();
  }

  Future<void> _initSupabase() async {
    try {
      // 1. Initialize Supabase if not already
      // Note: In real app, this happens in main.dart. For Spike, doing it here ensures isolation.
      if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
      } else {
        setState(() => _errorMessage = 'Supabase environment variables missing.');
        return;
      }

      // 2. Setup Realtime Channel
      final client = Supabase.instance.client;
      _channel = client.channel('spike_chat_room');

      // 3. Listen to Presence (Who is online)
      _channel!.onPresenceSync((payload) {
        final state = _channel!.presenceState();
        final users = state.values.expand((element) => element).map((e) => e.payload['user'] as String).toList();
        setState(() {
          _onlineUsers.clear();
          _onlineUsers.addAll(users);
        });
      });

      _channel!.onPresenceJoin((payload) {
        print('User joined: \$payload');
      });

      _channel!.onPresenceLeave((payload) {
        print('User left: \$payload');
      });

      // 4. Listen to Broadcast Messages (Chat)
      _channel!.onBroadcast(event: 'chat', callback: (payload) {
        setState(() {
          _messages.add(payload['message'] as String);
        });
      });

      // 5. Subscribe to channel and track presence
      await _channel!.subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          final userId = 'User-\${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
          await _channel!.track({'user': userId});
          setState(() => _isInit = true);
        }
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  void _sendMessage() {
    if (_msgCtrl.text.isEmpty || _channel == null) return;
    final msg = _msgCtrl.text;
    
    _channel!.sendBroadcastMessage(event: 'chat', payload: {'message': msg});
    
    setState(() {
      _messages.add('Me: \$msg');
      _msgCtrl.clear();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supabase Spike')),
        body: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
      );
    }

    if (!_isInit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supabase Spike')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Supabase Realtime Spike')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blueAccent.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.blue),
                const SizedBox(width: 8),
                Text('Online: \${_onlineUsers.join(', ')}'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
