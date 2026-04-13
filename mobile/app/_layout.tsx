/**
 * Root Layout
 *
 * Configures providers (SafeAreaProvider, QueryClientProvider),
 * listens for Supabase auth state changes, and redirects
 * unauthenticated users to the login screen.
 *
 * Requirements: 2.1, 2.5, 37.1
 */
import { Stack, router } from 'expo-router';
import { ThemeProvider, DarkTheme } from '@react-navigation/native';
import React from 'react';
import { useEffect, useState, useRef } from 'react';
import { Animated, Easing, View, Image, Text, StyleSheet, Button } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { QueryClientProvider } from '@tanstack/react-query';
import { queryClient } from '../services/queryClient';
import { useFonts } from 'expo-font';
import { Pacifico_400Regular } from '@expo-google-fonts/pacifico';
import * as SplashScreen from 'expo-splash-screen';

// Keep splash screen visible while fonts load
SplashScreen.preventAutoHideAsync();
import { useAuthStore } from '@stores/authStore';
import { supabase } from '../services/supabase';
import { colors } from '../constants/Colors';
import { useTheme } from '../hooks/useTheme';
import { initCrashReporting, captureException, setUser as setCrashUser } from '@shared/services/crashReporting';
import { configureAudioSession } from '../lib/livekit';
import { PresenceTracker } from '../components/PresenceTracker';
import { subscribeToCalls } from '@services/dmCallService';
import { IncomingCallDialog } from '../components/messages/IncomingCallDialog';
import { useSettingsStore } from '@stores/settingsStore';
import { fetchUserPrivacySettings } from '@shared/services/privacySettingsService';

// MED-001: Initialize crash reporting before any rendering
initCrashReporting();

// LiveKit: configure native audio session at startup
configureAudioSession();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const flickoIcon = require('../assets/splash_icon.png');

// queryClient imported from services/queryClient.ts

