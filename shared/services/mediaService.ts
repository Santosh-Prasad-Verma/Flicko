/**
 * Media Service — Manages LiveKit room lifecycle, camera/screen controls,
 * quality management, and stats collection.
 *
 * This is the imperative bridge between the Zustand voice store and the
 * LiveKit SDK.  Components that need the Room context should still use
 * &lt;LiveKitRoom&gt; + hooks (useTracks, useParticipants …).
 * This service backs the hook layer (useVideoCall, useGoLive) and provides
 * token-fetching plus DB bookkeeping for voice_states / streams.
 *
 * Zero-cost: Uses self-hosted LiveKit on Oracle Cloud Always Free tier
 */
import { Room, RoomEvent, Track, ConnectionState, ConnectionQuality as LKConnectionQuality, VideoPresets, type RoomOptions, type LocalParticipant, type RemoteParticipant, type RemoteTrackPublication, type RemoteTrack, type Participant } from 'livekit-client';
import { supabase } from '../lib/supabase';
import { useVoiceStore, QUALITY_PRESETS, SCREEN_SHARE_PRESETS, type MediaStats } from '../stores/voiceStore';

export type { StreamConfig } from '../stores/voiceStore';
import type { StreamConfig } from '../stores/voiceStore';

// ─── Token Fetcher ───────────────────────────────────────────────────────

async function fetchVoiceToken(config: {
  channelId: string;
  serverId: string;
  video?: boolean;
  screenShare?: boolean;
  streamTitle?: string;
  streamType?: string;
  quality?: string;
}): Promise<{
  token: string;
  room: string;
  streamId: string | null;
  serverUrl: string;
  qualityConfig?: any;
}> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  const response = await supabase.functions.invoke('voice-token', {
    body: config,
    headers: { Authorization: `Bearer ${session.access_token}` },
  });

  if (response.error) throw new Error(response.error.message);
  return response.data;
}

// ─── Helper: Map LiveKit connection quality → string ─────────────────────

function mapConnectionQuality(q: LKConnectionQuality): string {
  switch (q) {
    case LKConnectionQuality.Excellent: return 'excellent';
    case LKConnectionQuality.Good: return 'good';
    case LKConnectionQuality.Poor: return 'poor';
    case LKConnectionQuality.Lost: return 'lost';
    default: return 'unknown';
  }
}

// ─── Core Media Service ──────────────────────────────────────────────────

class MediaService {
  private _room: Room | null = null;
  private statsInterval: ReturnType<typeof setInterval> | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private _token: string | null = null;
  private _serverUrl: string | null = null;

  // ── Accessors ──────────────────────────

  /** Current LiveKit Room instance (or null). */
  getRoom(): Room | null {
    return this._room;
  }

  /** The last token used to connect. */
  getToken(): string | null {
    return this._token;
  }

  /** The LiveKit server URL. */
  getServerUrl(): string | null {
    return this._serverUrl;
  }

  isConnected(): boolean {
    return this._room?.state === ConnectionState.Connected;
  }

  // ── Room Lifecycle ─────────────────────

  async joinChannel(config: {
    channelId: string;
    serverId: string;
    enableVideo?: boolean;
    enableAudio?: boolean;
  }): Promise<Room> {
    // Disconnect from existing room if any
    if (this._room) {
      await this.leaveChannel();
    }

    const store = useVoiceStore.getState();
    store.setConnectionState('connecting');

    // 1. Get token from Supabase edge function
    const { token, room: roomName, serverUrl } = await fetchVoiceToken({
      channelId: config.channelId,
      serverId: config.serverId,
      video: config.enableVideo,
    });

    this._token = token;
    this._serverUrl = serverUrl;

    // 2. Create a real LiveKit Room
    const roomOptions: RoomOptions = {
      adaptiveStream: true,
      dynacast: true,
      videoCaptureDefaults: {
        resolution: VideoPresets.h720.resolution,
      },
      publishDefaults: {
        simulcast: true,
        videoSimulcastLayers: [VideoPresets.h180, VideoPresets.h360],
      },
    };

    const room = new Room(roomOptions);
    this._room = room;

    // 3. Wire LiveKit events → Zustand store
    this.attachRoomEvents(room);

    // 4. Connect to the room
    try {
      await room.connect(serverUrl, token);
    } catch (err) {
      store.setConnectionState('failed');
      this._room = null;
      throw err;
    }

    // 5. Publish local tracks
    const lp = room.localParticipant;

    if (config.enableAudio !== false) {
      await lp.setMicrophoneEnabled(true);
    }
    if (config.enableVideo) {
      await lp.setCameraEnabled(true);
    }

    // 6. Update store
    store.setRoom(room);
    store.setChannelId(config.channelId);
    store.setServerId(config.serverId);
    store.setConnectionState('connected');
    store.setMuted(false);
    store.setDeafened(false);
    store.setVideoEnabled(!!config.enableVideo);

    // Sync initial participants to store
    this.syncParticipantsToStore(room);

    // Start stats collection
    this.startStatsCollection();

    return room;
  }

