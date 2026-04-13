/**
 * VoiceChannelScreen (Enhanced with Video/Streaming)
 *
 * Full-screen voice channel UI with video grid, screen sharing,
 * Go Live streaming, layout toggles, and enhanced controls.
 *
 * Requirements: Feature 17 (Voice Channel UI) + Video/Streaming Plan
 */
import React, { memo, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
  StatusBar,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useVideoCall } from '../../../shared/hooks/useVideoCall';
import { useGoLive } from '../../../shared/hooks/useGoLive';
import { VideoGrid } from './VideoGrid';
import { VoiceVideoControls } from './VoiceVideoControls';
import { GoLiveModal } from './GoLiveModal';
import { ScreenShareViewer } from './ScreenShareViewer';
import { VideoLayoutToggle } from './VideoLayoutToggle';
import { GoLiveIndicator } from './GoLiveIndicator';
import { BotMusicControls } from '../music/BotMusicControls';
import { ErrorBoundary } from '../shared/ErrorBoundary';
import { useTheme } from '../../hooks/useTheme';
import { spacing } from '../../constants/Colors';

// ── Types ─────────────────────────────────────────────────────────────────

interface VoiceChannelScreenProps {
  channelId: string;
  channelName: string;
  serverId: string;
  onClose: () => void;
}

// ── Main Screen ───────────────────────────────────────────────────────────