function AuthGate({ children }: { children: React.ReactNode }) {
  const {
    user,
    initialized,
    setUser,
    setSession,
    setIsAuthenticated,
    setInitialized,
    setIsLoading,
    isSessionExpired,
  } = useAuthStore();

  const [isReady, setIsReady] = useState(false);
  const hasNavigated = useRef(false);
  const wasAuthenticated = useRef<boolean | null>(null);
  const navigationInProgress = useRef(false);

  useEffect(() => {
    // Get the current session on mount
    supabase.auth.getSession().then(async ({ data: { session } }) => {
      if (session) {
        setSession(session);
        // MED-019: If setSession rejected it (expired), don't authenticate
        if (!useAuthStore.getState().session) {
          supabase.auth.signOut();
        } else {
          let mergedUser: any = session.user as any;
          try {
            const { data: prof } = await supabase
              .from('profiles')
              .select('username, display_name, avatar, banner, bio, pronouns, discriminator')
              .eq('id', session.user.id)
              .maybeSingle();
            if (prof) {
              mergedUser = {
                ...session.user,
                username: prof.username ?? mergedUser.username,
                display_name: prof.display_name ?? mergedUser.display_name,
                avatar: prof.avatar ?? mergedUser.avatar,
                banner: prof.banner ?? mergedUser.banner,
                bio: prof.bio ?? mergedUser.bio,
                pronouns: prof.pronouns ?? mergedUser.pronouns,
                discriminator: prof.discriminator ?? mergedUser.discriminator,
              };
            }
            const privacy = await fetchUserPrivacySettings(session.user.id);
            if (privacy) useSettingsStore.getState().updatePrivacyPreferences(privacy);
          } catch {
            /* profile merge is best-effort */
          }
          setUser(mergedUser);
          setIsAuthenticated(true);
        }
      }
      setInitialized(true);
      setIsLoading(false);
      setIsReady(true);
    }).catch((err) => {
      // Invalid/expired refresh token — clear stale session and proceed to login
      console.warn('[AuthGate] Session restore failed, clearing stale session:', err.message);
      supabase.auth.signOut().catch(() => {});
      setSession(null);
      setUser(null);
      setIsAuthenticated(false);
      setInitialized(true);
      setIsLoading(false);
      setIsReady(true);
    });

    // Listen for auth state changes (sign in, sign out, token refresh)
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        if (event === 'TOKEN_REFRESHED' && !session) {
          // Refresh failed — clear stale auth state
          console.warn('[AuthGate] Token refresh failed, signing out');
          setSession(null);
          setUser(null);
          setIsAuthenticated(false);
          setIsLoading(false);
          router.replace('/login');
          return;
        }
        if (session) {
          setSession(session);
          (async () => {
            let mergedUser: any = session.user as any;
            try {
              const { data: prof } = await supabase
                .from('profiles')
                .select('username, display_name, avatar, banner, bio, pronouns, discriminator')
                .eq('id', session.user.id)
                .maybeSingle();
              if (prof) {
                mergedUser = {
                  ...session.user,
                  username: prof.username ?? mergedUser.username,
                  display_name: prof.display_name ?? mergedUser.display_name,
                  avatar: prof.avatar ?? mergedUser.avatar,
                  banner: prof.banner ?? mergedUser.banner,
                  bio: prof.bio ?? mergedUser.bio,
                  pronouns: prof.pronouns ?? mergedUser.pronouns,
                  discriminator: prof.discriminator ?? mergedUser.discriminator,
                };
              }
              const privacy = await fetchUserPrivacySettings(session.user.id);
              if (privacy) useSettingsStore.getState().updatePrivacyPreferences(privacy);
            } catch {
              /* ignore */
            }
            setUser(mergedUser);
            setIsAuthenticated(true);
          })();
        } else {
          setSession(null);
          setUser(null);
          setIsAuthenticated(false);
        }
        setIsLoading(false);
      },
    );

    // Listen for incoming DM calls
    let unsubscribeCalls: (() => void) | null = null;
    if (user) {
      unsubscribeCalls = subscribeToCalls(user.id);
    }

    return () => {
      subscription.unsubscribe();
      if (unsubscribeCalls) unsubscribeCalls();
    };
  }, [user]); // Re-subscribe if user changes

  // Redirect based on auth state — only on initial load and on actual login/logout transitions
  // HIGH-014: Added navigation guard to prevent infinite loop if auth state flaps
  useEffect(() => {
    if (!isReady || navigationInProgress.current) return;

    const isAuthenticated = initialized && !!user;

    // First navigation after app load
    if (!hasNavigated.current) {
      hasNavigated.current = true;
      wasAuthenticated.current = isAuthenticated;
      navigationInProgress.current = true;
      if (!user) {
        router.replace('/login');
      } else {
        router.replace('/(tabs)');
      }
      setTimeout(() => { navigationInProgress.current = false; }, 1000);
      return;
    }

    // Only redirect when auth state actually transitions (login / logout)
    if (wasAuthenticated.current !== isAuthenticated) {
      wasAuthenticated.current = isAuthenticated;
      navigationInProgress.current = true;
      if (!user) {
        router.replace('/login');
      } else {
        router.replace('/(tabs)');
      }
      setTimeout(() => { navigationInProgress.current = false; }, 1000);
    }
  }, [user, initialized, isReady]);

  // Show animated splash screen while restoring session
  if (!isReady) {
    return <SplashLoader />;
  }

  return (
    <>
      <PresenceTracker />
      <IncomingCallDialog />
      {children}
    </>
  );
}

/** Session restore splash — Flicko mark only (no loading dots). */
function SplashLoader() {
  const { themeColors } = useTheme();
  const scaleAnim = useRef(new Animated.Value(0.88)).current;
  const opacityAnim = useRef(new Animated.Value(0)).current;
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(opacityAnim, {
        toValue: 1,
        duration: 450,
        useNativeDriver: true,
      }),
      Animated.spring(scaleAnim, {
        toValue: 1,
        friction: 5,
        tension: 80,
        useNativeDriver: true,
      }),
    ]).start();

    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.04,
          duration: 1400,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 1400,
          easing: Easing.inOut(Easing.ease),
          useNativeDriver: true,
        }),
      ]),
    ).start();
  }, []);

  const combinedScale = Animated.multiply(scaleAnim, pulseAnim);

  return (
    <View style={[styles.splashContainer, { backgroundColor: themeColors.bgPrimary }]}>
      <Animated.Image
        source={flickoIcon}
        style={[
          styles.splashIcon,
          {
            opacity: opacityAnim,
            transform: [{ scale: combinedScale }],
          },
        ]}
        resizeMode="contain"
      />
    </View>
  );
}

