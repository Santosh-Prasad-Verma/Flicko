/**
 * GoLiveIndicator — Live badge + viewer count overlay
 */
import React from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';

interface GoLiveIndicatorProps {
  viewerCount: number;
  streamerName?: string;
  isOwnStream?: boolean;
  onEndStream?: () => void;
  onWatch?: () => void;
}

export function GoLiveIndicator({
  viewerCount,
  streamerName,
  isOwnStream = true,
  onEndStream,
  onWatch,
}: GoLiveIndicatorProps) {
  return (
    <Animated.View entering={FadeIn.duration(200)} exiting={FadeOut.duration(200)} style={styles.container}>
      <View style={styles.leftSection}>
        <View style={styles.liveBadge}>
          <View style={styles.liveDot} />
          <Text style={styles.liveText}>LIVE</Text>
        </View>

        {streamerName && !isOwnStream && (
          <Text style={styles.streamerName} numberOfLines={1}>
            {streamerName}
          </Text>
        )}

        <View style={styles.viewerBadge}>
          <Ionicons name="eye-outline" size={12} color="#fff" />
          <Text style={styles.viewerText}>{viewerCount}</Text>
        </View>
      </View>

      <View style={styles.rightSection}>
        {isOwnStream && onEndStream ? (
          <Pressable onPress={onEndStream} style={styles.endButton} hitSlop={8}>
            <Ionicons name="close" size={16} color="#fff" />
            <Text style={styles.endText}>End</Text>
          </Pressable>
        ) : onWatch ? (
          <Pressable onPress={onWatch} style={styles.watchButton} hitSlop={8}>
            <Ionicons name="play" size={14} color="#fff" />
            <Text style={styles.watchText}>Watch</Text>
          </Pressable>
        ) : null}
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    backgroundColor: 'rgba(237,66,69,0.9)',
    marginHorizontal: 12,
    marginTop: 8,
    borderRadius: 8,
  },
  leftSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    flex: 1,
  },
  liveBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#fff',
  },
  liveText: {
    color: '#fff',
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
  },
  streamerName: {
    color: 'rgba(255,255,255,0.9)',
    fontSize: 12,
    fontFamily: 'gg-sans-semibold',
    flex: 1,
  },
  viewerBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: 'rgba(0,0,0,0.3)',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 8,
  },
  viewerText: {
    color: '#fff',
    fontSize: 11,
    fontFamily: 'gg-sans-semibold',
  },
  rightSection: {
    marginLeft: 8,
  },
  endButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(0,0,0,0.3)',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 6,
  },
  endText: {
    color: '#fff',
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
  },
  watchButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(255,255,255,0.2)',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 6,
  },
  watchText: {
    color: '#fff',
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
  },
});
