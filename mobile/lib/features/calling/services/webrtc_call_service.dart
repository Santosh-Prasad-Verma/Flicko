import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final webRtcCallServiceProvider = Provider<WebRtcCallService>((ref) {
  final service = WebRtcCallService(Supabase.instance.client);
  ref.onDispose(service.dispose);
  return service;
});

enum WebRtcCallPhase {
  idle,
  preparing,
  signaling,
  connecting,
  connected,
  reconnecting,
  ended,
  failed,
}

enum _RtcSignalType { ready, offer, answer, ice, media, hangup }

class WebRtcCallService extends ChangeNotifier {
  WebRtcCallService(this._supabase);

  final SupabaseClient _supabase;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RealtimeChannel? _channel;
  RTCPeerConnection? _peer;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  AudioSession? _audioSession;
  Timer? _offerRetryTimer;
  RTCSessionDescription? _lastLocalOffer;
  final List<RTCIceCandidate> _pendingRemoteIceCandidates = [];

  bool _renderersReady = false;
  bool _started = false;
  bool _isCaller = false;
  bool _remoteReady = false;
  bool _answerReceived = false;
  bool _muted = false;
  bool _cameraEnabled = false;
  bool _speakerEnabled = true;
  bool _callAudioSessionActive = false;
  String? _roomName;
  String? _myUserId;
  String? _peerUserId;
  String? _error;
  WebRtcCallPhase _phase = WebRtcCallPhase.idle;
  RTCPeerConnectionState? _peerConnectionState;
  RTCIceConnectionState? _iceConnectionState;
  static const Duration _roomSubscribeTimeout = Duration(seconds: 8);

  bool get renderersReady => _renderersReady;
  bool get isStarted => _started;
  bool get isMuted => _muted;
  bool get cameraEnabled => _cameraEnabled;
  bool get speakerEnabled => _speakerEnabled;
  bool get hasRemoteVideo => _remoteStream?.getVideoTracks().isNotEmpty == true;
  bool get hasLocalVideo => _localStream?.getVideoTracks().isNotEmpty == true;
  String? get error => _error;
  WebRtcCallPhase get phase => _phase;
  RTCPeerConnectionState? get peerConnectionState => _peerConnectionState;
  RTCIceConnectionState? get iceConnectionState => _iceConnectionState;

  String get phaseLabel {
    if (_error != null && _phase == WebRtcCallPhase.failed) return 'FAILED';
    switch (_phase) {
      case WebRtcCallPhase.idle:
        return 'IDLE';
      case WebRtcCallPhase.preparing:
        return 'PREPARING MEDIA';
      case WebRtcCallPhase.signaling:
        return 'SIGNALING';
      case WebRtcCallPhase.connecting:
        return 'CONNECTING';
      case WebRtcCallPhase.connected:
        return 'CONNECTED';
      case WebRtcCallPhase.reconnecting:
        return 'RECONNECTING';
      case WebRtcCallPhase.ended:
        return 'ENDED';
      case WebRtcCallPhase.failed:
        return 'FAILED';
    }
  }

