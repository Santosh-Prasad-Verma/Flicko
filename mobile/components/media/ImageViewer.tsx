/**
 * ImageViewer Component
 *
 * Full-screen image viewer with pinch-to-zoom, double-tap zoom,
 * swipe-to-dismiss, and share/save actions.
 *
 * Requirements: Feature 12 (Media Players)
 */
import React, { memo, useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Dimensions,
  Share,
  StatusBar,
  Modal,
} from 'react-native';
import { Image } from 'expo-image';
import * as FileSystem from 'expo-file-system/legacy';
import { Ionicons } from '@expo/vector-icons';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
  runOnJS,
} from 'react-native-reanimated';
import {
  Gesture,
  GestureDetector,
  GestureHandlerRootView,
} from 'react-native-gesture-handler';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

interface ImageViewerProps {
  visible: boolean;
  imageUrl: string;
  filename?: string;
  width?: number;
  height?: number;
  onClose: () => void;
}

export const ImageViewer = memo(function ImageViewer({
  visible,
  imageUrl,
  filename,
  width: imgWidth,
  height: imgHeight,
  onClose,
}: ImageViewerProps) {
  const [saving, setSaving] = useState(false);

  // Animated values
  const scale = useSharedValue(1);
  const translationX = useSharedValue(0);
  const translationY = useSharedValue(0);
  const savedScale = useSharedValue(1);
  const savedTranslationX = useSharedValue(0);
  const savedTranslationY = useSharedValue(0);

  const handleClose = useCallback(() => {
    scale.value = withTiming(1, { duration: 200 });
    translationX.value = withTiming(0, { duration: 200 });
    translationY.value = withTiming(0, { duration: 200 });
    onClose();
  }, [onClose, scale, translationX, translationY]);

  const handleShare = useCallback(async () => {
    try {
      await Share.share({ url: imageUrl, message: imageUrl });
    } catch {}
  }, [imageUrl]);

  const handleSave = useCallback(async () => {
    setSaving(true);
    try {
      const ext = filename?.split('.').pop() || 'jpg';
      const localUri = `${FileSystem.documentDirectory}${filename || `image_${Date.now()}.${ext}`}`;
      await FileSystem.downloadAsync(imageUrl, localUri);
      // In a full implementation, we'd save to camera roll via expo-media-library
    } catch (err) {
      console.error('[ImageViewer] save error:', err);
    } finally {
      setSaving(false);
    }
  }, [imageUrl, filename]);

  // Pinch gesture
  const pinchGesture = Gesture.Pinch()
    .onUpdate((e) => {
      scale.value = savedScale.value * e.scale;
    })
    .onEnd(() => {
      if (scale.value < 1) {
        scale.value = withSpring(1);
        savedScale.value = 1;
      } else if (scale.value > 5) {
        scale.value = withSpring(5);
        savedScale.value = 5;
      } else {
        savedScale.value = scale.value;
      }
    });

  // Pan gesture
  const panGesture = Gesture.Pan()
    .onUpdate((e) => {
      translationX.value = savedTranslationX.value + e.translationX;
      translationY.value = savedTranslationY.value + e.translationY;
    })
    .onEnd((e) => {
      savedTranslationX.value = translationX.value;
      savedTranslationY.value = translationY.value;

      // Swipe down to dismiss (when not zoomed)
      if (scale.value <= 1.1 && Math.abs(e.translationY) > 100) {
        runOnJS(handleClose)();
      }

      // Snap back if zoomed out
      if (scale.value <= 1) {
        translationX.value = withSpring(0);
        translationY.value = withSpring(0);
        savedTranslationX.value = 0;
        savedTranslationY.value = 0;
      }
    });

  // Double tap to zoom
  const doubleTapGesture = Gesture.Tap()
    .numberOfTaps(2)
    .onStart(() => {
      if (scale.value > 1.5) {
        scale.value = withSpring(1);
        savedScale.value = 1;
        translationX.value = withSpring(0);
        translationY.value = withSpring(0);
        savedTranslationX.value = 0;
        savedTranslationY.value = 0;
      } else {
        scale.value = withSpring(2.5);
        savedScale.value = 2.5;
      }
    });

  const composedGesture = Gesture.Simultaneous(
    pinchGesture,
    panGesture,
    doubleTapGesture,
  );

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translationX.value },
      { translateY: translationY.value },
      { scale: scale.value },
    ],
  }));

  // Calculate image dimensions
  const aspectRatio = imgWidth && imgHeight ? imgWidth / imgHeight : 1;
  const displayWidth = SCREEN_WIDTH;
  const displayHeight = displayWidth / aspectRatio;

  return (
    <Modal
      visible={visible}
      animationType="fade"
      transparent
      statusBarTranslucent
      onRequestClose={handleClose}
    >
      <StatusBar barStyle="light-content" />
      <GestureHandlerRootView style={styles.container}>
        {/* Background */}
        <View style={styles.backdrop} />

        {/* Top bar */}
        <View style={styles.topBar}>
          <Pressable onPress={handleClose} hitSlop={12} style={styles.topBarBtn}>
            <Ionicons name="close" size={24} color="#FFFFFF" />
          </Pressable>
          {filename && (
            <Text style={styles.filename} numberOfLines={1}>
              {filename}
            </Text>
          )}
          <View style={styles.topBarActions}>
            <Pressable onPress={handleShare} hitSlop={12} style={styles.topBarBtn}>
              <Ionicons name="share-outline" size={22} color="#FFFFFF" />
            </Pressable>
            <Pressable onPress={handleSave} hitSlop={12} style={styles.topBarBtn}>
              <Ionicons
                name={saving ? 'hourglass-outline' : 'download-outline'}
                size={22}
                color="#FFFFFF"
              />
            </Pressable>
          </View>
        </View>

        {/* Image */}
        <GestureDetector gesture={composedGesture}>
          <Animated.View style={[styles.imageContainer, animatedStyle]}>
            <Image
              source={{ uri: imageUrl }}
              style={{
                width: displayWidth,
                height: Math.min(displayHeight, SCREEN_HEIGHT * 0.8),
              }}
              contentFit="contain"
            />
          </Animated.View>
        </GestureDetector>
      </GestureHandlerRootView>
    </Modal>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: '#000000',
  },
  topBar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    flexDirection: 'row',
    alignItems: 'center',
    paddingTop: 50,
    paddingHorizontal: 16,
    paddingBottom: 12,
    zIndex: 10,
    backgroundColor: 'rgba(0,0,0,0.4)',
  },
  topBarBtn: {
    padding: 8,
  },
  topBarActions: {
    flexDirection: 'row',
    gap: 8,
  },
  filename: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
    marginHorizontal: 12,
  },
  imageContainer: {
    justifyContent: 'center',
    alignItems: 'center',
  },
});
