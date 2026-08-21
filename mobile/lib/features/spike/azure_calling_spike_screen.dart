import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mobile/data/services/azure_calling_service.dart';
import 'package:mobile/features/voice/data/voice_repository.dart';

class AzureCallingSpikeScreen extends ConsumerStatefulWidget {
  const AzureCallingSpikeScreen({super.key});

  @override
  ConsumerState<AzureCallingSpikeScreen> createState() => _AzureCallingSpikeScreenState();
}

class _AzureCallingSpikeScreenState extends ConsumerState<AzureCallingSpikeScreen> {
  final TextEditingController _channelIdCtrl = TextEditingController(text: 'test_voice_channel');
  final TextEditingController _tokenCtrl = TextEditingController();

  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _channelIdCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTokenAndConnect() async {
    final channelId = _channelIdCtrl.text.trim();
    if (channelId.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid channel ID');
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final voiceRepo = ref.read(voiceRepositoryProvider);
      final callingService = ref.read(azureCallingServiceProvider);

      final connInfo = await voiceRepo.fetchConnection(channelId, 'spike_server');
      final token = connInfo.token;
      _tokenCtrl.text = token;

      await callingService.connect(token, channelId: channelId);
      await callingService.setCameraEnabled(true);
      await callingService.setMicrophoneMuted(false);
      setState(() {});
    } catch (e) {
      setState(() => _errorMessage = 'Connection failed: ${e.toString()}');
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    final callingService = ref.read(azureCallingServiceProvider);
    await callingService.disconnect();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final callingService = ref.watch(azureCallingServiceProvider);
    final isConnected = callingService.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Azure ACS Calling Spike'),
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
                ? _buildVideoGrid(callingService)
                : const Center(child: Text("Not connected to Azure Calling session")),
          ),
          if (isConnected) _buildControls(callingService),
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
            controller: _channelIdCtrl,
            decoration: const InputDecoration(
              labelText: 'Channel ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'ACS Voice Token (auto-fetched)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _isConnecting
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _fetchTokenAndConnect,
                  child: const Text('Connect to Azure ACS Voice Room'),
                ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(AzureCallingService callingService) {
    final localRenderer = callingService.localVideoRenderer;
    final remoteParticipants = callingService.remoteParticipants.values.toList();

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(8.0),
      crossAxisSpacing: 8.0,
      mainAxisSpacing: 8.0,
      children: [
        // Local participant tile
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (localRenderer != null && localRenderer.srcObject != null)
                RTCVideoView(
                  localRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                Container(
                  color: Colors.black87,
                  child: const Center(child: Icon(Icons.person, color: Colors.white54, size: 48)),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.black54,
                  child: const Text('You (Local)', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),

        // Remote participant tiles
        ...remoteParticipants.map((p) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (p.videoRenderer != null && p.videoRenderer!.srcObject != null)
                  RTCVideoView(
                    p.videoRenderer!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                else
                  Container(
                    color: Colors.black87,
                    child: const Center(child: Icon(Icons.person, color: Colors.white54, size: 48)),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black54,
                    child: Text(p.name, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildControls(AzureCallingService callingService) {
    final isMuted = callingService.isMuted;
    final isCameraEnabled = callingService.isCameraEnabled;
    final isScreenSharing = callingService.isScreenSharing;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.black12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
            onPressed: () async {
              await callingService.setMicrophoneMuted(!isMuted);
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(isCameraEnabled ? Icons.videocam : Icons.videocam_off),
            onPressed: () async {
              await callingService.setCameraEnabled(!isCameraEnabled);
              setState(() {});
            },
          ),
          IconButton(
            icon: Icon(isScreenSharing ? Icons.stop_screen_share : Icons.screen_share),
            onPressed: () async {
              await callingService.setScreenShareEnabled(!isScreenSharing);
              setState(() {});
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