  Future<void> startCall({
    required String roomName,
    required String myUserId,
    required String peerUserId,
    required bool isCaller,
    required bool videoEnabled,
  }) async {
    if (_started && _roomName == roomName) return;
    await endCall(notifyPeer: false);

    _started = true;
    _isCaller = isCaller;
    _roomName = roomName;
    _myUserId = myUserId;
    _peerUserId = peerUserId;
    _muted = false;
    _cameraEnabled = videoEnabled;
    _speakerEnabled = true;
    _remoteReady = false;
    _answerReceived = false;
    _lastLocalOffer = null;
    _pendingRemoteIceCandidates.clear();
    _error = null;
    _setPhase(WebRtcCallPhase.preparing);

    try {
      await _ensureRenderersReady();
      await _openLocalMedia(videoEnabled: videoEnabled);
      await _createPeerConnection();
      await _subscribeRoom();
      await _sendSignal(_RtcSignalType.ready);
      _setPhase(WebRtcCallPhase.signaling);

      if (_isCaller) {
        _offerRetryTimer?.cancel();
        _offerRetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (_phase == WebRtcCallPhase.connected || !_started) {
            timer.cancel();
            return;
          }
          if (_remoteReady || timer.tick >= 2) {
            unawaited(_createAndSendOffer());
          }
          if (timer.tick >= 8) timer.cancel();
        });
      }
    } catch (error, stackTrace) {
      debugPrint('[FlickoRTC] start failed: $error\n$stackTrace');
      _error = error.toString();
      _setPhase(WebRtcCallPhase.failed);
      await endCall(notifyPeer: true);
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    final audioTracks = _localStream?.getAudioTracks() ?? <MediaStreamTrack>[];
    if (audioTracks.isEmpty) {
      debugPrint('[FlickoRTC] no local microphone track to toggle');
      return;
    }

    if (enabled && !_callAudioSessionActive) {
      await _startPhoneAudioSession();
    }

    for (final track in audioTracks) {
      track.enabled = enabled;
      await Helper.setMicrophoneMute(!enabled, track);
    }

    _muted = !enabled;
    await _sendSignal(_RtcSignalType.media, payload: _mediaPayload());
    notifyListeners();
  }

  Future<void> setCameraEnabled(bool enabled) async {
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
    _cameraEnabled = enabled;
    await _sendSignal(_RtcSignalType.media, payload: _mediaPayload());
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    _speakerEnabled = enabled;
    await Helper.setSpeakerphoneOn(enabled);
    if (_remoteStream != null) {
      await _activateRemoteAudio();
    }
    notifyListeners();
  }

  Future<void> endCall({bool notifyPeer = true}) async {
    final shouldNotify =
        notifyPeer && _started && _phase != WebRtcCallPhase.ended;
    if (shouldNotify) {
      await _sendSignal(_RtcSignalType.hangup);
    }

    _offerRetryTimer?.cancel();
    _offerRetryTimer = null;

    try {
      await _peer?.close();
    } catch (error) {
      debugPrint('[FlickoRTC] peer close ignored: $error');
    }
    _peer = null;

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await _localStream?.dispose();
      await _remoteStream?.dispose();
    } catch (_) {}
    _localStream = null;
    _remoteStream = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    try {
      await _channel?.unsubscribe();
    } catch (error) {
      debugPrint('[FlickoRTC] channel unsubscribe ignored: $error');
    }
    _channel = null;

    await _stopPhoneAudioSession();

    _started = false;
    _remoteReady = false;
    _answerReceived = false;
    _lastLocalOffer = null;
    _pendingRemoteIceCandidates.clear();
    _roomName = null;
    _myUserId = null;
    _peerUserId = null;
    _peerConnectionState = null;
    _iceConnectionState = null;
    _muted = false;
    _cameraEnabled = false;
    _setPhase(WebRtcCallPhase.ended);
  }

  Future<void> _ensureRenderersReady() async {
    if (_renderersReady) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _renderersReady = true;
  }

  Future<void> _openLocalMedia({required bool videoEnabled}) async {
    await _ensureMediaPermissions(videoEnabled: videoEnabled);
    await _startPhoneAudioSession();

    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': videoEnabled
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
              'frameRate': {'ideal': 30},
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    final audioTracks = _localStream?.getAudioTracks() ?? <MediaStreamTrack>[];
    if (audioTracks.isEmpty) {
      throw StateError('No microphone audio track was created');
    }

    for (final track in audioTracks) {
      track.enabled = true;
      await Helper.setMicrophoneMute(false, track);
    }

    localRenderer.srcObject = _localStream;
    await Helper.setSpeakerphoneOn(_speakerEnabled);
    debugPrint(
      '[FlickoRTC] local media opened: '
      'audio=${_localStream?.getAudioTracks().length ?? 0}, '
      'video=${_localStream?.getVideoTracks().length ?? 0}',
    );
  }

  Future<void> _ensureMediaPermissions({required bool videoEnabled}) async {
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      throw StateError('Microphone permission denied');
    }

    unawaited(_requestOptionalBluetoothPermission());

    if (videoEnabled) {
      final camera = await Permission.camera.request();
      if (!camera.isGranted) {
        throw StateError('Camera permission denied');
      }
    }
  }

  Future<void> _requestOptionalBluetoothPermission() async {
    try {
      final status = await Permission.bluetoothConnect.status;
      if (status.isDenied || status.isRestricted || status.isLimited) {
        final result = await Permission.bluetoothConnect.request();
        debugPrint('[FlickoRTC] bluetooth audio permission: $result');
      }
    } catch (error) {
      debugPrint('[FlickoRTC] bluetooth permission ignored: $error');
    }
  }

  Future<void> _startPhoneAudioSession() async {
    if (Platform.isAndroid) {
      // flutter_webrtc on Android does not switch to MODE_IN_COMMUNICATION on
      // its own. Without this, AudioRecord initializes against the wrong
      // stream and both ends capture silence. This must be set before
      // getUserMedia and cannot be changed mid-session.
      try {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
        debugPrint('[FlickoRTC] android communication audio mode set');
      } catch (error) {
        debugPrint('[FlickoRTC] android audio config failed: $error');
      }
      _callAudioSessionActive = true;
      return;
    }

    if (!Platform.isIOS) {
      _callAudioSessionActive = true;
      return;
    }

    _audioSession ??= await AudioSession.instance;
    await _audioSession!.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
    ));

    final activated = await _audioSession!.setActive(true);
    if (!activated) {
      throw StateError('Phone call audio session did not activate');
    }

    _callAudioSessionActive = true;
    debugPrint('[FlickoRTC] phone call audio session active');
  }

  Future<void> _stopPhoneAudioSession() async {
    if (!_callAudioSessionActive && _audioSession == null) return;

    if (Platform.isAndroid) {
      try {
        await Helper.clearAndroidCommunicationDevice();
      } catch (error) {
        debugPrint('[FlickoRTC] clear android comm device ignored: $error');
      }
      _callAudioSessionActive = false;
      return;
    }

    if (!Platform.isIOS) {
      _callAudioSessionActive = false;
      return;
    }

    try {
      await _audioSession?.setActive(false);
      await _audioSession?.configure(const AudioSessionConfiguration.music());
    } catch (error) {
      debugPrint('[FlickoRTC] phone call audio session stop ignored: $error');
    } finally {
      _callAudioSessionActive = false;
    }
  }

  Future<void> _createPeerConnection() async {
    _peer = await createPeerConnection(
      {
        'sdpSemantics': 'unified-plan',
        'iceServers': _iceServers(),
      },
      {
        'mandatory': {},
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      },
    );

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await _peer!.addTrack(track, _localStream!);
    }

    _peer!
      ..onIceCandidate = (candidate) {
        if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
        debugPrint('[FlickoRTC] local ICE candidate generated');
        unawaited(
          _sendSignal(
            _RtcSignalType.ice,
            payload: {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
          ),
        );
      }
      ..onTrack = (event) {
        unawaited(_attachRemoteTrack(event));
      }
      ..onConnectionState = (state) {
        _peerConnectionState = state;
        debugPrint('[FlickoRTC] peer connection state: $state');
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _setPhase(WebRtcCallPhase.connected);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
            _setPhase(WebRtcCallPhase.connecting);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _setPhase(WebRtcCallPhase.reconnecting);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            _setPhase(WebRtcCallPhase.failed);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _setPhase(WebRtcCallPhase.ended);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateNew:
            break;
        }
      }
      ..onIceConnectionState = (state) {
        _iceConnectionState = state;
        debugPrint('[FlickoRTC] ICE connection state: $state');
        notifyListeners();
      };
  }

  Future<void> _attachRemoteTrack(RTCTrackEvent event) async {
    debugPrint(
      '[FlickoRTC] remote ${event.track.kind} track received '
      'streams=${event.streams.length}',
    );

    MediaStream stream;
    if (event.streams.isNotEmpty) {
      stream = event.streams.first;
    } else {
      stream = _remoteStream ??
          await createLocalMediaStream('flicko-remote-${_roomName ?? 'call'}');
      await stream.addTrack(event.track, addToNative: false);
    }

    _remoteStream = stream;
    remoteRenderer.srcObject = stream;
    await _activateRemoteAudio();
    notifyListeners();
  }

  Future<void> _activateRemoteAudio() async {
    final audioTracks = _remoteStream?.getAudioTracks() ?? <MediaStreamTrack>[];
    for (final track in audioTracks) {
      track.enabled = true;
    }

    try {
      await remoteRenderer.setVolume(1.0);
      await Helper.setSpeakerphoneOn(_speakerEnabled);
    } catch (error) {
      debugPrint('[FlickoRTC] remote audio route failed: $error');
    }

    debugPrint('[FlickoRTC] remote audio tracks=${audioTracks.length}');
  }

  Future<void> _subscribeRoom() async {
    final roomName = _roomName;
    if (roomName == null) return;

    _channel = _supabase
        .channel(
          'flicko_rtc:$roomName',
          opts: const RealtimeChannelConfig(ack: true),
        )
        .onBroadcast(
          event: 'rtc_signal',
          callback: (payload) {
            unawaited(_handleSignal(payload));
          },
        );

    await _subscribeRealtimeChannel(_channel!, label: 'rtc:$roomName');
  }

  Future<void> _subscribeRealtimeChannel(
    RealtimeChannel channel, {
    required String label,
  }) async {
    final completer = Completer<void>();
    channel.subscribe((status, error) {
      debugPrint('[FlickoRTC] $label subscription status: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!completer.isCompleted) completer.complete();
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.timedOut) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('$label subscription failed: $status ${error ?? ''}'),
          );
        }
      }
    });

    await completer.future.timeout(
      _roomSubscribeTimeout,
      onTimeout: () => throw TimeoutException('$label subscription timed out'),
    );
  }

  Future<void> _handleSignal(dynamic payload) async {
    if (!_started || payload is! Map) return;

    final senderId = payload['sender_id'] as String?;
    final targetId = payload['target_id'] as String?;
    if (senderId == null || senderId == _myUserId) return;
    if (targetId != null && targetId.isNotEmpty && targetId != _myUserId) {
      return;
    }

    final typeName = payload['type'] as String?;
    _RtcSignalType? type;
    for (final value in _RtcSignalType.values) {
      if (value.name == typeName) {
        type = value;
        break;
      }
    }
    if (type == null) return;

    switch (type) {
      case _RtcSignalType.ready:
        _remoteReady = true;
        if (!_isCaller) {
          await _sendSignal(_RtcSignalType.ready);
        } else {
          await _createAndSendOffer();
        }
        break;
      case _RtcSignalType.offer:
        await _handleOffer(payload);
        break;
      case _RtcSignalType.answer:
        await _handleAnswer(payload);
        break;
      case _RtcSignalType.ice:
        await _handleIce(payload);
        break;
      case _RtcSignalType.media:
        notifyListeners();
        break;
      case _RtcSignalType.hangup:
        await endCall(notifyPeer: false);
        break;
    }
  }

  Future<void> _createAndSendOffer() async {
    if (!_started || !_isCaller || _answerReceived || _peer == null) return;
    _setPhase(WebRtcCallPhase.connecting);

    var offer = _lastLocalOffer;
    if (offer == null) {
      offer = await _peer!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peer!.setLocalDescription(offer);
      _lastLocalOffer = offer;
    }

    await _sendSignal(
      _RtcSignalType.offer,
      payload: {'sdp': offer.sdp, 'sdpType': offer.type},
    );
  }

  Future<void> _handleOffer(Map payload) async {
    final sdp = payload['sdp'] as String?;
    if (sdp == null || _peer == null) return;
    _setPhase(WebRtcCallPhase.connecting);

    final existingRemote = await _safeRemoteDescription();
    final existingLocal = await _safeLocalDescription();
    if (existingRemote?.type == 'offer' && existingRemote?.sdp == sdp) {
      if (existingLocal?.type == 'answer' &&
          existingLocal?.sdp?.isNotEmpty == true) {
        await _sendSignal(
          _RtcSignalType.answer,
          payload: {'sdp': existingLocal!.sdp, 'sdpType': existingLocal.type},
        );
      }
      return;
    }

    await _peer!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    await _flushPendingRemoteIceCandidates();
    final answer = await _peer!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peer!.setLocalDescription(answer);
    await _sendSignal(
      _RtcSignalType.answer,
      payload: {'sdp': answer.sdp, 'sdpType': answer.type},
    );
  }

  Future<void> _handleAnswer(Map payload) async {
    final sdp = payload['sdp'] as String?;
    if (sdp == null || _peer == null) return;
    if (_answerReceived) return;
    await _peer!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    _answerReceived = true;
    _offerRetryTimer?.cancel();
    _offerRetryTimer = null;
    await _flushPendingRemoteIceCandidates();
  }

  Future<void> _handleIce(Map payload) async {
    if (_peer == null) return;
    final candidate = payload['candidate'] as String?;
    if (candidate == null || candidate.isEmpty) return;

    final iceCandidate = RTCIceCandidate(
      candidate,
      payload['sdpMid'] as String?,
      payload['sdpMLineIndex'] as int?,
    );

    final remoteDescription = await _safeRemoteDescription();
    if (remoteDescription?.sdp?.isNotEmpty != true) {
      _pendingRemoteIceCandidates.add(iceCandidate);
      debugPrint('[FlickoRTC] queued remote ICE candidate');
      return;
    }

    await _addRemoteIceCandidate(iceCandidate);
  }

  Future<void> _flushPendingRemoteIceCandidates() async {
    if (_pendingRemoteIceCandidates.isEmpty || _peer == null) return;
    final queued = List<RTCIceCandidate>.from(_pendingRemoteIceCandidates);
    _pendingRemoteIceCandidates.clear();
    debugPrint('[FlickoRTC] flushing ${queued.length} remote ICE candidates');
    for (final candidate in queued) {
      await _addRemoteIceCandidate(candidate);
    }
  }

  Future<void> _addRemoteIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _peer?.addCandidate(candidate);
      debugPrint('[FlickoRTC] remote ICE candidate added');
    } catch (error) {
      debugPrint('[FlickoRTC] add remote ICE failed: $error');
    }
  }

  Future<RTCSessionDescription?> _safeRemoteDescription() async {
    try {
      return await _peer?.getRemoteDescription();
    } catch (_) {
      return null;
    }
  }

  Future<RTCSessionDescription?> _safeLocalDescription() async {
    try {
      return await _peer?.getLocalDescription();
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendSignal(
    _RtcSignalType type, {
    Map<String, dynamic>? payload,
  }) async {
    final channel = _channel;
    final myUserId = _myUserId;
    final peerUserId = _peerUserId;
    if (channel == null || myUserId == null || peerUserId == null) return;

    final message = <String, dynamic>{
      'type': type.name,
      'room_name': _roomName,
      'sender_id': myUserId,
      'target_id': peerUserId,
      'sent_at': DateTime.now().toIso8601String(),
      ...?payload,
    };

    try {
      final response = await channel.sendBroadcastMessage(
        event: 'rtc_signal',
        payload: message,
      );
      if (response != ChannelResponse.ok) {
        debugPrint('[FlickoRTC] send ${type.name} returned $response');
      } else {
        debugPrint('[FlickoRTC] sent ${type.name}');
      }
    } catch (error) {
      debugPrint('[FlickoRTC] send ${type.name} failed: $error');
    }
  }

  Map<String, dynamic> _mediaPayload() {
    return {
      'muted': _muted,
      'camera_enabled': _cameraEnabled,
      'speaker_enabled': _speakerEnabled,
    };
  }

  List<Map<String, dynamic>> _iceServers() {
    final stunUrls = AppConfig.rtcStunUrls
        .split(',')
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);

    final servers = <Map<String, dynamic>>[
      if (stunUrls.isNotEmpty) {'urls': stunUrls},
    ];

    if (AppConfig.rtcTurnUrl.trim().isNotEmpty) {
      servers.add({
        'urls': AppConfig.rtcTurnUrl.trim(),
        if (AppConfig.rtcTurnUsername.trim().isNotEmpty)
          'username': AppConfig.rtcTurnUsername.trim(),
        if (AppConfig.rtcTurnCredential.trim().isNotEmpty)
          'credential': AppConfig.rtcTurnCredential.trim(),
      });
    }
    return servers;
  }

  void _setPhase(WebRtcCallPhase next) {
    if (_phase == next && next != WebRtcCallPhase.connected) return;
    _phase = next;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(endCall(notifyPeer: false));
    if (_renderersReady) {
      localRenderer.dispose();
      remoteRenderer.dispose();
      _renderersReady = false;
    }
    super.dispose();
  }
}
