/**
 * Stage Channel Moderation Controls (Feature 32)
 *
 * Manages stage channel speaker/audience separation,
 * request-to-speak flow, and moderator controls.
 */
import React, { memo, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  FlatList,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Avatar } from '../ui/Avatar';
import { useTheme } from '../../hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import {
  useServerManagementStore,
  SpeakerRequest,
} from '@stores/serverManagementStore';

interface StageUser {
  id: string;
  username: string;
  display_name?: string;
  avatar_url?: string;
  isSpeaker: boolean;
  isMuted?: boolean;
}

interface Props {
  channelId: string;
  users: StageUser[];
  isModerator: boolean;
  currentUserId: string;
  onMoveToSpeaker: (userId: string) => void;
  onMoveToAudience: (userId: string) => void;
  onMuteUser: (userId: string) => void;
  onDisconnectUser: (userId: string) => void;
  onRequestToSpeak: () => void;
}

export const StageModeration = memo(function StageModeration({
  channelId,
  users,
  isModerator,
  currentUserId,
  onMoveToSpeaker,
  onMoveToAudience,
  onMuteUser,
  onDisconnectUser,
  onRequestToSpeak,
}: Props) {
  const { themeColors } = useTheme();
  const stageInstance = useServerManagementStore((s) => s.stageInstances[channelId]);
  const requests = useServerManagementStore((s) => s.speakerRequests[channelId] ?? []);
  const updateRequest = useServerManagementStore((s) => s.updateSpeakerRequest);

  const speakers = users.filter((u) => u.isSpeaker);
  const audience = users.filter((u) => !u.isSpeaker);
  const pendingRequests = requests.filter((r) => r.status === 'pending');
  const currentUserIsSpeaker = speakers.some((u) => u.id === currentUserId);

  const handleApprove = useCallback(
    (userId: string) => {
      updateRequest(channelId, userId, 'approved');
      onMoveToSpeaker(userId);
    },
    [channelId, updateRequest, onMoveToSpeaker]
  );

  const handleDeny = useCallback(
    (userId: string) => {
      updateRequest(channelId, userId, 'denied');
    },
    [channelId, updateRequest]
  );

  const renderUser = (user: StageUser, section: 'speaker' | 'audience') => (
    <View key={user.id} style={styles.userRow}>
      <Avatar name={user.display_name || user.username} imageUrl={user.avatar_url} size={36} />
      <View style={{ flex: 1 }}>
        <Text style={[styles.userName, { color: themeColors.textPrimary }]}>
          {user.display_name || user.username}
        </Text>
        {user.isMuted && (
          <Text style={[styles.mutedLabel, { color: themeColors.textMuted }]}>Muted</Text>
        )}
      </View>

      {isModerator && (
        <View style={styles.modActions}>
          {section === 'speaker' ? (
            <>
              <Pressable
                style={[styles.modBtn, { backgroundColor: themeColors.bgTertiary }]}
                onPress={() => onMuteUser(user.id)}
              >
                <Ionicons name={user.isMuted ? 'mic' : 'mic-off'} size={16} color={themeColors.textMuted} />
              </Pressable>
              <Pressable
                style={[styles.modBtn, { backgroundColor: themeColors.bgTertiary }]}
                onPress={() => onMoveToAudience(user.id)}
              >
                <Ionicons name="arrow-down" size={16} color={themeColors.textMuted} />
              </Pressable>
            </>
          ) : (
            <Pressable
              style={[styles.modBtn, { backgroundColor: themeColors.bgTertiary }]}
              onPress={() => onMoveToSpeaker(user.id)}
            >
              <Ionicons name="arrow-up" size={16} color={themeColors.accentPrimary} />
            </Pressable>
          )}
          <Pressable
            style={[styles.modBtn, { backgroundColor: themeColors.bgTertiary }]}
            onPress={() => {
              Alert.alert('Disconnect', `Remove ${user.display_name || user.username}?`, [
                { text: 'Cancel', style: 'cancel' },
                { text: 'Disconnect', style: 'destructive', onPress: () => onDisconnectUser(user.id) },
              ]);
            }}
          >
            <Ionicons name="close" size={16} color={themeColors.danger} />
          </Pressable>
        </View>
      )}
    </View>
  );

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      {/* Stage Topic */}
      {stageInstance && (
        <View style={[styles.topicBar, { backgroundColor: themeColors.bgSecondary }]}>
          <Ionicons name="megaphone" size={18} color={themeColors.accentPrimary} />
          <Text style={[styles.topicText, { color: themeColors.textPrimary }]} numberOfLines={1}>
            {stageInstance.topic}
          </Text>
        </View>
      )}

      {/* Pending Requests */}
      {isModerator && pendingRequests.length > 0 && (
        <View style={[styles.section, { backgroundColor: themeColors.bgSecondary }]}>
          <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>
            SPEAKER REQUESTS ({pendingRequests.length})
          </Text>
          {pendingRequests.map((req) => {
            const user = users.find((u) => u.id === req.user_id);
            return (
              <View key={req.user_id} style={styles.requestRow}>
                <Avatar name={user?.display_name || user?.username || '?'} imageUrl={user?.avatar_url} size={32} />
                <Text style={[styles.userName, { color: themeColors.textPrimary, flex: 1 }]}>
                  {user?.display_name || user?.username || 'Unknown'}
                </Text>
                <Pressable
                  style={[styles.approveBtn, { backgroundColor: themeColors.accentPrimary }]}
                  onPress={() => handleApprove(req.user_id)}
                >
                  <Ionicons name="checkmark" size={16} color="#fff" />
                </Pressable>
                <Pressable
                  style={[styles.denyBtn, { backgroundColor: themeColors.bgTertiary }]}
                  onPress={() => handleDeny(req.user_id)}
                >
                  <Ionicons name="close" size={16} color={themeColors.danger} />
                </Pressable>
              </View>
            );
          })}
        </View>
      )}

      {/* Speakers */}
      <View style={[styles.section, { backgroundColor: themeColors.bgSecondary }]}>
        <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>
          SPEAKERS — {speakers.length}
        </Text>
        {speakers.map((u) => renderUser(u, 'speaker'))}
      </View>

      {/* Audience */}
      <View style={[styles.section, { backgroundColor: themeColors.bgSecondary }]}>
        <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>
          AUDIENCE — {audience.length}
        </Text>
        {audience.map((u) => renderUser(u, 'audience'))}
      </View>

      {/* Request to Speak button (for audience members) */}
      {!currentUserIsSpeaker && !isModerator && (
        <Pressable
          style={[styles.requestBtn, { backgroundColor: themeColors.accentPrimary }]}
          onPress={onRequestToSpeak}
        >
          <Ionicons name="hand-left" size={18} color="#fff" />
          <Text style={styles.requestBtnText}>Request to Speak</Text>
        </Pressable>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: { flex: 1, padding: spacing.md },
  topicBar: { flexDirection: 'row', alignItems: 'center', padding: spacing.sm, borderRadius: 10, gap: spacing.xs, marginBottom: spacing.md },
  topicText: { fontSize: 15, fontFamily: 'gg-sans-medium', flex: 1 },
  section: { borderRadius: 12, marginBottom: spacing.sm, overflow: 'hidden' },
  sectionLabel: { fontSize: 12, fontFamily: 'gg-sans-bold', letterSpacing: 0.5, textTransform: 'uppercase', padding: spacing.sm, paddingBottom: 4 },
  userRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.sm, gap: spacing.sm },
  userName: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  mutedLabel: { ...typography.caption },
  modActions: { flexDirection: 'row', gap: 6 },
  modBtn: { width: 32, height: 32, borderRadius: 16, justifyContent: 'center', alignItems: 'center' },
  requestRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.sm, gap: spacing.sm },
  approveBtn: { width: 32, height: 32, borderRadius: 16, justifyContent: 'center', alignItems: 'center' },
  denyBtn: { width: 32, height: 32, borderRadius: 16, justifyContent: 'center', alignItems: 'center' },
  requestBtn: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingVertical: 14, borderRadius: 10, gap: spacing.xs, marginTop: spacing.sm },
  requestBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 15 },
});
