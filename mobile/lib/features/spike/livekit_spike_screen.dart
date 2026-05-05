import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/core/config/app_config.dart';

class LiveKitSpikeScreen extends StatefulWidget {
  const LiveKitSpikeScreen({super.key});

  @override
  State<LiveKitSpikeScreen> createState() => _LiveKitSpikeScreenState();
}

class _LiveKitSpikeScreenState extends State<LiveKitSpikeScreen> with EventsListener<RoomEvent> {
  late final Room _room;
  late final EventsListener<RoomEvent> _listener;

  bool _isConnecting = false;
  String? _errorMessage;

  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _tokenCtrl = TextEditingController();

  List<ParticipantTrack> participantTracks = [];

  @override
  void initState() {
    super.initState();
    _room = Room();
    _listener = _room.createListener();
    _listener
      ..on<RoomDisconnectedEvent>((event) {
        setState(() {
          participantTracks.clear();
        });
      })
      ..on<TrackSubscribedEvent>((event) {
        _sortParticipants();
      })
      ..on<TrackUnsubscribedEvent>((event) {
        _sortParticipants();
      })
      ..on<LocalTrackPublishedEvent>((event) {
        _sortParticipants();
      })
      ..on<LocalTrackUnpublishedEvent>((event) {
        _sortParticipants();
      });

    // Populate default from AppConfig if available
    _urlCtrl.text = AppConfig.livekitUrl.isNotEmpty ? AppConfig.livekitUrl : 'wss://your-livekit-url';
  }

  @override
  void dispose() {
    _listener.dispose();
    _room.disconnect();
    _room.dispose();
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  void _sortParticipants() {
    List<ParticipantTrack> tracks = [];
    if (_room.localParticipant != null) {
      for (var trackPub in _room.localParticipant!.videoTrackPublications) {
        if (trackPub.track != null) {
          tracks.add(ParticipantTrack(
              participant: _room.localParticipant!, videoTrack: trackPub.track as VideoTrack));
        }
      }
    }
    for (var participant in _room.remoteParticipants.values) {
      for (var trackPub in participant.videoTrackPublications) {
        if (trackPub.track != null) {
          tracks.add(ParticipantTrack(
              participant: participant, videoTrack: trackPub.track as VideoTrack));
        }
      }
    }
    setState(() {
      participantTracks = tracks;
    });
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text;
    final token = _tokenCtrl.text;

    if (token.isEmpty) {
      setState(() => _errorMessage = "Please enter a valid token");
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      await _room.connect(url, token);
      
      // Auto publish camera and mic after connection
      await _room.localParticipant?.setCameraEnabled(true);
      await _room.localParticipant?.setMicrophoneEnabled(true);

      _sortParticipants();
    } catch (e) {
      setState(() => _errorMessage = 'Connection failed: \${e.toString()}');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    await _room.disconnect();
    setState(() {
      participantTracks.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _room.connectionState == ConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LiveKit Spike'),
      ),
      body: Column(
        children: [
          _buildConnectionPanel(isConnected),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: isConnected
                ? _buildVideoGrid()
                : const Center(child: Text("Not connected to any room")),
          ),
          if (isConnected) _buildControls(),
        ],
      ),
    );
  }

  Widget _buildConnectionPanel(bool isConnected) {
    if (isConnected) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(labelText: 'LiveKit URL', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenCtrl,
            decoration: const InputDecoration(labelText: 'Access Token', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _isConnecting
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _connect,
                  child: const Text('Connect to Room'),
                ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (participantTracks.isEmpty) {
      return const Center(child: Text("Waiting for video tracks..."));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: participantTracks.length,
      itemBuilder: (context, index) {
        final track = participantTracks[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoTrackRenderer(
                track.videoTrack,
                fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.black54,
                  child: Text(
                    track.participant.identity,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    final localParticipant = _room.localParticipant;
    final isCameraEnabled = localParticipant?.isCameraEnabled() ?? false;
    final isMicEnabled = localParticipant?.isMicrophoneEnabled() ?? false;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.black12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(isMicEnabled ? Icons.mic : Icons.mic_off),
            onPressed: () async {
              await localParticipant?.setMicrophoneEnabled(!isMicEnabled);
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(isCameraEnabled ? Icons.videocam : Icons.videocam_off),
            onPressed: () async {
              await localParticipant?.setCameraEnabled(!isCameraEnabled);
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.screen_share),
            onPressed: () async {
              final isScreenShareEnabled = localParticipant?.isScreenShareEnabled() ?? false;
              await localParticipant?.setScreenShareEnabled(!isScreenShareEnabled);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _disconnect,
            child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class ParticipantTrack {
  final Participant participant;
  final VideoTrack videoTrack;

  ParticipantTrack({required this.participant, required this.videoTrack});
}
