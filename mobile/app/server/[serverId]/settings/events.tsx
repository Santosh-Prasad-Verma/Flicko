/**
 * Events Settings Screen
 *
 * Create, view and manage scheduled server events.
 * Route: /server/[serverId]/settings/events
 */
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  TextInput,
  Alert,
  Modal,
  ActivityIndicator,
  Platform,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import {
  getServerEvents,
  createEvent,
  deleteEvent,
  updateEvent,
  type ScheduledEvent,
} from '@services/eventService';
import { useAuthStore } from '@stores/authStore';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

const STATUS_COLORS: Record<string, string> = {
  scheduled: '#5865F2',
  active: '#2ECC71',
  completed: '#95A5A6',
  cancelled: '#FF4757',
};

function formatDateTime(dateStr: string): string {
  const d = new Date(dateStr);
  return d.toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  });
}

export default function EventsScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: any) => s.user);

  const [showCreate, setShowCreate] = useState(false);
  const [eventName, setEventName] = useState('');
  const [eventDesc, setEventDesc] = useState('');
  const [eventLocation, setEventLocation] = useState('');
  const [eventDate, setEventDate] = useState('');
  const [eventTime, setEventTime] = useState('');
  const [eventEndDate, setEventEndDate] = useState('');
  const [eventEndTime, setEventEndTime] = useState('');

  const { data: events = [], isLoading } = useQuery({
    queryKey: ['server-events', serverId],
    queryFn: () => getServerEvents(serverId!),
    enabled: !!serverId,
  });

  const createMutation = useMutation({
    mutationFn: async () => {
      if (!eventName.trim()) throw new Error('Event name is required');
      if (!eventDate || !eventTime) throw new Error('Start date and time are required');

      const startTime = new Date(`${eventDate}T${eventTime}`).toISOString();
      const endTime = eventEndDate && eventEndTime
        ? new Date(`${eventEndDate}T${eventEndTime}`).toISOString()
        : undefined;

      return createEvent({
        serverId: serverId!,
        name: eventName.trim(),
        description: eventDesc.trim() || undefined,
        startTime,
        endTime,
        location: eventLocation.trim() || undefined,
        creatorId: user?.id!,
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['server-events', serverId] });
      setShowCreate(false);
      resetForm();
    },
    onError: (err) => Alert.alert('Error', err.message),
  });

  const deleteMutation = useMutation({
    mutationFn: (eventId: string) => deleteEvent(eventId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['server-events', serverId] }),
  });

  const cancelMutation = useMutation({
    mutationFn: (eventId: string) => updateEvent(eventId, { status: 'cancelled' }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['server-events', serverId] }),
  });

  const resetForm = () => {
    setEventName('');
    setEventDesc('');
    setEventLocation('');
    setEventDate('');
    setEventTime('');
    setEventEndDate('');
    setEventEndTime('');
  };

  const handleDelete = useCallback((event: ScheduledEvent) => {
    Alert.alert('Delete Event', `Delete "${event.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteMutation.mutate(event.id) },
    ]);
  }, [deleteMutation]);

  const handleCancel = useCallback((event: ScheduledEvent) => {
    Alert.alert('Cancel Event', `Cancel "${event.name}"? Attendees will be notified.`, [
      { text: 'Back', style: 'cancel' },
      { text: 'Cancel Event', style: 'destructive', onPress: () => cancelMutation.mutate(event.id) },
    ]);
  }, [cancelMutation]);

  const renderEvent = useCallback(
    ({ item }: { item: ScheduledEvent }) => (
      <View style={[styles.eventCard, { backgroundColor: themeColors.bgSecondary }]}>
        <View style={styles.eventHeader}>
          <View style={[styles.statusDot, { backgroundColor: STATUS_COLORS[item.status] || themeColors.textMuted }]} />
          <Text style={[styles.statusText, { color: STATUS_COLORS[item.status] || themeColors.textMuted }]}>
            {item.status.charAt(0).toUpperCase() + item.status.slice(1)}
          </Text>
        </View>

        <Text style={[styles.eventName, { color: themeColors.textPrimary }]}>{item.name}</Text>

        {item.description && (
          <Text style={[styles.eventDesc, { color: themeColors.textSecondary }]} numberOfLines={2}>
            {item.description}
          </Text>
        )}

        <View style={styles.eventMeta}>
          <Ionicons name="calendar-outline" size={14} color={themeColors.textMuted} />
          <Text style={[styles.metaText, { color: themeColors.textMuted }]}>
            {formatDateTime(item.start_time)}
            {item.end_time ? ` — ${formatDateTime(item.end_time)}` : ''}
          </Text>
        </View>

        {item.location && (
          <View style={styles.eventMeta}>
            <Ionicons name="location-outline" size={14} color={themeColors.textMuted} />
            <Text style={[styles.metaText, { color: themeColors.textMuted }]}>{item.location}</Text>
          </View>
        )}

        {item.channel && (
          <View style={styles.eventMeta}>
            <Ionicons name="chatbubble-outline" size={14} color={themeColors.textMuted} />
            <Text style={[styles.metaText, { color: themeColors.textMuted }]}>#{item.channel.name}</Text>
          </View>
        )}

        <View style={styles.eventMeta}>
          <Ionicons name="people-outline" size={14} color={themeColors.textMuted} />
          <Text style={[styles.metaText, { color: themeColors.textMuted }]}>
            {item.interested_count} interested
          </Text>
        </View>

        {item.creator && (
          <Text style={[styles.creatorText, { color: themeColors.textMuted }]}>
            Created by {item.creator.display_name || item.creator.username}
          </Text>
        )}

        <View style={styles.eventActions}>
          {item.status === 'scheduled' && (
            <Pressable
              onPress={() => handleCancel(item)}
              style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]}
            >
              <Ionicons name="close-outline" size={16} color={themeColors.warning} />
              <Text style={{ color: themeColors.warning, fontSize: 13 }}>Cancel</Text>
            </Pressable>
          )}
          <Pressable
            onPress={() => handleDelete(item)}
            style={[styles.actionBtn, { backgroundColor: themeColors.bgTertiary }]}
          >
            <Ionicons name="trash-outline" size={16} color={themeColors.danger} />
            <Text style={{ color: themeColors.danger, fontSize: 13 }}>Delete</Text>
          </Pressable>
        </View>
      </View>
    ),
    [themeColors, handleDelete, handleCancel],
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <View style={[styles.header, { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary }]}>
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
            Events ({events.length})
          </Text>
          <Pressable onPress={() => setShowCreate(true)} hitSlop={8} style={styles.addBtn}>
            <Ionicons name="add" size={24} color={themeColors.accentPrimary} />
          </Pressable>
        </View>

        {isLoading ? (
          <View style={styles.centered}>
            <ActivityIndicator size="large" color={themeColors.accentPrimary} />
          </View>
        ) : events.length === 0 ? (
          <View style={styles.centered}>
            <Ionicons name="calendar-outline" size={48} color={themeColors.textMuted} />
            <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>No events</Text>
            <Text style={[styles.emptyDesc, { color: themeColors.textMuted }]}>
              Schedule events for your community
            </Text>
            <Pressable
              onPress={() => setShowCreate(true)}
              style={[styles.createBtn, { backgroundColor: themeColors.accentPrimary }]}
            >
              <Ionicons name="add-circle-outline" size={18} color="#fff" />
              <Text style={styles.createBtnText}>Create Event</Text>
            </Pressable>
          </View>
        ) : (
          <FlatList
            data={events}
            renderItem={renderEvent}
            keyExtractor={(item) => item.id}
            contentContainerStyle={{ padding: spacing.md, paddingBottom: insets.bottom + 40 }}
          />
        )}

        {/* Create Modal */}
        <Modal visible={showCreate} animationType="slide" transparent>
          <View style={styles.modalOverlay}>
            <View style={[styles.modalContent, { backgroundColor: themeColors.bgSecondary }]}>
              <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>Create Event</Text>

              <Text style={[styles.label, { color: themeColors.textMuted }]}>EVENT NAME *</Text>
              <TextInput
                value={eventName}
                onChangeText={setEventName}
                maxLength={100}
                placeholder="Community Game Night"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <Text style={[styles.label, { color: themeColors.textMuted }]}>DESCRIPTION</Text>
              <TextInput
                value={eventDesc}
                onChangeText={setEventDesc}
                maxLength={1000}
                multiline
                placeholder="What's happening?"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, styles.multiline, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <Text style={[styles.label, { color: themeColors.textMuted }]}>LOCATION (optional)</Text>
              <TextInput
                value={eventLocation}
                onChangeText={setEventLocation}
                maxLength={100}
                placeholder="Voice channel, link, or place"
                placeholderTextColor={themeColors.textMuted}
                style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
              />

              <View style={styles.dateRow}>
                <View style={styles.dateField}>
                  <Text style={[styles.label, { color: themeColors.textMuted }]}>START DATE *</Text>
                  <TextInput
                    value={eventDate}
                    onChangeText={setEventDate}
                    placeholder="YYYY-MM-DD"
                    placeholderTextColor={themeColors.textMuted}
                    style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
                  />
                </View>
                <View style={styles.dateField}>
                  <Text style={[styles.label, { color: themeColors.textMuted }]}>START TIME *</Text>
                  <TextInput
                    value={eventTime}
                    onChangeText={setEventTime}
                    placeholder="HH:MM"
                    placeholderTextColor={themeColors.textMuted}
                    style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
                  />
                </View>
              </View>

              <View style={styles.dateRow}>
                <View style={styles.dateField}>
                  <Text style={[styles.label, { color: themeColors.textMuted }]}>END DATE</Text>
                  <TextInput
                    value={eventEndDate}
                    onChangeText={setEventEndDate}
                    placeholder="YYYY-MM-DD"
                    placeholderTextColor={themeColors.textMuted}
                    style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
                  />
                </View>
                <View style={styles.dateField}>
                  <Text style={[styles.label, { color: themeColors.textMuted }]}>END TIME</Text>
                  <TextInput
                    value={eventEndTime}
                    onChangeText={setEventEndTime}
                    placeholder="HH:MM"
                    placeholderTextColor={themeColors.textMuted}
                    style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.bgTertiary }]}
                  />
                </View>
              </View>

              <View style={styles.modalButtons}>
                <Pressable
                  onPress={() => { setShowCreate(false); resetForm(); }}
                  style={[styles.modalBtn, { backgroundColor: themeColors.bgTertiary }]}
                >
                  <Text style={{ color: themeColors.textPrimary }}>Cancel</Text>
                </Pressable>
                <Pressable
                  onPress={() => createMutation.mutate()}
                  disabled={!eventName.trim() || !eventDate || !eventTime || createMutation.isPending}
                  style={[styles.modalBtn, {
                    backgroundColor: themeColors.accentPrimary,
                    opacity: eventName.trim() && eventDate && eventTime ? 1 : 0.4,
                  }]}
                >
                  {createMutation.isPending ? (
                    <ActivityIndicator size="small" color="#fff" />
                  ) : (
                    <Text style={{ color: '#fff', fontFamily: 'gg-sans-semibold' }}>Create</Text>
                  )}
                </Pressable>
              </View>
            </View>
          </View>
        </Modal>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255,255,255,0.05)',
  },
  backBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: { ...typography.headingS, flex: 1, marginLeft: spacing.sm },
  addBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  centered: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: spacing.xl },
  emptyTitle: { fontSize: 18, fontFamily: 'gg-sans-semibold', marginTop: spacing.md },
  emptyDesc: { fontSize: 14, marginTop: spacing.xs, textAlign: 'center' },
  createBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    marginTop: spacing.lg,
  },
  createBtnText: { color: '#fff', fontFamily: 'gg-sans-semibold', fontSize: 15 },
  // Event card
  eventCard: {
    padding: spacing.md,
    borderRadius: borderRadius.md,
    marginBottom: spacing.md,
  },
  eventHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginBottom: spacing.sm,
  },
  statusDot: { width: 8, height: 8, borderRadius: 4 },
  statusText: { fontSize: 12, fontFamily: 'gg-sans-semibold', textTransform: 'uppercase', letterSpacing: 0.5 },
  eventName: { fontSize: 17, fontFamily: 'gg-sans-bold', marginBottom: spacing.xs },
  eventDesc: { fontSize: 14, marginBottom: spacing.sm, lineHeight: 20 },
  eventMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginTop: 4,
  },
  metaText: { fontSize: 13 },
  creatorText: { fontSize: 12, marginTop: spacing.sm, fontStyle: 'italic' },
  eventActions: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.md,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: 'rgba(255,255,255,0.05)',
    paddingTop: spacing.md,
  },
  actionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: spacing.md,
    paddingVertical: 8,
    borderRadius: borderRadius.sm,
  },
  // Modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: spacing.lg,
    paddingBottom: 40,
    maxHeight: '90%',
  },
  modalTitle: { ...typography.headingS, marginBottom: spacing.md },
  label: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.xs,
    marginTop: spacing.md,
  },
  input: {
    borderRadius: borderRadius.md,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    fontSize: 15,
  },
  multiline: { minHeight: 80, textAlignVertical: 'top' },
  dateRow: {
    flexDirection: 'row',
    gap: spacing.md,
  },
  dateField: { flex: 1 },
  modalButtons: {
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.xl,
  },
  modalBtn: {
    flex: 1,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