/** HIGH-005: Error boundary to prevent full app crashes */
class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('[ErrorBoundary] App Error:', error, errorInfo);
    // MED-001: Report to crash reporting service
    captureException(error, { componentStack: errorInfo.componentStack });
  }

  render() {
    if (this.state.hasError) {
      // Use colors.dark as fallback since we can't use hooks in class components
      const fallbackColors = colors.dark;
      return (
        <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center', padding: 20, backgroundColor: fallbackColors.bgPrimary }}>
          <Text style={{ fontSize: 18, fontFamily: 'gg-sans-bold', marginBottom: 10, color: fallbackColors.textPrimary }}>
            Something went wrong
          </Text>
          <Text style={{ marginBottom: 20, textAlign: 'center', color: fallbackColors.textSecondary }}>
            {this.state.error?.message}
          </Text>
          <Button
            title="Restart App"
            onPress={() => this.setState({ hasError: false, error: null })}
          />
        </View>
      );
    }

    return this.props.children;
  }
}

// Custom dark navigation theme to prevent white flash during transitions
const FlickoDarkTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    background: colors.dark.bgTertiary,
    card: colors.dark.bgTertiary,
    border: colors.dark.divider,
  },
};

export default function RootLayout() {
  const { themeColors } = useTheme();
  const [fontsLoaded, fontError] = useFonts({
    Pacifico_400Regular,
    // ─── GG Sans (Discord's font) ───
    'gg-sans':          require('../assets/fonts/GGSans-Regular.ttf'),
    'gg-sans-medium':   require('../assets/fonts/GGSans-Medium.ttf'),
    'gg-sans-semibold': require('../assets/fonts/GGSans-SemiBold.ttf'),
    'gg-sans-bold':     require('../assets/fonts/GGSans-Bold.ttf'),
  });

  // Hide splash screen once fonts are ready
  useEffect(() => {
    if (fontsLoaded || fontError) {
      SplashScreen.hideAsync();
    }
  }, [fontsLoaded, fontError]);

  // Don't render until fonts are loaded
  if (!fontsLoaded && !fontError) {
    return null;
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <ErrorBoundary>
        <SafeAreaProvider>
          <QueryClientProvider client={queryClient}>
            <AuthGate>
              <ThemeProvider value={FlickoDarkTheme}>
            <Stack screenOptions={{
              headerShown: false,
              contentStyle: { backgroundColor: themeColors.bgTertiary },
              animation: 'slide_from_right',
              animationDuration: 200,
              gestureEnabled: true,
              gestureDirection: 'horizontal',
              navigationBarColor: themeColors.bgTertiary,
              statusBarColor: themeColors.bgTertiary,
            }}>
              <Stack.Screen name="(auth)" options={{ animation: 'fade', contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="(tabs)" options={{ animation: 'fade', contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="settings" options={{ animation: 'slide_from_right', contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="server" options={{ animation: 'slide_from_right', contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="dm" options={{ animation: 'slide_from_right', contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="profile" options={{ animation: 'slide_from_bottom', contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="search" options={{ animation: 'fade_from_bottom', animationDuration: 150, contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="advanced-search" options={{ animation: 'fade_from_bottom', animationDuration: 150, contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="voice" options={{ animation: 'slide_from_bottom', contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="notifications" options={{ animation: 'slide_from_right', contentStyle: { backgroundColor: themeColors.bgTertiary } }} />
              <Stack.Screen name="+not-found" />
            </Stack>
            </ThemeProvider>
          </AuthGate>
        </QueryClientProvider>
      </SafeAreaProvider>
    </ErrorBoundary>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  splashContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  splashIcon: {
    width: 130,
    height: 130,
    borderRadius: 32,
  },
});