  async leaveChannel(): Promise<void> {
    const store = useVoiceStore.getState();

    // Stop stats
    this.stopStatsCollection();

    // Disconnect from LiveKit room
    if (this._room) {
      try {
        this._room.disconnect(true);
      } catch {
        // ignore disconnect errors
      }
      this._room.removeAllListeners();
      this._room = null;
    }

    // Clean up DB voice_state
    if (store.channelId) {
      const { data: { session } } = await supabase.auth.getSession();
      if (session) {
        await supabase
          .from('voice_states')
          .delete()
          .eq('user_id', session.user.id);
      }
    }

    this._token = null;
    this._serverUrl = null;

    // Reset store
    store.reset();
  }

  // ── Camera Controls ────────────────────

  async enableCamera(enabled: boolean): Promise<void> {
    const lp = this._room?.localParticipant;
    if (lp) {
      await lp.setCameraEnabled(enabled);
    }
    await this.updateVoiceState({ video_enabled: enabled });
    useVoiceStore.getState().setVideoEnabled(enabled);
  }

  async switchCamera(): Promise<void> {
    const lp = this._room?.localParticipant;
    if (lp) {
      const cameraPub = lp.getTrackPublication(Track.Source.Camera);
      if (cameraPub?.track) {
        // Toggle between front and back camera
        await (cameraPub.track as any).restartTrack?.({
          facingMode: useVoiceStore.getState().cameraFacing === 'front' ? 'environment' : 'user',
        });
      }
    }
    const store = useVoiceStore.getState();
    const newFacing = store.cameraFacing === 'front' ? 'back' : 'front';
    store.setCameraFacing(newFacing);
  }

  async setVideoQuality(quality: keyof typeof QUALITY_PRESETS): Promise<void> {
    const preset = QUALITY_PRESETS[quality];
    if (!preset) throw new Error(`Invalid quality preset: ${quality}`);

    const lp = this._room?.localParticipant;
    if (lp) {
      const cameraPub = lp.getTrackPublication(Track.Source.Camera);
      if (cameraPub?.track) {
        await (cameraPub.track as any).restartTrack?.({
          width: preset.width,
          height: preset.height,
          frameRate: preset.fps,
        });
      }
    }

    useVoiceStore.getState().setVideoQuality(quality);
  }

  // ── Screen Sharing ─────────────────────

  async startScreenShare(config?: {
    audio?: boolean;
    quality?: keyof typeof SCREEN_SHARE_PRESETS;
  }): Promise<void> {
    const lp = this._room?.localParticipant;
    if (lp) {
      await lp.setScreenShareEnabled(true, {
        audio: config?.audio ?? true,
      });
    }
    await this.updateVoiceState({ screen_sharing: true });
    useVoiceStore.getState().setScreenSharing(true);
  }

  async stopScreenShare(): Promise<void> {
    const lp = this._room?.localParticipant;
    if (lp) {
      await lp.setScreenShareEnabled(false);
    }

    const store = useVoiceStore.getState();
    if (store.activeStreamId) {
      await this.endStream(store.activeStreamId);
    }

    await this.updateVoiceState({ screen_sharing: false });
    store.setScreenSharing(false);
  }

  // ── Go Live (Stream) ──────────────────

  async startGoLive(config: StreamConfig): Promise<string> {
    const { token, streamId, serverUrl } = await fetchVoiceToken({
      channelId: config.channelId,
      serverId: config.serverId,
      screenShare: true,
      streamTitle: config.title,
      streamType: config.streamType,
      quality: config.quality,
    });

    // Start screen share with specified quality
    const qualityKey = config.quality || '720p30';
    await this.startScreenShare({ quality: qualityKey, audio: true });

    // Mark stream as live
    await supabase
      .from('streams')
      .update({ status: 'live' })
      .eq('id', streamId);

    const store = useVoiceStore.getState();
    store.setActiveStreamId(streamId!);
    store.setStreamTitle(config.title || '');

    return streamId!;
  }

  async endStream(streamId: string): Promise<void> {
    await supabase
      .from('streams')
      .update({ status: 'ended', ended_at: new Date().toISOString() })
      .eq('id', streamId);

    await this.stopScreenShare();

    const store = useVoiceStore.getState();
    store.setActiveStreamId(null);
    store.setStreamTitle('');
  }

  // ── Stream Viewing ─────────────────────

  async watchStream(streamId: string): Promise<void> {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) throw new Error('Not authenticated');

    await supabase.from('stream_viewers').upsert(
      {
        stream_id: streamId,
        user_id: session.user.id,
        joined_at: new Date().toISOString(),
        left_at: null,
      },
      { onConflict: 'stream_id,user_id' },
    );

