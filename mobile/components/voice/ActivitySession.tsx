/**
 * Activity Session
 *
 * Manages the full activity session lifecycle within a voice channel:
 * IDLE → LAUNCHING → ACTIVE → CLOSING → ENDED
 *
 * When ACTIVE, renders the activity in a WebView with a JS↔Native bridge.
 * Shows appropriate UI for each state with participant list and host controls.
 *
 * Requirements: Activity Session Lifecycle
 */
import React, { memo, useCallback, useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
  Alert,
  FlatList,
  Platform,
} from 'react-native';
import Animated, {
  FadeIn,
  FadeOut,
  FadeInUp,
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  withSequence,
  Easing,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { Avatar } from '../ui/Avatar';
import { useTheme } from '../../hooks/useTheme';
import {
  spacing,
  borderRadius,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';
import {
  useActivityStore,
  type ActivitySession as ActivitySessionType,
  type ActivitySessionState,
  type ActivityParticipant,
} from '@stores/activityStore';
import {
  updateSessionState,
  endActivitySession,
  joinActivitySession,
  leaveActivitySession,
  subscribeToActivitySession,
} from '@services/activityService';
import { useAuthStore } from '@stores/authStore';

// Conditionally import WebView — graceful fallback if not installed
let WebView: any = null;
try {
  WebView = require('react-native-webview').WebView;
} catch {
  // Will render placeholder if WebView not available
}

interface ActivitySessionProps {
  channelId: string;
  serverId: string;
}

// ── State Indicator ───────────────────────────────────────────────────────

const StateIndicator = memo(function StateIndicator({
  state,
}: {
  state: ActivitySessionState;
}) {
  const { themeColors } = useTheme();
  const pulse = useSharedValue(1);

  useEffect(() => {
    if (state === 'launching') {
      pulse.value = withRepeat(
        withSequence(
          withTiming(0.5, { duration: 600, easing: Easing.inOut(Easing.ease) }),
          withTiming(1, { duration: 600, easing: Easing.inOut(Easing.ease) }),
        ),
        -1,
        false,
      );
    } else {
      pulse.value = 1;
    }
  }, [state, pulse]);

  const dotStyle = useAnimatedStyle(() => ({
    opacity: pulse.value,
  }));

  const stateConfig: Record<
    ActivitySessionState,
    { color: string; label: string; icon: string }
  > = {
    idle: { color: themeColors.textMuted, label: 'Idle', icon: 'ellipse-outline' },
    launching: { color: themeColors.warning, label: 'Launching...', icon: 'rocket' },
    active: { color: themeColors.success, label: 'Active', icon: 'play-circle' },
    closing: { color: themeColors.warning, label: 'Closing...', icon: 'close-circle' },
    ended: { color: themeColors.textMuted, label: 'Ended', icon: 'checkmark-circle' },
  };

  const cfg = stateConfig[state];

  return (
    <View style={styles.stateRow}>
      <Animated.View
        style={[styles.stateDot, { backgroundColor: cfg.color }, dotStyle]}
      />
      <Ionicons name={cfg.icon as any} size={14} color={cfg.color} />
      <Text style={[styles.stateLabel, { color: cfg.color }]}>{cfg.label}</Text>
    </View>
  );
});

// ── Participant Row ───────────────────────────────────────────────────────

const ParticipantRow = memo(function ParticipantRow({
  participant,
  isHost,
}: {
  participant: ActivityParticipant;
  isHost: boolean;
}) {
  const { themeColors } = useTheme();

  return (
    <Animated.View
      entering={FadeIn.duration(200)}
      exiting={FadeOut.duration(150)}
      style={styles.participantRow}
    >
      <Avatar
        name={participant.displayName}
        imageUrl={participant.avatarUrl}
        size={28}
      />
      <Text
        style={[styles.participantName, { color: themeColors.textPrimary }]}
        numberOfLines={1}
      >
        {participant.displayName}
      </Text>
      {isHost && (
        <View style={[styles.hostBadge, { backgroundColor: themeColors.warning + '30' }]}>
          <Text style={[styles.hostText, { color: themeColors.warning }]}>
            Host
          </Text>
        </View>
      )}
    </Animated.View>
  );
});

// ── Launching State ───────────────────────────────────────────────────────

const LaunchingView = memo(function LaunchingView({
  session,
}: {
  session: ActivitySessionType;
}) {
  const { themeColors } = useTheme();
  const spin = useSharedValue(0);

  useEffect(() => {
    spin.value = withRepeat(
      withTiming(360, { duration: 2000, easing: Easing.linear }),
      -1,
      false,
    );
  }, [spin]);

  const spinStyle = useAnimatedStyle(() => ({
    transform: [{ rotateZ: `${spin.value}deg` }],
  }));

  return (
    <Animated.View entering={FadeIn.duration(300)} style={styles.stateContainer}>
      <Animated.View style={spinStyle}>
        <Ionicons name="rocket" size={48} color={themeColors.accentPrimary} />
      </Animated.View>
      <Text style={[styles.stateTitle, { color: themeColors.textPrimary }]}>
        Launching {session.activity.name}
      </Text>
      <Text style={[styles.stateSubtitle, { color: themeColors.textMuted }]}>
        Preparing the activity for everyone...
      </Text>
      <ActivityIndicator
        color={themeColors.accentPrimary}
        style={{ marginTop: spacing.lg }}
      />
    </Animated.View>
  );
});

// ── Active State (WebView with JS↔Native bridge) ─────────────────────────

/**
 * Bridge protocol: The activity iframe communicates via postMessage.
 * 
 * Activity → Native (onMessage):
 *   { type: 'READY' }                              — Activity loaded
 *   { type: 'GET_PARTICIPANTS' }                    — Request participant list
 *   { type: 'SET_ACTIVITY_STATE', state: object }   — Update activity state
 *   { type: 'CLOSE' }                               — Request close
 *   { type: 'GET_USER' }                            — Request current user info
 * 
 * Native → Activity (injectJavaScript):
 *   { type: 'PARTICIPANTS', participants: [...] }
 *   { type: 'USER', user: {...} }
 *   { type: 'ACTIVITY_STATE_UPDATE', state: {...} }
 *   { type: 'SESSION_UPDATE', session: {...} }
 */

const BRIDGE_INJECT_JS = `
  (function() {
    if (window.__FLICKO_BRIDGE__) return;
    window.__FLICKO_BRIDGE__ = {
      ready: false,
      send: function(msg) {
        window.ReactNativeWebView.postMessage(JSON.stringify(msg));
      },
      _handlers: {},
      on: function(type, handler) {
        this._handlers[type] = handler;
      },
      _dispatch: function(msg) {
        var h = this._handlers[msg.type];
        if (h) h(msg);
      }
    };
    // Listen for native → activity messages
    window.addEventListener('message', function(e) {
      try {
        var msg = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
        window.__FLICKO_BRIDGE__._dispatch(msg);
      } catch(_) {}
    });
    // Signal ready
    window.__FLICKO_BRIDGE__.ready = true;
    window.__FLICKO_BRIDGE__.send({ type: 'READY' });
    true;
  })();
`;

const ActiveView = memo(function ActiveView({
  session,
}: {
  session: ActivitySessionType;
}) {
  const { themeColors } = useTheme();
  const webViewRef = useRef<any>(null);
  const store = useActivityStore();
  const user = useAuthStore((s) => s.user);
  const [webViewError, setWebViewError] = useState<string | null>(null);
  const [loaded, setLoaded] = useState(false);

  // Send message to activity WebView
  const sendToActivity = useCallback((msg: Record<string, any>) => {
    if (webViewRef.current) {
      const json = JSON.stringify(msg);
      webViewRef.current.injectJavaScript(
        `window.__FLICKO_BRIDGE__ && window.__FLICKO_BRIDGE__._dispatch(${json}); true;`
      );
    }
  }, []);

  // Push participant updates to activity
  useEffect(() => {
    if (loaded) {
      sendToActivity({
        type: 'PARTICIPANTS',
        participants: session.participants.map((p) => ({
          userId: p.userId,
          displayName: p.displayName,
          avatarUrl: p.avatarUrl,
        })),
      });
    }
  }, [session.participants, loaded, sendToActivity]);

  // Handle messages from activity WebView
  const handleMessage = useCallback((event: any) => {
    try {
      const msg = JSON.parse(event.nativeEvent.data);

      switch (msg.type) {
        case 'READY':
          setLoaded(true);
          // Send initial data
          sendToActivity({
            type: 'SESSION_UPDATE',
            session: {
              id: session.id,
              activityId: session.activity.id,
              activityName: session.activity.name,
              state: session.state,
              participantCount: session.participants.length,
            },
          });
          break;

        case 'GET_PARTICIPANTS':
          sendToActivity({
            type: 'PARTICIPANTS',
            participants: session.participants.map((p) => ({
              userId: p.userId,
              displayName: p.displayName,
              avatarUrl: p.avatarUrl,
            })),
          });
          break;

        case 'GET_USER':
          sendToActivity({
            type: 'USER',
            user: user
              ? { id: user.id, username: (user as any).username, avatar: (user as any).avatar }
              : null,
          });
          break;

        case 'SET_ACTIVITY_STATE':
          // Activity wants to broadcast state to other participants
          if (msg.state) {
            console.log('[ActivityBridge] Activity state update:', msg.state);
          }
          break;

        case 'CLOSE':
          // Activity requested close
          Alert.alert('Activity', 'The activity requested to close.', [
            { text: 'OK', onPress: () => store.endSession() },
          ]);
          break;

        default:
          console.log('[ActivityBridge] Unknown message:', msg.type);
      }
    } catch (err) {
      console.error('[ActivityBridge] Parse error:', err);
    }
  }, [session, user, store, sendToActivity]);

  // If WebView is not installed, or no embedUrl, show placeholder
  if (!WebView || !session.embedUrl) {
    return (
      <View style={styles.activeContainer}>
        <View
          style={[
            styles.webviewPlaceholder,
            { backgroundColor: themeColors.bgTertiary, borderColor: themeColors.border },
          ]}
        >
          <Ionicons
            name="game-controller"
            size={48}
            color={themeColors.accentPrimary}
          />
          <Text style={[styles.webviewText, { color: themeColors.textPrimary }]}>
            {session.activity.name}
          </Text>
          <Text style={[styles.webviewSubtext, { color: themeColors.textMuted }]}>
            {!WebView
              ? 'WebView not available — install react-native-webview'
              : 'Activity is running (no embed URL)'}
          </Text>
          {session.embedUrl ? (
            <Text style={[styles.webviewUrl, { color: themeColors.textMuted }]}>
              {session.embedUrl}
            </Text>
          ) : null}
        </View>
      </View>
    );
  }

  return (
    <View style={styles.activeContainer}>
      {/* Loading overlay */}
      {!loaded && (
        <View style={[styles.loadingOverlay, { backgroundColor: themeColors.bgPrimary }]}>
          <ActivityIndicator size="large" color={themeColors.accentPrimary} />
          <Text style={[styles.loadingText, { color: themeColors.textMuted }]}>
            Loading {session.activity.name}...
          </Text>
        </View>
      )}

      {/* Error state */}
      {webViewError && (
        <View style={[styles.errorOverlay, { backgroundColor: themeColors.bgPrimary }]}>
          <Ionicons name="warning" size={32} color={themeColors.danger} />
          <Text style={[styles.errorText, { color: themeColors.danger }]}>
            {webViewError}
          </Text>
          <Pressable
            onPress={() => {
              setWebViewError(null);
              setLoaded(false);
              webViewRef.current?.reload();
            }}
            style={[styles.retryBtn, { backgroundColor: themeColors.bgTertiary }]}
          >
            <Text style={[styles.retryText, { color: themeColors.textPrimary }]}>Retry</Text>
          </Pressable>
        </View>
      )}

      {/* WebView */}
      <WebView
        ref={webViewRef}
        source={{ uri: session.embedUrl }}
        style={[styles.webview, !loaded && { opacity: 0 }]}
        injectedJavaScript={BRIDGE_INJECT_JS}
        onMessage={handleMessage}
        onLoadEnd={() => {
          // Bridge READY message will set loaded state
        }}
        onError={(e: any) => {
          setWebViewError(e.nativeEvent?.description || 'Failed to load activity');
        }}
        onHttpError={(e: any) => {
          if (e.nativeEvent?.statusCode >= 400) {
            setWebViewError(`HTTP ${e.nativeEvent.statusCode}`);
          }
        }}
        javaScriptEnabled
        domStorageEnabled
        allowsInlineMediaPlayback
        mediaPlaybackRequiresUserAction={false}
        originWhitelist={['*']}
        startInLoadingState={false}
      />
    </View>
  );
});

// ── Ended State ───────────────────────────────────────────────────────────

const EndedView = memo(function EndedView({
  session,
  onDismiss,
}: {
  session: ActivitySessionType;
  onDismiss: () => void;
}) {
  const { themeColors } = useTheme();

  return (
    <Animated.View entering={FadeIn.duration(300)} style={styles.stateContainer}>
      <View
        style={[styles.endedCircle, { backgroundColor: themeColors.bgTertiary }]}
      >
        <Ionicons name="checkmark" size={32} color={themeColors.success} />
      </View>
      <Text style={[styles.stateTitle, { color: themeColors.textPrimary }]}>
        Activity Ended
      </Text>
      <Text style={[styles.stateSubtitle, { color: themeColors.textMuted }]}>
        {session.activity.name} has finished
      </Text>
      {session.errorMessage && (
        <Text style={[styles.errorMsg, { color: themeColors.danger }]}>
          {session.errorMessage}
        </Text>
      )}
      <Pressable
        onPress={onDismiss}
        style={[styles.dismissBtn, { backgroundColor: themeColors.bgTertiary }]}
      >
        <Text style={[styles.dismissText, { color: themeColors.textPrimary }]}>
          Dismiss
        </Text>
      </Pressable>
    </Animated.View>
  );
});

// ── Main Component ────────────────────────────────────────────────────────

export const ActivitySession = memo(function ActivitySession({
  channelId,
  serverId,
}: ActivitySessionProps) {
  const { themeColors } = useTheme();
  const store = useActivityStore();
  const session = store.currentSession;
  const user = useAuthStore((s) => s.user);
  const isHost = session?.hostUserId === user?.id;

  // Subscribe to real-time session updates
  useEffect(() => {
    if (!channelId) return;

    const unsubscribe = subscribeToActivitySession(channelId, (updatedSession) => {
      if (updatedSession) {
        store.launchActivity(updatedSession);
        store.setSessionState(updatedSession.state);
        store.setParticipants(updatedSession.participants);
      } else if (session) {
        store.endSession();
      }
    });

    return () => unsubscribe();
  }, [channelId]); // eslint-disable-line react-hooks/exhaustive-deps

  // Auto-transition from launching to active
  useEffect(() => {
    if (session?.state === 'launching') {
      const timer = setTimeout(async () => {
        try {
          await updateSessionState(session.id, 'active');
          store.setSessionState('active');
        } catch (err) {
          console.error('[ActivitySession] transition error:', err);
          store.setSessionState('ended', 'Failed to start activity');
        }
      }, 3000); // 3s simulated launch time
      return () => clearTimeout(timer);
    }
  }, [session?.state, session?.id, store]);

  const handleEndActivity = useCallback(async () => {
    if (!session) return;

    Alert.alert(
      'End Activity',
      `Are you sure you want to end ${session.activity.name}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'End',
          style: 'destructive',
          onPress: async () => {
            try {
              store.setSessionState('closing');
              await endActivitySession(session.id);
              store.endSession();
            } catch (err) {
              console.error('[ActivitySession] end error:', err);
              store.setSessionState('ended', 'Error ending activity');
            }
          },
        },
      ],
    );
  }, [session, store]);

  const handleLeave = useCallback(async () => {
    if (!session) return;

    try {
      await leaveActivitySession(session.id);
      store.reset();
    } catch (err) {
      console.error('[ActivitySession] leave error:', err);
    }
  }, [session, store]);

  const handleDismiss = useCallback(() => {
    store.reset();
  }, [store]);

  // Don't render if no session
  if (!session) return null;

  return (
    <Animated.View
      entering={FadeInUp.duration(300)}
      exiting={FadeOut.duration(200)}
      style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
    >
      {/* Header bar */}
      <View
        style={[styles.header, { borderBottomColor: themeColors.border }]}
      >
        <View style={styles.headerLeft}>
          <Ionicons
            name="game-controller"
            size={20}
            color={themeColors.accentPrimary}
          />
          <Text
            style={[styles.headerTitle, { color: themeColors.textPrimary }]}
            numberOfLines={1}
          >
            {session.activity.name}
          </Text>
        </View>
        <StateIndicator state={session.state} />
      </View>

      {/* State-specific content */}
      {session.state === 'launching' && (
        <LaunchingView session={session} />
      )}

      {session.state === 'active' && (
        <ActiveView session={session} />
      )}

      {session.state === 'closing' && (
        <Animated.View entering={FadeIn.duration(200)} style={styles.stateContainer}>
          <ActivityIndicator size="large" color={themeColors.warning} />
          <Text style={[styles.stateTitle, { color: themeColors.textPrimary }]}>
            Closing activity...
          </Text>
        </Animated.View>
      )}

      {session.state === 'ended' && (
        <EndedView session={session} onDismiss={handleDismiss} />
      )}

      {/* Participants sidebar */}
      {(session.state === 'active' || session.state === 'launching') && (
        <View
          style={[styles.participantsPanel, { backgroundColor: themeColors.bgSecondary }]}
        >
          <Text style={[styles.panelTitle, { color: themeColors.textMuted }]}>
            PARTICIPANTS — {session.participants.length}
          </Text>
          <FlatList
            data={session.participants}
            renderItem={({ item }) => (
              <ParticipantRow
                participant={item}
                isHost={item.userId === session.hostUserId}
              />
            )}
            keyExtractor={(item) => item.userId}
            contentContainerStyle={styles.participantsList}
            scrollEnabled={false}
          />
        </View>
      )}

      {/* Action buttons */}
      {session.state !== 'ended' && (
        <View style={styles.actionBar}>
          {isHost && session.state === 'active' && (
            <Pressable
              onPress={handleEndActivity}
              style={[styles.endBtn, { backgroundColor: themeColors.danger }]}
            >
              <Ionicons name="stop" size={18} color="#FFFFFF" />
              <Text style={styles.endBtnText}>End Activity</Text>
            </Pressable>
          )}
          {!isHost && (
            <Pressable
              onPress={handleLeave}
              style={[styles.leaveBtn, { backgroundColor: themeColors.bgTertiary }]}
            >
              <Ionicons
                name="exit"
                size={18}
                color={themeColors.textPrimary}
              />
              <Text
                style={[styles.leaveBtnText, { color: themeColors.textPrimary }]}
              >
                Leave Activity
              </Text>
            </Pressable>
          )}
        </View>
      )}
    </Animated.View>
  );
});

// ── Styles ────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    flex: 1,
  },
  headerTitle: {
    ...typography.headingS,
    flex: 1,
  },
  stateRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  stateDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  stateLabel: {
    ...typography.micro,
    fontFamily: 'gg-sans-semibold',
  },
  stateContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.xl,
    gap: spacing.md,
  },
  stateTitle: {
    ...typography.headingM,
    textAlign: 'center',
  },
  stateSubtitle: {
    ...typography.bodySmall,
    textAlign: 'center',
  },
  activeContainer: {
    flex: 1,
    padding: spacing.md,
  },
  webview: {
    flex: 1,
    borderRadius: borderRadius.lg,
    overflow: 'hidden',
  },
  webviewPlaceholder: {
    flex: 1,
    borderRadius: borderRadius.lg,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.md,
  },
  webviewText: {
    ...typography.headingM,
  },
  webviewSubtext: {
    ...typography.bodySmall,
  },
  webviewUrl: {
    ...typography.micro,
    marginTop: spacing.sm,
  },
  loadingOverlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 10,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.md,
  },
  loadingText: {
    ...typography.bodySmall,
  },
  errorOverlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 10,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.md,
    paddingHorizontal: spacing.xl,
  },
  errorText: {
    ...typography.bodySmall,
    textAlign: 'center',
  },
  retryBtn: {
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    marginTop: spacing.sm,
  },
  retryText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  endedCircle: {
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: spacing.sm,
  },
  errorMsg: {
    ...typography.caption,
    textAlign: 'center',
    marginTop: spacing.sm,
  },
  dismissBtn: {
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    marginTop: spacing.lg,
    minHeight: MINIMUM_TOUCH_TARGET,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dismissText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  participantsPanel: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
    maxHeight: 160,
  },
  panelTitle: {
    ...typography.overline,
    marginBottom: spacing.sm,
  },
  participantsList: {
    gap: spacing.sm,
  },
  participantRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  participantName: {
    ...typography.bodySmall,
    flex: 1,
  },
  hostBadge: {
    paddingHorizontal: spacing.sm,
    paddingVertical: 2,
    borderRadius: borderRadius.sm,
  },
  hostText: {
    ...typography.micro,
    fontFamily: 'gg-sans-bold',
  },
  actionBar: {
    flexDirection: 'row',
    gap: spacing.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.md,
  },
  endBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  endBtnText: {
    color: '#FFFFFF',
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
  leaveBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  leaveBtnText: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
  },
});
