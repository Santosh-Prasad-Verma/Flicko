/**
 * StreamViewerList — List of current stream viewers
 */
import React from 'react';
import { View, Text, StyleSheet, FlatList, Pressable } from 'react-native';
import { useTheme } from '@/hooks/useTheme';
import { Ionicons } from '@expo/vector-icons';
import type { StreamViewer } from '@services/streamService';

interface StreamViewerListProps {
  viewers: StreamViewer[];
  viewerCount: number;
  onClose?: () => void;
}

export function StreamViewerList({ viewers, viewerCount, onClose }: StreamViewerListProps) {
  const { themeColors } = useTheme();

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <Ionicons name="eye-outline" size={18} color={themeColors.textPrimary} />
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
            Viewers ({viewerCount})
          </Text>
        </View>
        {onClose && (
          <Pressable onPress={onClose} hitSlop={8}>
            <Ionicons name="close" size={22} color={themeColors.textSecondary} />
          </Pressable>
        )}
      </View>

      {/* Viewer List */}
      <FlatList
        data={viewers}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={[styles.viewerRow, { borderBottomColor: themeColors.border }]}>
            <View
              style={[styles.avatar, { backgroundColor: themeColors.accentPrimary }]}
            >
              <Text style={styles.avatarText}>
                {item.user?.username?.charAt(0)?.toUpperCase() || '?'}
              </Text>
            </View>
            <View style={styles.viewerInfo}>
              <Text style={[styles.viewerName, { color: themeColors.textPrimary }]}>
                {item.user?.username || 'Unknown'}
              </Text>
              <Text style={[styles.viewerTime, { color: themeColors.textMuted }]}>
                Watching since {new Date(item.joined_at).toLocaleTimeString()}
              </Text>
            </View>
          </View>
        )}
        ListEmptyComponent={
          <View style={styles.empty}>
            <Ionicons name="eye-off-outline" size={32} color={themeColors.textMuted} />
            <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
              No viewers yet
            </Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  headerTitle: {
    fontSize: 16,
    fontFamily: 'gg-sans-bold',
  },
  viewerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  avatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    color: '#fff',
    fontSize: 16,
    fontFamily: 'gg-sans-bold',
  },
  viewerInfo: {
    flex: 1,
    gap: 2,
  },
  viewerName: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  viewerTime: {
    fontSize: 12,
  },
  empty: {
    alignItems: 'center',
    justifyContent: 'center',
    padding: 40,
    gap: 8,
  },
  emptyText: {
    fontSize: 14,
  },
});