    useVoiceStore.getState().setWatchingStreamId(streamId);
  }

  async stopWatchingStream(streamId: string): Promise<void> {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;

    await supabase
      .from('stream_viewers')
      .update({ left_at: new Date().toISOString() })
      .eq('stream_id', streamId)
      .eq('user_id', session.user.id);

    useVoiceStore.getState().setWatchingStreamId(null);
  }

  // ── Audio Controls ─────────────────────

  async setMicEnabled(enabled: boolean): Promise<void> {
    const lp = this._room?.localParticipant;
    if (lp) {
      await lp.setMicrophoneEnabled(enabled);
    }
    await this.updateVoiceState({ self_mute: !enabled });
    useVoiceStore.getState().setMuted(!enabled);
  }

  async setDeafened(deafened: boolean): Promise<void> {
    if (deafened && this._room) {
      // When deafened, mute all incoming audio at the subscriber level
      for (const participant of this._room.remoteParticipants.values()) {
        for (const pub of participant.trackPublications.values()) {
          if (pub.kind === Track.Kind.Audio && pub.track) {
            pub.track.detach();
          }
        }
      }
    } else if (!deafened && this._room) {
      // Re-attach all audio tracks
      for (const participant of this._room.remoteParticipants.values()) {
        for (const pub of participant.trackPublications.values()) {
          if (pub.kind === Track.Kind.Audio && pub.track) {
            pub.track.attach();
          }
        }
      }
    }

    await this.updateVoiceState({
      self_deaf: deafened,
      self_mute: deafened || useVoiceStore.getState().muted,
    });

    const store = useVoiceStore.getState();
    store.setDeafened(deafened);
    if (deafened) store.setMuted(true);
  }

  // ── Subscriber Quality Control ─────────

  setParticipantVideoQuality(
    participantId: string,
    quality: 'high' | 'medium' | 'low' | 'off',
  ): void {
    const store = useVoiceStore.getState();
    store.updateParticipant(participantId, {
      connectionQuality:
        quality === 'off' ? 'poor' : quality === 'low' ? 'fair' : 'good',
    });
  }

  // ── Room Event Wiring ─────────────────

  private attachRoomEvents(room: Room): void {
    const store = useVoiceStore.getState;

    room.on(RoomEvent.ParticipantConnected, (participant) => {
      const meta = this.parseMetadata(participant.metadata);
      store().addParticipant({
        id: participant.identity,
        userId: meta.userId || participant.identity,
        username: participant.name || meta.username || participant.identity,
        displayName: participant.name || meta.displayName || participant.identity,
        avatarUrl: meta.avatarUrl || null,
        metadata: meta,
        muted: false,
        deafened: false,
        speaking: false,
        audioEnabled: true,
        videoEnabled: false,
        screenSharing: false,
        isSpeaking: false,
        connectionQuality: 'good',
        tracks: [],
        video: false,
        streaming: false,
      });
    });

    room.on(RoomEvent.ParticipantDisconnected, (participant: RemoteParticipant) => {
      store().removeParticipant(participant.identity);
    });

    room.on(RoomEvent.TrackSubscribed, (track: RemoteTrack, publication: RemoteTrackPublication, participant: RemoteParticipant) => {
      const trackInfo = {
        source: publication.source as string,
        kind: track.kind,
        enabled: !publication.isMuted,
        muted: publication.isMuted,
      };
      store().updateParticipantTrack(participant.identity, trackInfo);
    });

    room.on(RoomEvent.TrackUnsubscribed, (_track: RemoteTrack, publication: RemoteTrackPublication, participant: RemoteParticipant) => {
      store().updateParticipantTrack(participant.identity, {
        source: publication.source as string,
        kind: _track.kind,
        enabled: false,
        muted: true,
      });
    });

    room.on(RoomEvent.TrackMuted, (publication: RemoteTrackPublication, participant: Participant) => {
      const source = publication.source as string;
      if (source === Track.Source.Microphone) {
        store().updateParticipant(participant.identity, { muted: true, audioEnabled: false });
      } else if (source === Track.Source.Camera) {
        store().updateParticipant(participant.identity, { videoEnabled: false, video: false });
      } else if (source === Track.Source.ScreenShare) {
        store().updateParticipant(participant.identity, { screenSharing: false, streaming: false });
      }
    });

    room.on(RoomEvent.TrackUnmuted, (publication: RemoteTrackPublication, participant: Participant) => {
      const source = publication.source as string;
      if (source === Track.Source.Microphone) {
        store().updateParticipant(participant.identity, { muted: false, audioEnabled: true });
      } else if (source === Track.Source.Camera) {
        store().updateParticipant(participant.identity, { videoEnabled: true, video: true });
      } else if (source === Track.Source.ScreenShare) {
        store().updateParticipant(participant.identity, { screenSharing: true, streaming: true });
      }
    });

    room.on(RoomEvent.ActiveSpeakersChanged, (speakers: Participant[]) => {
      const speakerIds = new Set(speakers.map((s) => s.identity));
      store().setActiveSpeakers(speakerIds);
    });

    room.on(RoomEvent.ConnectionQualityChanged, (quality: LKConnectionQuality, participant: Participant) => {
      store().updateParticipant(participant.identity, {
        connectionQuality: mapConnectionQuality(quality),
      });
    });

    room.on(RoomEvent.Reconnecting, () => {
      store().setConnectionState('reconnecting');
      this.reconnectAttempts++;
    });

    room.on(RoomEvent.Reconnected, () => {
      store().setConnectionState('connected');
      this.reconnectAttempts = 0;
    });

    room.on(RoomEvent.Disconnected, () => {
      store().setConnectionState('disconnected');
    });

    room.on(RoomEvent.LocalTrackPublished, (publication) => {
      const lp = room.localParticipant;
      if (!lp) return;
      const source = publication.source as string;
      if (source === Track.Source.Camera) {
        store().setVideoEnabled(true);
      } else if (source === Track.Source.ScreenShare) {
        store().setScreenSharing(true);
      }
    });

    room.on(RoomEvent.LocalTrackUnpublished, (publication) => {
      const source = publication.source as string;
      if (source === Track.Source.Camera) {
        store().setVideoEnabled(false);
      } else if (source === Track.Source.ScreenShare) {
        store().setScreenSharing(false);
      }
    });
  }

  // ── Sync all participants to store ─────

  private syncParticipantsToStore(room: Room): void {
    const store = useVoiceStore.getState();
    const participants = [];

    // Add local participant
    const lp = room.localParticipant;
    const localMeta = this.parseMetadata(lp.metadata);
    participants.push({
      id: lp.identity,
      userId: localMeta.userId || lp.identity,
      username: lp.name || localMeta.username || lp.identity,
      displayName: lp.name || localMeta.displayName || lp.identity,
      avatarUrl: localMeta.avatarUrl || null,
      metadata: localMeta,
      muted: lp.isMicrophoneEnabled === false,
      deafened: false,
      speaking: false,
      audioEnabled: lp.isMicrophoneEnabled !== false,
      videoEnabled: lp.isCameraEnabled === true,
      screenSharing: lp.isScreenShareEnabled === true,
      isSpeaking: false,
      connectionQuality: 'good',
      tracks: [],
      video: lp.isCameraEnabled === true,
      streaming: lp.isScreenShareEnabled === true,
    });

    // Add remote participants
    for (const [, rp] of room.remoteParticipants) {
      const meta = this.parseMetadata(rp.metadata);
      const hasCam = rp.getTrackPublication(Track.Source.Camera)?.isMuted === false;
      const hasScreen = rp.getTrackPublication(Track.Source.ScreenShare)?.isMuted === false;
      const hasMic = rp.getTrackPublication(Track.Source.Microphone)?.isMuted === false;

      participants.push({
        id: rp.identity,
        userId: meta.userId || rp.identity,
        username: rp.name || meta.username || rp.identity,
        displayName: rp.name || meta.displayName || rp.identity,
        avatarUrl: meta.avatarUrl || null,
        metadata: meta,
        muted: !hasMic,
        deafened: false,
        speaking: false,
        audioEnabled: !!hasMic,
        videoEnabled: !!hasCam,
        screenSharing: !!hasScreen,
        isSpeaking: false,
        connectionQuality: 'good',
        tracks: [],
        video: !!hasCam,
        streaming: !!hasScreen,
      });
    }

    store.setParticipants(participants);
  }

  // ── Stats ──────────────────────────────

  private startStatsCollection(): void {
    this.statsInterval = setInterval(async () => {
      const stats = await this.getMediaStats();
      useVoiceStore.getState().setMediaStats(stats);
    }, 2000);
  }

  private stopStatsCollection(): void {
    if (this.statsInterval) {
      clearInterval(this.statsInterval);
      this.statsInterval = null;
    }
  }

  async getMediaStats(): Promise<MediaStats> {
    // In production, pull real stats from room.getStats()
    return {
      outgoing: {},
      incoming: new Map(),
      networkQuality: this.isConnected() ? 'good' : 'poor',
    };
  }

  // ── Helpers ────────────────────────────

  private async updateVoiceState(updates: Record<string, unknown>): Promise<void> {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return;

    await supabase
      .from('voice_states')
      .update(updates)
      .eq('user_id', session.user.id);
  }

  private parseMetadata(metadata?: string): Record<string, any> {
    if (!metadata) return {};
    try {
      return JSON.parse(metadata);
    } catch {
      return {};
    }
  }
}

export const mediaService = new MediaService();
