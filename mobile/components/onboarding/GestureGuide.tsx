/**
 * Gesture Guide Overlay (Feature 41)
 *
 * First-time onboarding overlay showing available gestures:
 * - Swipe right → open channel list
 * - Swipe left → open member list
 * - Long-press message → actions
 * - Double-tap message → quick react
 * - Pinch → media zoom
 * - Swipe down → dismiss modal
 */
import React, { memo, useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Modal,
  Dimensions,
  ScrollView,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withSequence,
  withTiming,
  withDelay,
  Easing,
  FadeIn,
  FadeOut,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';

const GESTURE_GUIDE_KEY = '@flicko/gesture_guide_seen';
const { width: SCREEN_WIDTH } = Dimensions.get('window');

interface GestureItem {
  icon: keyof typeof Ionicons.glyphMap;
  gesture: string;
  description: string;
  animation: 'swipeRight' | 'swipeLeft' | 'longPress' | 'doubleTap' | 'pinch' | 'swipeDown';
}

const GESTURES: GestureItem[] = [
  {
    icon: 'arrow-forward',
    gesture: 'Swipe Right',
    description: 'Open the channel list and server sidebar',
    animation: 'swipeRight',
  },
  {
    icon: 'arrow-back',
    gesture: 'Swipe Left',
    description: 'Open the member list',
    animation: 'swipeLeft',
  },
  {
    icon: 'finger-print',
    gesture: 'Long Press Message',
    description: 'Open message actions (reply, edit, delete, react)',
    animation: 'longPress',
  },
  {
    icon: 'copy-outline',
    gesture: 'Double Tap Message',
    description: 'Quick-react with your default emoji',
    animation: 'doubleTap',
  },
  {
    icon: 'expand-outline',
    gesture: 'Pinch on Media',
    description: 'Zoom in on images and videos',
    animation: 'pinch',
  },
  {
    icon: 'chevron-down',
    gesture: 'Swipe Down',
    description: 'Dismiss modals and overlays',
    animation: 'swipeDown',
  },
];

const GestureAnimatedIcon = memo(function GestureAnimatedIcon({
  animation,
}: {
  animation: GestureItem['animation'];
}) {
  const translateX = useSharedValue(0);
  const translateY = useSharedValue(0);
  const scale = useSharedValue(1);

  useEffect(() => {
    switch (animation) {
      case 'swipeRight':
        translateX.value = withRepeat(
          withSequence(
            withTiming(16, { duration: 600, easing: Easing.inOut(Easing.ease) }),
            withTiming(0, { duration: 600, easing: Easing.inOut(Easing.ease) })
          ),
          -1,
          false
        );
        break;
      case 'swipeLeft':
        translateX.value = withRepeat(
          withSequence(
            withTiming(-16, { duration: 600, easing: Easing.inOut(Easing.ease) }),
            withTiming(0, { duration: 600, easing: Easing.inOut(Easing.ease) })
          ),
          -1,
          false
        );
        break;
      case 'longPress':
        scale.value = withRepeat(
          withSequence(
            withTiming(0.85, { duration: 500 }),
            withDelay(400, withTiming(1, { duration: 300 }))
          ),
          -1,
          false
        );
        break;
      case 'doubleTap':
        scale.value = withRepeat(
          withSequence(
            withTiming(0.8, { duration: 150 }),
            withTiming(1, { duration: 150 }),
            withDelay(100, withTiming(0.8, { duration: 150 })),
            withTiming(1, { duration: 150 }),
            withDelay(400, withTiming(1, { duration: 1 }))
          ),
          -1,
          false
        );
        break;
      case 'pinch':
        scale.value = withRepeat(
          withSequence(
            withTiming(1.25, { duration: 600, easing: Easing.inOut(Easing.ease) }),
            withTiming(1, { duration: 600, easing: Easing.inOut(Easing.ease) })
          ),
          -1,
          false
        );
        break;
      case 'swipeDown':
        translateY.value = withRepeat(
          withSequence(
            withTiming(10, { duration: 500, easing: Easing.inOut(Easing.ease) }),
            withTiming(0, { duration: 500, easing: Easing.inOut(Easing.ease) })
          ),
          -1,
          false
        );
        break;
    }
  }, [animation]);

  const animStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { scale: scale.value },
    ],
  }));

  return (
    <Animated.View style={[styles.animCircle, animStyle]}>
      <View style={styles.fingerDot} />
    </Animated.View>
  );
});

interface GestureGuideProps {
  /** Force show (e.g. from settings) */
  forceShow?: boolean;
  onDismiss?: () => void;
}

/**
 * Shows gesture guide overlay on first launch or when triggered from settings.
 */
