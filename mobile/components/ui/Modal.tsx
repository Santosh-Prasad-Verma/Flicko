/**
 * Modal Component — Discord-style Spring Sheet
 *
 * Bottom sheet modal with spring slide-up animation, backdrop fade,
 * and swipe-to-dismiss gesture. Uses Reanimated for smooth 60fps.
 *
 * Requirements: 16.4
 */
import React, { useEffect, useCallback } from 'react';
import {
  Modal as RNModal,
  View,
  Pressable,
  Text,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ViewStyle,
  Dimensions,
} from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  runOnJS,
  interpolate,
  Extrapolation,
} from 'react-native-reanimated';
import {
  Gesture,
  GestureDetector,
  GestureHandlerRootView,
} from 'react-native-gesture-handler';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  spacing,
  borderRadius,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';
import { SPRING_SNAPPY, SPRING_BOUNCY, TIMING_FAST } from '../../constants/Animations';
import { useTheme } from '../../hooks/useTheme';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const DISMISS_THRESHOLD = 120;

interface ModalProps {
  visible: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  /** Whether pressing the backdrop dismisses the modal */
  dismissible?: boolean;
  style?: ViewStyle;
}

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export const Modal = React.memo<ModalProps>(function Modal({
  visible,
  onClose,
  title,
  children,
  dismissible = true,
  style,
}) {
  const { themeColors } = useTheme();
  const insets = useSafeAreaInsets();

  // 0 = hidden (off-screen), 1 = fully visible
  const progress = useSharedValue(0);
  const translateY = useSharedValue(SCREEN_HEIGHT);
  const dragY = useSharedValue(0);

  const handleClose = useCallback(() => {
    onClose();
  }, [onClose]);

  // Animate in when visible changes
  useEffect(() => {
    if (visible) {
      // Reset position and animate up
      translateY.value = SCREEN_HEIGHT;
      progress.value = withTiming(1, TIMING_FAST);
      translateY.value = withSpring(0, SPRING_SNAPPY);
    }
  }, [visible]);

  // Pan gesture for swipe-to-dismiss
  const panGesture = Gesture.Pan()
    .enabled(dismissible)
    .onUpdate((event) => {
      // Only allow dragging down
      dragY.value = Math.max(0, event.translationY);
    })
    .onEnd((event) => {
      if (event.translationY > DISMISS_THRESHOLD || event.velocityY > 500) {
        // Dismiss
        translateY.value = withSpring(SCREEN_HEIGHT, SPRING_SNAPPY);
        progress.value = withTiming(0, TIMING_FAST, () => {
          runOnJS(handleClose)();
        });
      } else {
        // Snap back
        dragY.value = withSpring(0, SPRING_SNAPPY);
      }
    });

  // Backdrop opacity
  const backdropStyle = useAnimatedStyle(() => ({
    opacity: interpolate(progress.value, [0, 1], [0, 1], Extrapolation.CLAMP),
  }));

  // Content slide + drag
  const contentStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: translateY.value + dragY.value }],
  }));

  // Handle backdrop press dismiss
  const dismissWithAnimation = useCallback(() => {
    if (!dismissible) return;
    translateY.value = withSpring(SCREEN_HEIGHT, SPRING_SNAPPY);
    progress.value = withTiming(0, TIMING_FAST, () => {
      runOnJS(handleClose)();
    });
  }, [dismissible, handleClose]);

  return (
    <RNModal
      visible={visible}
      transparent
      animationType="none"
      onRequestClose={dismissWithAnimation}
      statusBarTranslucent
    >
      <GestureHandlerRootView style={{ flex: 1 }}>
        <KeyboardAvoidingView
          style={styles.wrapper}
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        >
          {/* Backdrop */}
          <AnimatedPressable
            style={[styles.backdrop, { backgroundColor: themeColors.overlay }, backdropStyle]}
            onPress={dismissWithAnimation}
            accessibilityRole="button"
            accessibilityLabel="Close modal"
          />

          {/* Drag handle + Content */}
          <GestureDetector gesture={panGesture}>
            <Animated.View
              style={[
                styles.content,
                {
                  backgroundColor: themeColors.bgSecondary,
                  borderColor: themeColors.border,
                  paddingBottom: Math.max(insets.bottom, spacing.xxl),
                },
                style,
                contentStyle,
              ]}
              accessibilityViewIsModal
            >
              {/* Drag indicator */}
              <View style={styles.dragIndicatorRow}>
                <View style={[styles.dragIndicator, { backgroundColor: themeColors.textMuted }]} />
              </View>

              {/* Header */}
              {title ? (
                <View style={styles.header}>
                  <Text style={[styles.title, { color: themeColors.textPrimary }]}>
                    {title}
                  </Text>
                  <Pressable
                    onPress={dismissWithAnimation}
                    hitSlop={12}
                    accessibilityRole="button"
                    accessibilityLabel="Close"
                    style={styles.closeButton}
                  >
                    <Text style={[styles.closeText, { color: themeColors.textSecondary }]}>
                      ✕
                    </Text>
                  </Pressable>
                </View>
              ) : null}

              {children}
            </Animated.View>
          </GestureDetector>
        </KeyboardAvoidingView>
      </GestureHandlerRootView>
    </RNModal>
  );
});

const styles = StyleSheet.create({
  wrapper: {
    flex: 1,
    justifyContent: 'flex-end',
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
  },
  content: {
    borderTopLeftRadius: borderRadius.xl,
    borderTopRightRadius: borderRadius.xl,
    borderWidth: 1,
    borderBottomWidth: 0,
    paddingHorizontal: spacing.xxl,
    paddingTop: 0,
    maxHeight: '90%',
  },
  dragIndicatorRow: {
    alignItems: 'center',
    paddingVertical: spacing.sm,
  },
  dragIndicator: {
    width: 36,
    height: 4,
    borderRadius: 2,
    opacity: 0.4,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: spacing.lg,
    paddingTop: spacing.sm,
  },
  title: {
    ...typography.headingM,
    flex: 1,
  },
  closeButton: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  closeText: {
    fontSize: 18,
    fontFamily: 'gg-sans-semibold',
  },
});
