/**
 * Events Screen
 *
 * Lists scheduled events with RSVP, create, and detail views.
 * Route: /server/[serverId]/events
 * Requirements: Feature 10 (Scheduled Events)
 */
import React, { useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Alert,
  ActivityIndicator,
  Modal,
  TextInput,
  ScrollView,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import * as eventService from '@services/eventService';
import type { ScheduledEvent } from '@services/eventService';
import { useAuthStore } from '@stores/authStore';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET, type ThemeColors } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

export default function EventsScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: any) => s.user);
  const [createVisible, setCreateVisible] = useState(false);

  const { data: events = [], isLoading, refetch } = useQuery({
    queryKey: ['server-events', serverId],
    queryFn: () => eventService.getServerEvents(serverId!),
    enabled: !!serverId,
  });

  const rsvpMutation = useMutation({
    mutationFn: ({ eventId, status }: { eventId: string; status: 'interested' | 'going' }) =>
      eventService.rsvpToEvent(eventId, user?.id!, status),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['server-events', serverId] }),
  });

  const formatDate = (dateStr: string) => {
    const d = new Date(dateStr);
    const now = new Date();
    const diff = d.getTime() - now.getTime();
    const days = Math.ceil(diff / 86400000);

    const time = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    if (days === 0) return `Today at ${time}`;
    if (days === 1) return `Tomorrow at ${time}`;
    return `${d.toLocaleDateString([], { month: 'short', day: 'numeric' })} at ${time}`;
  };

  const renderEvent = useCallback(
    ({ item }: { item: ScheduledEvent }) => (
      <Pressable
        style={[styles.eventCard, { backgroundColor: themeColors.cardBg }]}
        onPress={() => router.push(`/server/${serverId}/events/${item.id}` as any)}
      >
        {/* Status indicator */}
        <View style={styles.eventHeader}>
          <View
            style={[
              styles.statusDot,
              {
                backgroundColor:
                  item.status === 'active' ? themeColors.success :
                  item.status === 'scheduled' ? themeColors.accentPrimary :
                  themeColors.textMuted,
              },
            ]}
          />
          <Text style={[styles.eventDate, { color: themeColors.accentSecondary }]}>
            {formatDate(item.start_time)}
          </Text>
          {item.status === 'active' && (
            <View style={[styles.liveBadge, { backgroundColor: themeColors.success }]}>
              <Text style={styles.liveText}>LIVE</Text>
            </View>
          )}
        </View>

        <Text style={[styles.eventName, { color: themeColors.textPrimary }]} numberOfLines={2}>
          {item.name}
        </Text>

        {item.description && (
          <Text style={[styles.eventDesc, { color: themeColors.textSecondary }]} numberOfLines={2}>
            {item.description}
          </Text>
        )}

        {/* Location / Channel */}
        <View style={styles.eventMeta}>
          {item.channel ? (
            <View style={styles.metaItem}>
              <Ionicons name="chatbubble-outline" size={12} color={themeColors.textMuted} />
              <Text style={[styles.metaText, { color: themeColors.textMuted }]}>
                #{item.channel.name}
              </Text>
            </View>
          ) : item.location ? (
            <View style={styles.metaItem}>
              <Ionicons name="location-outline" size={12} color={themeColors.textMuted} />
              <Text style={[styles.metaText, { color: themeColors.textMuted }]}>
                {item.location}
              </Text>
            </View>
          ) : null}

          <View style={styles.metaItem}>
            <Ionicons name="star-outline" size={12} color={themeColors.textMuted} />
            <Text style={[styles.metaText, { color: themeColors.textMuted }]}>
              {item.interested_count ?? 0} interested
            </Text>
          </View>
        </View>

        {/* RSVP buttons */}
        <View style={styles.rsvpRow}>
          <Pressable
            style={[styles.rsvpBtn, { backgroundColor: themeColors.bgTertiary }]}
            onPress={() => rsvpMutation.mutate({ eventId: item.id, status: 'interested' })}
          >
            <Ionicons name="star-outline" size={14} color={themeColors.textSecondary} />
            <Text style={[styles.rsvpText, { color: themeColors.textSecondary }]}>Interested</Text>
          </Pressable>
        </View>
      </Pressable>
    ),
    [themeColors, serverId, rsvpMutation],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary, borderBottomColor: themeColors.border }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={[styles.backBtn, { backgroundColor: themeColors.bgTertiary }]}> 
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Events</Text>
          <Pressable onPress={() => setCreateVisible(true)} hitSlop={8} style={[styles.addBtn, { backgroundColor: themeColors.bgTertiary }]}> 
            <Ionicons name="add-circle-outline" size={24} color={themeColors.accentPrimary} />
          </Pressable>
        </View>

        <FlatList
          data={events}
          renderItem={renderEvent}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          refreshing={false}
          onRefresh={() => refetch()}
          ListEmptyComponent={
            isLoading ? (
              <ActivityIndicator style={styles.loader} color={themeColors.accentPrimary} />
            ) : (
              <View style={styles.emptyState}>
                <Ionicons name="calendar-outline" size={48} color={themeColors.textMuted} />
                <Text style={[styles.emptyText, { color: themeColors.textSecondary }]}>
                  No upcoming events
                </Text>
              </View>
            )
          }
        />

        {/* Create event modal */}
        <CreateEventModal
          visible={createVisible}
          onClose={() => setCreateVisible(false)}
          serverId={serverId!}
          themeColors={themeColors}
        />
      </View>
    </>
  );
}

