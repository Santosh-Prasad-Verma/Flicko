/**
 * VideoGrid — Dynamic grid layout for video participants
 */
import React, { useMemo } from 'react';
import { View, StyleSheet, Dimensions, Pressable } from 'react-native';
import { useTheme } from '@/hooks/useTheme';
import { VideoTile } from './VideoTile';
import { ScreenShareViewer } from './ScreenShareViewer';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

export type VideoLayout = 'grid' | 'focus' | 'sidebar';

interface Participant {
  id: string;
  name: string;
  videoEnabled?: boolean;
  screenSharing?: boolean;
  audioEnabled?: boolean;
  isSpeaking?: boolean;
  connectionQuality?: string;
  metadata?: Record<string, unknown>;
}

interface VideoGridProps {
  participants: Participant[];
  layout: VideoLayout;
  focusedParticipantId: string | null;
  onParticipantPress: (id: string) => void;
  onParticipantLongPress: (id: string) => void;
}

export function VideoGrid({
  participants,
  layout,
  focusedParticipantId,
  onParticipantPress,
  onParticipantLongPress,
}: VideoGridProps) {
  const { themeColors } = useTheme();

  const screenSharers = participants.filter((p) => p.screenSharing);
  const videoParticipants = participants.filter((p) => !p.screenSharing || p.videoEnabled);

  const gridConfig = useMemo(() => {
    return calculateGridLayout(videoParticipants.length, layout, focusedParticipantId, screenSharers.length > 0);
  }, [videoParticipants.length, layout, focusedParticipantId, screenSharers.length]);

  // Screen Share Layout
  if (screenSharers.length > 0 && layout !== 'grid') {
    const primaryScreenSharer = screenSharers[0];

    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={styles.screenShareMain}>
          <ScreenShareViewer
            participantId={primaryScreenSharer.id}
            participantName={primaryScreenSharer.name}
          />
        </View>

        <View style={[styles.sidebar, { backgroundColor: themeColors.bgSecondary }]}>
          {videoParticipants.map((p) => (
            <VideoTile
              key={p.id}
              participant={p}
              size="small"
              isSpeaking={p.isSpeaking ?? false}
              onPress={() => onParticipantPress(p.id)}
              onLongPress={() => onParticipantLongPress(p.id)}
            />
          ))}
        </View>
      </View>
    );
  }

  // Focus Layout
  if (layout === 'focus' && focusedParticipantId) {
    const focused = participants.find((p) => p.id === focusedParticipantId);
    const others = participants.filter((p) => p.id !== focusedParticipantId);

    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {focused && (
          <View style={styles.focusMain}>
            <VideoTile
              participant={focused}
              size="large"
              isSpeaking={focused.isSpeaking ?? false}
              showControls
              onPress={() => onParticipantPress(focused.id)}
              onLongPress={() => onParticipantLongPress(focused.id)}
            />
          </View>
        )}
        <View style={styles.focusStrip}>
          {others.map((p) => (
            <VideoTile
              key={p.id}
              participant={p}
              size="small"
              isSpeaking={p.isSpeaking ?? false}
              onPress={() => onParticipantPress(p.id)}
              onLongPress={() => onParticipantLongPress(p.id)}
            />
          ))}
        </View>
      </View>
    );
  }

  // Grid Layout (default)
  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      <View style={[styles.grid, { flexWrap: 'wrap' }]}>
        {videoParticipants.map((p) => (
          <View
            key={p.id}
            style={[
              styles.gridCell,
              {
                width: gridConfig.cellWidth,
                height: gridConfig.cellHeight,
                padding: gridConfig.gap / 2,
              },
            ]}
          >
            <VideoTile
              participant={p}
              size={gridConfig.tileSize}
              isSpeaking={p.isSpeaking ?? false}
              onPress={() => onParticipantPress(p.id)}
              onLongPress={() => onParticipantLongPress(p.id)}
            />
          </View>
        ))}
      </View>
    </View>
  );
}

// ── Grid Layout Calculator ──

interface GridLayout {
  columns: number;
  rows: number;
  cellWidth: number;
  cellHeight: number;
  gap: number;
  tileSize: 'small' | 'medium' | 'large';
}

function calculateGridLayout(
  count: number,
  _layout: VideoLayout,
  _focusedId: string | null,
  _hasScreenShare: boolean,
): GridLayout {
  const gap = 4;
  const availableWidth = SCREEN_WIDTH - gap * 2;
  const availableHeight = SCREEN_HEIGHT - 200;

  let columns: number;
  let tileSize: 'small' | 'medium' | 'large';

  if (count <= 1) {
    columns = 1;
    tileSize = 'large';
  } else if (count <= 4) {
    columns = 2;
    tileSize = 'medium';
  } else if (count <= 9) {
    columns = 3;
    tileSize = 'small';
  } else if (count <= 16) {
    columns = 4;
    tileSize = 'small';
  } else {
    columns = 5;
    tileSize = 'small';
  }

  const rows = Math.ceil(count / columns);
  const cellWidth = availableWidth / columns;
  const cellHeight = Math.min(availableHeight / rows, cellWidth * (9 / 16));

  return { columns, rows, cellWidth, cellHeight, gap, tileSize };
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  grid: {
    flex: 1,
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 2,
  },
  gridCell: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  screenShareMain: {
    flex: 1,
  },
  sidebar: {
    width: 100,
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    paddingVertical: 4,
    gap: 4,
    alignItems: 'center',
  },
  focusMain: {
    flex: 1,
    padding: 4,
  },
  focusStrip: {
    height: 100,
    flexDirection: 'row',
    gap: 4,
    paddingHorizontal: 4,
    paddingBottom: 4,
  },
});