export const GestureGuide = memo(function GestureGuide({
  forceShow = false,
  onDismiss,
}: GestureGuideProps) {
  const [visible, setVisible] = useState(false);
  const [page, setPage] = useState(0);

  useEffect(() => {
    if (forceShow) {
      setVisible(true);
      setPage(0);
      return;
    }
    // Auto-show on first launch
    AsyncStorage.getItem(GESTURE_GUIDE_KEY).then((seen) => {
      if (!seen) {
        setVisible(true);
        setPage(0);
      }
    });
  }, [forceShow]);

  const handleDismiss = useCallback(async () => {
    await AsyncStorage.setItem(GESTURE_GUIDE_KEY, '1');
    setVisible(false);
    onDismiss?.();
  }, [onDismiss]);

  const handleNext = useCallback(() => {
    if (page < GESTURES.length - 1) {
      setPage((p) => p + 1);
    } else {
      handleDismiss();
    }
  }, [page, handleDismiss]);

  const handlePrev = useCallback(() => {
    setPage((p) => Math.max(0, p - 1));
  }, []);

  if (!visible) return null;

  const gesture = GESTURES[page];
  const isLast = page === GESTURES.length - 1;

  return (
    <Modal
      transparent
      animationType="fade"
      visible={visible}
      onRequestClose={handleDismiss}
    >
      <View style={styles.backdrop}>
        <Animated.View
          key={page}
          entering={FadeIn.duration(300)}
          style={styles.card}
        >
          <TouchableOpacity style={styles.skipBtn} onPress={handleDismiss}>
            <Text style={styles.skipText}>Skip</Text>
          </TouchableOpacity>

          <View style={styles.gestureVisual}>
            <Ionicons name={gesture.icon} size={40} color="#5865F2" />
            <GestureAnimatedIcon animation={gesture.animation} />
          </View>

          <Text style={styles.gestureTitle}>{gesture.gesture}</Text>
          <Text style={styles.gestureDesc}>{gesture.description}</Text>

          {/* Page dots */}
          <View style={styles.dotsRow}>
            {GESTURES.map((_, i) => (
              <View
                key={i}
                style={[styles.dot, i === page && styles.dotActive]}
              />
            ))}
          </View>

          <View style={styles.navRow}>
            {page > 0 ? (
              <TouchableOpacity onPress={handlePrev} style={styles.navBtn}>
                <Ionicons name="chevron-back" size={20} color="#B9BBBE" />
                <Text style={styles.navText}>Back</Text>
              </TouchableOpacity>
            ) : (
              <View />
            )}
            <TouchableOpacity onPress={handleNext} style={[styles.navBtn, styles.nextBtn]}>
              <Text style={styles.nextText}>{isLast ? 'Got it!' : 'Next'}</Text>
              {!isLast && <Ionicons name="chevron-forward" size={20} color="#FFF" />}
            </TouchableOpacity>
          </View>
        </Animated.View>
      </View>
    </Modal>
  );
});

/**
 * Resets the guide so it shows again next launch.
 */
export async function resetGestureGuide() {
  await AsyncStorage.removeItem(GESTURE_GUIDE_KEY);
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.8)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  card: {
    width: Math.min(SCREEN_WIDTH - 48, 360),
    backgroundColor: '#36393F',
    borderRadius: 16,
    padding: 28,
    alignItems: 'center',
  },
  skipBtn: {
    position: 'absolute',
    top: 14,
    right: 16,
    padding: 4,
  },
  skipText: {
    color: '#72767D',
    fontSize: 13,
    fontFamily: 'GGSans-Medium',
  },
  gestureVisual: {
    alignItems: 'center',
    justifyContent: 'center',
    height: 100,
    width: 100,
    marginBottom: 16,
    marginTop: 8,
  },
  animCircle: {
    position: 'absolute',
    bottom: 0,
  },
  fingerDot: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: 'rgba(88,101,242,0.4)',
    borderWidth: 2,
    borderColor: '#5865F2',
  },
  gestureTitle: {
    color: '#FFFFFF',
    fontSize: 20,
    fontFamily: 'GGSans-Bold',
    marginBottom: 8,
  },
  gestureDesc: {
    color: '#B9BBBE',
    fontSize: 14,
    fontFamily: 'GGSans-Regular',
    textAlign: 'center',
    lineHeight: 20,
    marginBottom: 20,
  },
  dotsRow: {
    flexDirection: 'row',
    gap: 6,
    marginBottom: 20,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#4F545C',
  },
  dotActive: {
    backgroundColor: '#5865F2',
    width: 20,
  },
  navRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    width: '100%',
  },
  navBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    padding: 8,
  },
  navText: {
    color: '#B9BBBE',
    fontSize: 14,
    fontFamily: 'GGSans-Medium',
  },
  nextBtn: {
    backgroundColor: '#5865F2',
    borderRadius: 6,
    paddingHorizontal: 18,
    paddingVertical: 10,
  },
  nextText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontFamily: 'GGSans-Bold',
  },
});