// ─── Create Event Modal ────────────────────────────────────────────────────────

function CreateEventModal({
  visible,
  onClose,
  serverId,
  themeColors,
}: {
  visible: boolean;
  onClose: () => void;
  serverId: string;
  themeColors: ThemeColors;
}) {
  const user = useAuthStore((s: any) => s.user);
  const queryClient = useQueryClient();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [location, setLocation] = useState('');

  const createMutation = useMutation({
    mutationFn: () =>
      eventService.createEvent({
        serverId,
        name: name.trim(),
        description: description.trim() || undefined,
        startTime: new Date(Date.now() + 3600000).toISOString(), // 1hr from now default
        location: location.trim() || undefined,
        creatorId: user?.id!,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['server-events', serverId] });
      setName('');
      setDescription('');
      setLocation('');
      onClose();
    },
    onError: (err) => Alert.alert('Error', err.message),
  });

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={[styles.modalOverlay, { backgroundColor: themeColors.overlay }]}>
        <View style={[styles.modalContent, { backgroundColor: themeColors.bgSecondary }]}>
          <View style={[styles.modalHeader, { borderBottomColor: themeColors.border }]}>
            <Pressable onPress={onClose} hitSlop={12}>
              <Ionicons name="close" size={24} color={themeColors.textSecondary} />
            </Pressable>
            <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>Create Event</Text>
            <Pressable
              onPress={() => createMutation.mutate()}
              disabled={!name.trim() || createMutation.isPending}
              style={[styles.createBtn, { backgroundColor: name.trim() ? themeColors.accentPrimary : themeColors.bgTertiary }]}
            >
              {createMutation.isPending ? (
                <ActivityIndicator size="small" color="#fff" />
              ) : (
                <Text style={styles.createBtnText}>Create</Text>
              )}
            </Pressable>
          </View>
          <ScrollView style={styles.modalBody} keyboardShouldPersistTaps="handled">
            <TextInput
              style={[styles.textInput, { color: themeColors.textPrimary, backgroundColor: themeColors.inputBg, borderColor: themeColors.border }]}
              placeholder="Event name"
              placeholderTextColor={themeColors.textMuted}
              value={name}
              onChangeText={setName}
              autoFocus
            />
            <TextInput
              style={[styles.textInput, styles.multilineInput, { color: themeColors.textPrimary, backgroundColor: themeColors.inputBg, borderColor: themeColors.border }]}
              placeholder="Description (optional)"
              placeholderTextColor={themeColors.textMuted}
              value={description}
              onChangeText={setDescription}
              multiline
              textAlignVertical="top"
            />
            <TextInput
              style={[styles.textInput, { color: themeColors.textPrimary, backgroundColor: themeColors.inputBg, borderColor: themeColors.border }]}
              placeholder="Location (optional)"
              placeholderTextColor={themeColors.textMuted}
              value={location}
              onChangeText={setLocation}
            />
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: spacing.md, paddingBottom: spacing.md, borderBottomWidth: 1 },
  backBtn: { minWidth: MINIMUM_TOUCH_TARGET, minHeight: MINIMUM_TOUCH_TARGET, borderRadius: 18, justifyContent: 'center', alignItems: 'center' },
  headerTitle: { ...typography.headingM, flex: 1, marginLeft: spacing.sm },
  addBtn: { minWidth: MINIMUM_TOUCH_TARGET, minHeight: MINIMUM_TOUCH_TARGET, borderRadius: 18, justifyContent: 'center', alignItems: 'center' },
  listContent: { padding: spacing.md, gap: spacing.md },
  loader: { marginTop: spacing.xxxxl },
  emptyState: { alignItems: 'center', marginTop: spacing.xxxxl * 2, gap: spacing.md },
  emptyText: { ...typography.body },

  eventCard: { padding: spacing.lg, borderRadius: borderRadius.md },
  eventHeader: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.sm },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  eventDate: { ...typography.caption, fontFamily: 'gg-sans-semibold', flex: 1 },
  liveBadge: { paddingHorizontal: spacing.sm, paddingVertical: 1, borderRadius: borderRadius.sm },
  liveText: { color: '#fff', ...typography.micro, fontFamily: 'gg-sans-bold' },
  eventName: { ...typography.headingS, marginBottom: spacing.xs },
  eventDesc: { ...typography.bodySmall, marginBottom: spacing.sm },
  eventMeta: { flexDirection: 'row', gap: spacing.lg, marginBottom: spacing.md },
  metaItem: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  metaText: { ...typography.caption },
  rsvpRow: { flexDirection: 'row', gap: spacing.sm },
  rsvpBtn: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: spacing.md, paddingVertical: spacing.sm, borderRadius: borderRadius.sm, gap: spacing.xs },
  rsvpText: { ...typography.caption, fontFamily: 'gg-sans-semibold' },

  modalOverlay: { flex: 1, justifyContent: 'flex-end' },
  modalContent: { borderTopLeftRadius: borderRadius.xl, borderTopRightRadius: borderRadius.xl, maxHeight: '80%' },
  modalHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: spacing.lg, borderBottomWidth: 1 },
  modalTitle: { ...typography.headingM },
  modalBody: { padding: spacing.lg },
  createBtn: { paddingHorizontal: spacing.lg, paddingVertical: spacing.sm, borderRadius: borderRadius.sm },
  createBtnText: { color: '#fff', ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  textInput: { ...typography.body, padding: spacing.md, borderRadius: borderRadius.sm, borderWidth: 1, marginBottom: spacing.md },
  multilineInput: { minHeight: 80 },
});
