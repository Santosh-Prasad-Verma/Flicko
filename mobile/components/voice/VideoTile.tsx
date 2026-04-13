/**
 * VideoTile — Individual participant video tile
 *
 * Renders a real LiveKit VideoTrack when a camera track is available,
 * otherwise falls back to an avatar placeholder.
 */
import React, { memo, useMemo } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import { Image } from 'expo-image';
import { useTheme } from '@/hooks/useTheme';
import { useVoiceStore } from '@/shared/stores/voiceStore';
import { ConnectionQualityIcon } from './ConnectionQualityIcon';
import { Ionicons } from '@expo/vector-icons';
import Animated, {
  useAnimatedStyle,
  withRepeat,
  withTiming,
  withSequence,
} from 'react-native-reanimated';
import { VideoTrack as LKVideoTrack } from '@livekit/react-native';
import { Track } from 'livekit-client';
import type { Room } from 'livekit-client';

interface Participant {
  id: string;
  name: string;
  avatarUrl?: string | null;
  videoEnabled?: boolean;
  screenSharing?: boolean;
  audioEnabled?: boolean;
  isSpeaking?: boolean;
  connectionQuality?: string;
  metadata?: Record<string, unknown>;
}

interface VideoTileProps {
  participant: Participant;
  size: 'small' | 'medium' | 'large';
  isSpeaking: boolean;
  showControls?: boolean;
  onPress?: () => void;
  onLongPress?: () => void;
}

export const VideoTile = memo(function VideoTile({
  participant,
  size,
  isSpeaking,
  showControls: _showControls = false,
  onPress,
  onLongPress,
}: VideoTileProps) {
  const { themeColors } = useTheme();
  const room = useVoiceStore((s) => s.room) as Room | null;

  // Resolve the LiveKit participant → camera track reference
  const trackRef = useMemo(() => {
    if (!room || !participant.videoEnabled) return undefined;

    const isLocal = room.localParticipant?.identity === participant.id;
    const lkParticipant = isLocal
      ? room.localParticipant
      : room.remoteParticipants?.get(participant.id);

    if (!lkParticipant) return undefined;

    const cameraPub = lkParticipant.getTrackPublication(Track.Source.Camera);
    if (!cameraPub?.track) return undefined;

    return {
      participant: lkParticipant,
      publication: cameraPub,
      source: Track.Source.Camera,
    };
  }, [room, participant.id, participant.videoEnabled]);

  const hasVideo = !!trackRef;
  const isLocal = room?.localParticipant?.identity === participant.id;

  // Speaking border animation
  const speakingStyle = useAnimatedStyle(() => ({
    borderColor: isSpeaking
      ? withRepeat(
          withSequence(
            withTiming('#43b581', { duration: 300 }),
            withTiming('#3ca374', { duration: 300 }),
          ),
          -1,
          true,
        )
      : 'transparent',
    borderWidth: isSpeaking ? 3 : 0,
  }));

  const sizeStyles = SIZE_MAP[size];
  const avatarSize = size === 'large' ? 80 : size === 'medium' ? 56 : 36;

  return (
    <Pressable onPress={onPress} onLongPress={onLongPress}>
      <Animated.View
        style={[
          styles.tile,
          sizeStyles.container,
          { backgroundColor: themeColors.bgTertiary, borderRadius: 12 },
          speakingStyle,
        ]}
      >
        {hasVideo ? (
          // Real LiveKit Video Feed
          <View style={styles.videoContainer}>
            <LKVideoTrack
              trackRef={trackRef}
              style={styles.video}
              objectFit="cover"
              mirror={isLocal}
              zOrder={isLocal ? 1 : 0}
            />

            {/* Overlay: name + indicators */}
            <View style={styles.videoOverlay}>
              <View style={[styles.nameBadge, { backgroundColor: 'rgba(0,0,0,0.6)' }]}>
                <Text style={[styles.nameText, { color: '#fff' }]} numberOfLines={1}>
                  {participant.name}
                  {isLocal ? ' (You)' : ''}
                </Text>
                {!participant.audioEnabled && (
                  <Ionicons name="mic-off" size={12} color="#ed4245" />
                )}
              </View>

              <ConnectionQualityIcon quality={participant.connectionQuality || 'unknown'} size={16} />
            </View>
          </View>
        ) : (
          // No Video — Show Avatar
          <View style={styles.avatarContainer}>
            {participant.avatarUrl ? (
              <Image
                source={{ uri: participant.avatarUrl }}
                style={[
                  styles.avatarImage,
                  { width: avatarSize, height: avatarSize, borderRadius: avatarSize / 2 },
                ]}
                contentFit="cover"
                cachePolicy="memory-disk"
              />
            ) : (
              <View
                style={[
                  styles.avatarPlaceholder,
                  { width: avatarSize, height: avatarSize, borderRadius: avatarSize / 2, backgroundColor: themeColors.accentPrimary },
                ]}
              >
                <Text style={styles.avatarInitial}>
                  {participant.name?.charAt(0)?.toUpperCase() || '?'}
                </Text>
              </View>
            )}
            <Text
              style={[
                styles.avatarName,
                { color: themeColors.textPrimary, fontSize: sizeStyles.fontSize },
              ]}
              numberOfLines={1}
            >
              {participant.name}
              {isLocal ? ' (You)' : ''}
            </Text>

            {/* Status icons */}
            <View style={styles.statusIcons}>
              {!participant.audioEnabled && (
                <View style={[styles.statusIcon, { backgroundColor: 'rgba(237,66,69,0.2)' }]}>
                  <Ionicons name="mic-off" size={14} color="#ed4245" />
                </View>
              )}
              {participant.screenSharing && (
                <View style={[styles.statusIcon, { backgroundColor: 'rgba(88,101,242,0.2)' }]}>
                  <Ionicons name="desktop-outline" size={14} color="#5865f2" />
                </View>
              )}
            </View>

            <ConnectionQualityIcon quality={participant.connectionQuality || 'unknown'} size={14} />
          </View>
        )}

        {/* Screen sharing indicator */}
        {participant.screenSharing && (
          <View style={[styles.screenShareBadge, { backgroundColor: '#5865f2' }]}>
            <Ionicons name="desktop-outline" size={10} color="#fff" />
            <Text style={styles.screenShareText}>Screen</Text>
          </View>
        )}
      </Animated.View>
    </Pressable>
  );
});

