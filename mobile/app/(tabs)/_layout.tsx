/**
 * Tab Layout — Discord-style bottom navigation with animations
 *
 * Animated icon scale on press, smooth pill background transition,
 * and avatar border animation for the "You" tab.
 */
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { View, StyleSheet } from 'react-native';
import { Image } from 'expo-image';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  useAnimatedProps,
  interpolateColor,
} from 'react-native-reanimated';
import { useEffect } from 'react';
import { useTheme } from '../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';
import { SPRING_SNAPPY, SPRING_BOUNCY, TIMING_FAST } from '../../constants/Animations';

const AnimatedImage = Animated.createAnimatedComponent(Image);

/** Animated tab icon with scale bounce and pill background */
function TabIcon({
  focused,
  color,
  iconFocused,
  iconDefault,
}: {
  focused: boolean;
  color: string;
  iconFocused: React.ComponentProps<typeof Ionicons>['name'];
  iconDefault: React.ComponentProps<typeof Ionicons>['name'];
}) {
  const scale = useSharedValue(focused ? 1 : 1);
  const pillOpacity = useSharedValue(focused ? 1 : 0);
  const pillScale = useSharedValue(focused ? 1 : 0.5);

  useEffect(() => {
    // Bounce on focus change
    if (focused) {
      scale.value = withSpring(1.15, SPRING_BOUNCY, () => {
        scale.value = withSpring(1, SPRING_SNAPPY);
      });
      pillOpacity.value = withTiming(1, TIMING_FAST);
      pillScale.value = withSpring(1, SPRING_SNAPPY);
    } else {
      scale.value = withSpring(1, SPRING_SNAPPY);
      pillOpacity.value = withTiming(0, TIMING_FAST);
      pillScale.value = withSpring(0.5, SPRING_SNAPPY);
    }
  }, [focused]);

  const iconAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const pillAnimStyle = useAnimatedStyle(() => ({
    opacity: pillOpacity.value,
    transform: [{ scaleX: pillScale.value }],
  }));

  return (
    <View style={styles.iconWrap}>
      <Animated.View style={[styles.pill, pillAnimStyle]} />
      <Animated.View style={iconAnimStyle}>
        <Ionicons name={focused ? iconFocused : iconDefault} size={22} color={color} />
      </Animated.View>
    </View>
  );
}

/** Animated avatar tab icon */
function AvatarTabIcon({
  focused,
  color,
  avatarUri,
}: {
  focused: boolean;
  color: string;
  avatarUri?: string | null;
}) {
  const scale = useSharedValue(1);
  const pillOpacity = useSharedValue(focused ? 1 : 0);
  const pillScale = useSharedValue(focused ? 1 : 0.5);
  const borderProgress = useSharedValue(focused ? 1 : 0);

  useEffect(() => {
    if (focused) {
      scale.value = withSpring(1.15, SPRING_BOUNCY, () => {
        scale.value = withSpring(1, SPRING_SNAPPY);
      });
      pillOpacity.value = withTiming(1, TIMING_FAST);
      pillScale.value = withSpring(1, SPRING_SNAPPY);
      borderProgress.value = withSpring(1, SPRING_SNAPPY);
    } else {
      scale.value = withSpring(1, SPRING_SNAPPY);
      pillOpacity.value = withTiming(0, TIMING_FAST);
      pillScale.value = withSpring(0.5, SPRING_SNAPPY);
      borderProgress.value = withSpring(0, SPRING_SNAPPY);
    }
  }, [focused]);

  const iconAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  const pillAnimStyle = useAnimatedStyle(() => ({
    opacity: pillOpacity.value,
    transform: [{ scaleX: pillScale.value }],
  }));

  const avatarAnimStyle = useAnimatedStyle(() => ({
    borderWidth: 2,
    borderColor: `rgba(255,255,255,${borderProgress.value})`,
  }));

  return (
    <View style={styles.iconWrap}>
      <Animated.View style={[styles.pill, pillAnimStyle]} />
      <Animated.View style={iconAnimStyle}>
        {avatarUri && avatarUri.trim().length > 0 ? (
          <Animated.View style={[styles.avatar, avatarAnimStyle]}>
            <Image
              source={{ uri: avatarUri }}
              style={styles.avatarImage}
              contentFit="cover"
              cachePolicy="disk"
              transition={200}
            />
          </Animated.View>
        ) : (
          <View style={[styles.avatarFallback, focused && styles.avatarFallbackFocused]}>
            <Ionicons name="person" size={16} color={focused ? '#FFFFFF' : color} />
          </View>
        )}
      </Animated.View>
    </View>
  );
}

export default function TabLayout() {
  const { themeColors: theme } = useTheme();
  const user = useAuthStore((s: any) => s.user);
  
  const avatarToUse = user?.avatar || user?.user_metadata?.avatar_url || null;

  return (
    <Tabs
      sceneContainerStyle={{ backgroundColor: theme.bgPrimary }}
      screenOptions={{
        tabBarActiveTintColor: '#FFFFFF',
        tabBarInactiveTintColor: theme.textMuted,
        headerShown: false,
        tabBarStyle: {
          backgroundColor: theme.bgTertiary,
          borderTopColor: theme.bgTertiary,
          borderTopWidth: 0,
          paddingBottom: 2,
          paddingTop: 4,
          height: 56,
          elevation: 0,
          shadowOpacity: 0,
        },
        tabBarLabelStyle: {
          fontSize: 10,
          fontFamily: 'gg-sans-semibold',
          marginTop: -2,
        },
        tabBarIconStyle: {
          marginBottom: -2,
        },
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Servers',
          tabBarIcon: ({ color, focused }) => (
            <TabIcon focused={focused} color={color} iconFocused="grid" iconDefault="grid-outline" />
          ),
        }}
      />
      <Tabs.Screen
        name="dms"
        options={{
          href: null,
        }}
      />
      <Tabs.Screen
        name="notifications"
        options={{
          title: 'Notifications',
          tabBarIcon: ({ color, focused }) => (
            <TabIcon focused={focused} color={color} iconFocused="notifications" iconDefault="notifications-outline" />
          ),
        }}
      />
      <Tabs.Screen
        name="friends"
        options={{
          href: null,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'You',
          tabBarIcon: ({ color, focused }) => (
            <AvatarTabIcon focused={focused} color={color} avatarUri={avatarToUse} />
          ),
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  iconWrap: {
    width: 46,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pill: {
    position: 'absolute',
    width: 46,
    height: 28,
    borderRadius: 12,
    backgroundColor: 'rgba(88,101,242,0.15)',
  },
  avatar: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarImage: {
    width: 24,
    height: 24,
    borderRadius: 12,
  },
  avatarFallback: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: 'rgba(88,101,242,0.3)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarFallbackFocused: {
    backgroundColor: 'rgba(88,101,242,0.6)',
  },
});