export const VoiceChannelScreen = memo(function VoiceChannelScreen({
  channelId,
  channelName,
  serverId,
  onClose,
}: VoiceChannelScreenProps) {
  const { themeColors } = useTheme();
  const [goLiveModalVisible, setGoLiveModalVisible] = useState(false);
  const [isProcessingGoLive, setIsProcessingGoLive] = useState(false);

  // ── Video Call Hook ────────────────────────────────────────────────
  const {
    connectionState,
    muted,
    deafened,
    videoEnabled,
    screenSharing,
    participants,
    videoParticipants,
    screenSharers,
    elapsedTime,
    join,
    leave,
    toggleCamera,
    toggleMic,
    toggleDeafen,
    flipCamera,
    startScreenShare,
    stopScreenShare,
    videoLayout,
    focusedParticipantId,
    setLayout,
    focusParticipant,
  } = useVideoCall({
    channelId,
    serverId,
    autoJoin: true,
    enableAudio: true,
    enableVideo: false, // Start audio-only, like Discord
  });

  // ── Go Live Hook ──────────────────────────────────────────────────
  const {
    activeStreams,
    viewerCount,
    loading: goLiveLoading,
    isLive,
    goLive,
    endGoLive,
    watchStream,
  } = useGoLive(channelId);

  // ── Handle Disconnect ─────────────────────────────────────────────
  const handleDisconnect = useCallback(async () => {
    await leave();
    onClose();
  }, [leave, onClose]);

  // ── Handle Screen Share Toggle ────────────────────────────────────
  const handleToggleScreenShare = useCallback(async () => {
    if (screenSharing) {
      await stopScreenShare();
    } else {
      await startScreenShare('720p30');
    }
  }, [screenSharing, startScreenShare, stopScreenShare]);

  // ── Handle Go Live ────────────────────────────────────────────────
  const handleGoLive = useCallback(
    async (config: {
      title: string;
      streamType: 'screen' | 'application' | 'game' | 'camera';
      quality: string;
    }) => {
      if (isProcessingGoLive) return;
      setIsProcessingGoLive(true);
      try {
        await goLive(config);
        setGoLiveModalVisible(false);
      } finally {
        setIsProcessingGoLive(false);
      }
    },
    [goLive, isProcessingGoLive],
  );

  // ── Handle Participant Press (focus) ──────────────────────────────
  const handleParticipantPress = useCallback(
    (participantId: string) => {
      if (focusedParticipantId === participantId) {
        focusParticipant(null);
        setLayout('grid');
      } else {
        focusParticipant(participantId);
      }
    },
    [focusedParticipantId, focusParticipant, setLayout],
  );

  // ── Handle Participant Long Press ─────────────────────────────────
  const handleParticipantLongPress = useCallback((_participantId: string) => {
    // TODO: Show participant context menu (mute, volume, profile, etc.)
  }, []);

  // Determine if we should show screen share viewer
  const primaryScreenSharer = screenSharers[0];
  const showScreenShareViewer = !!primaryScreenSharer && videoLayout !== 'grid';

  // ── Connecting state ──────────────────────────────────────────────
  if (connectionState === 'connecting') {
    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={styles.connectingContainer}>
          <ActivityIndicator size="large" color={themeColors.accentPrimary} />
          <Text style={[styles.connectingText, { color: themeColors.textSecondary }]}>
            Connecting to {channelName}...
          </Text>
        </View>
      </View>
    );
  }

  return (
    <ErrorBoundary>
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <StatusBar barStyle="light-content" />

        {/* Header */}
        <View style={[styles.header, { borderBottomColor: themeColors.border }]}>
          <Pressable onPress={onClose} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="chevron-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <View style={styles.headerInfo}>
            <Ionicons name="volume-high" size={18} color={themeColors.textMuted} />
            <Text style={[styles.channelName, { color: themeColors.textPrimary }]}>
              {channelName}
            </Text>
          </View>
          <Text style={[styles.participantCount, { color: themeColors.textMuted }]}>
            {participants.length} {participants.length === 1 ? 'user' : 'users'}
          </Text>
        </View>

        {/* Live indicator — own stream */}
        {isLive && (
          <GoLiveIndicator viewerCount={viewerCount} onEndStream={endGoLive} />
        )}

        {/* Active streams from other users */}
        {activeStreams
          .filter((s) => s.status === 'live')
          .map((stream) => (
            <GoLiveIndicator
              key={stream.id}
              viewerCount={stream.viewer_count}
              streamerName={(stream as any).user?.username}
              isOwnStream={false}
              onWatch={() => watchStream(stream.id)}
            />
          ))}

        {/* Layout toggle */}
        <View style={styles.layoutToggle}>
          <VideoLayoutToggle
            currentLayout={videoLayout}
            onLayoutChange={setLayout}
            hasScreenShare={screenSharers.length > 0}
          />
        </View>

        {/* Main Content: Video Grid or Screen Share Viewer */}
        <View style={styles.mainContent}>
          {showScreenShareViewer ? (
            <ScreenShareViewer
              participantId={primaryScreenSharer.id}
              participantName={primaryScreenSharer.name}
              showViewerCount={
                !!activeStreams.find(
                  (s) =>
                    s.user_id === primaryScreenSharer.id && s.status === 'live',
                )
              }
              viewerCount={
                activeStreams.find(
                  (s) => s.user_id === primaryScreenSharer.id,
                )?.viewer_count || 0
              }
            />
          ) : participants.length > 0 ? (
            <VideoGrid
              participants={participants}
              layout={videoLayout}
              focusedParticipantId={focusedParticipantId}
              onParticipantPress={handleParticipantPress}
              onParticipantLongPress={handleParticipantLongPress}
            />
          ) : (
            <View style={styles.emptyState}>
              <Ionicons name="people-outline" size={48} color={themeColors.textMuted} />
              <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
                No one else is here yet
              </Text>
            </View>
          )}
        </View>

        {/* Music Controls (Real-time synced) */}
        <BotMusicControls serverId={serverId} channelId={channelId} />

        {/* Bottom Controls */}
        <VoiceVideoControls
          muted={muted}
          deafened={deafened}
          videoEnabled={videoEnabled}
          screenSharing={screenSharing}
          cameraFacing="front"
          connectionState={connectionState}
          elapsedTime={elapsedTime}
          onToggleMic={toggleMic}
          onToggleDeafen={toggleDeafen}
          onToggleCamera={toggleCamera}
          onFlipCamera={flipCamera}
          onToggleScreenShare={handleToggleScreenShare}
          onGoLive={() => !isProcessingGoLive && setGoLiveModalVisible(true)}
          onDisconnect={handleDisconnect}
          onOpenSettings={() => {
            /* TODO: navigate to voice settings */
          }}
        />

        {/* Go Live Modal */}
        <GoLiveModal
          visible={goLiveModalVisible}
          onClose={() => setGoLiveModalVisible(false)}
          onGoLive={handleGoLive}
          loading={goLiveLoading}
        />
      </View>
    </ErrorBoundary>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  connectingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: spacing.md,
  },
  connectingText: {
    fontSize: 16,
    fontFamily: 'gg-sans-medium',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
  },
  backBtn: {
    padding: 4,
    marginRight: spacing.sm,
  },
  headerInfo: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  channelName: {
    fontSize: 17,
    fontFamily: 'gg-sans-semibold',
  },
  participantCount: {
    fontSize: 13,
  },
  layoutToggle: {
    position: 'absolute',
    top: 56,
    right: 12,
    zIndex: 10,
  },
  mainContent: {
    flex: 1,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: spacing.md,
  },
  emptyText: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
  },
});