const SIZE_MAP = {
  small: {
    container: { minWidth: 60, minHeight: 60 } as const,
    fontSize: 10,
  },
  medium: {
    container: { minWidth: 120, minHeight: 120 } as const,
    fontSize: 12,
  },
  large: {
    container: { minWidth: 200, minHeight: 200, flex: 1 } as const,
    fontSize: 14,
  },
};

const styles = StyleSheet.create({
  tile: {
    flex: 1,
    overflow: 'hidden',
    position: 'relative',
  },
  videoContainer: {
    flex: 1,
    position: 'relative',
  },
  video: {
    flex: 1,
  },
  videoOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
    padding: 6,
  },
  nameBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
    maxWidth: '70%',
  },
  nameText: {
    fontSize: 11,
    fontFamily: 'gg-sans-semibold',
  },
  avatarContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 6,
    padding: 8,
  },
  avatarPlaceholder: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarImage: {
    backgroundColor: '#2B2D31',
  },
  avatarInitial: {
    color: '#fff',
    fontSize: 24,
    fontFamily: 'gg-sans-bold',
  },
  avatarName: {
    fontFamily: 'gg-sans-semibold',
    textAlign: 'center',
  },
  statusIcons: {
    flexDirection: 'row',
    gap: 4,
    position: 'absolute',
    bottom: 6,
    left: 6,
  },
  statusIcon: {
    width: 24,
    height: 24,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  screenShareBadge: {
    position: 'absolute',
    top: 6,
    left: 6,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
  },
  screenShareText: {
    fontSize: 9,
    fontFamily: 'gg-sans-bold',
    color: '#fff',
  },
});
