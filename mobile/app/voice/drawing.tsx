/**
 * Drawing Screen
 *
 * Allows users to draw on a screen share during voice calls.
 * Accessed from the voice channel screen share viewer.
 *
 * Route: /voice/drawing?shareId=...&channelId=...
 */
import React, { useCallback, useState } from 'react';
import { View, Text, StyleSheet, Pressable, Alert } from 'react-native';
import { Stack, useLocalSearchParams, router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { DrawingCanvas } from '../../components/voice/DrawingCanvas';
import { supabase } from '../../services/supabase';
import { useAuthStore, type AuthStore } from '@stores/authStore';

export default function DrawingScreen() {
  const { themeColors } = useTheme();
  const insets = useSafeAreaInsets();
  const { shareId, channelId } = useLocalSearchParams<{
    shareId: string;
    channelId: string;
  }>();
  const user = useAuthStore((s: AuthStore) => s.user);
  const [drawingEnabled, setDrawingEnabled] = useState(true);

  const handleStrokeComplete = useCallback(async (stroke: {
    tool: string;
    color: string;
    width: number;
    opacity: number;
    points: { x: number; y: number }[];
  }) => {
    if (!shareId || !user?.id) return;

    try {
      await supabase.from('drawing_strokes').insert({
        screen_share_id: shareId,
        user_id: user.id,
        tool: stroke.tool,
        color: stroke.color,
        width: stroke.width,
        opacity: stroke.opacity,
        coordinates: { points: stroke.points },
      });
    } catch (err) {
      console.error('[Drawing] Failed to save stroke:', err);
    }
  }, [shareId, user?.id]);

  const handleClear = useCallback(async () => {
    if (!shareId) return;
    try {
      await supabase
        .from('drawing_strokes')
        .delete()
        .eq('screen_share_id', shareId)
        .eq('user_id', user?.id);
    } catch (err) {
      console.error('[Drawing] Failed to clear strokes:', err);
    }
  }, [shareId, user?.id]);

  if (!shareId) {
    return (
      <>
        <Stack.Screen options={{ headerShown: false }} />
        <View style={[styles.container, styles.center, { backgroundColor: themeColors.bgPrimary }]}>
          <Ionicons name="alert-circle-outline" size={48} color={themeColors.textMuted} />
          <Text style={[styles.errorText, { color: themeColors.textMuted }]}>
            No active screen share found
          </Text>
          <Pressable
            style={[styles.backButton, { backgroundColor: themeColors.accentPrimary }]}
            onPress={() => router.back()}
          >
            <Text style={styles.backButtonText}>Go Back</Text>
          </Pressable>
        </View>
      </>
    );
  }

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: '#000000' }]}>
        {/* Top bar */}
        <View style={[styles.header, { paddingTop: insets.top + 8 }]}>
          <Pressable onPress={() => router.back()} hitSlop={12}>
            <Ionicons name="arrow-back" size={24} color="#FFFFFF" />
          </Pressable>
          <Text style={styles.headerTitle}>Draw on Screen Share</Text>
          <Pressable
            onPress={() => setDrawingEnabled(v => !v)}
            hitSlop={12}
          >
            <Ionicons
              name={drawingEnabled ? 'pencil' : 'eye-outline'}
              size={22}
              color={drawingEnabled ? themeColors.accentPrimary : '#FFFFFF'}
            />
          </Pressable>
        </View>

        {/* Drawing canvas overlay */}
        <DrawingCanvas
          screenShareId={shareId}
          onStrokeComplete={handleStrokeComplete}
          onClear={handleClear}
          enabled={drawingEnabled}
        />
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  center: {
    alignItems: 'center',
    justifyContent: 'center',
    gap: 16,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingBottom: 8,
    zIndex: 10,
  },
  headerTitle: {
    color: '#FFFFFF',
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
  },
  errorText: {
    fontSize: 16,
    fontFamily: 'gg-sans-medium',
    textAlign: 'center',
  },
  backButton: {
    paddingHorizontal: 24,
    paddingVertical: 10,
    borderRadius: 8,
    marginTop: 8,
  },
  backButtonText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
  },
});
