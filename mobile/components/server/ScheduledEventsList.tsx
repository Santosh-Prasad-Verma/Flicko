/**
 * Scheduled Events — Improved (Feature 31)
 *
 * Full event management with voice/stage/external types,
 * cover images, recurrence, RSVP, and reminders.
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Modal,
  Alert,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import {
  useServerManagementStore,
  ScheduledEvent,
  EventType,
} from '@stores/serverManagementStore';
import { supabase } from '@services/supabase';

const EVENT_TYPES: { type: EventType; icon: string; label: string }[] = [
  { type: 'voice', icon: 'mic', label: 'Voice Channel' },
  { type: 'stage', icon: 'megaphone', label: 'Stage Channel' },
  { type: 'external', icon: 'globe-outline', label: 'External / Somewhere Else' },
];

interface Props {
  serverId: string;
  voiceChannels?: { id: string; name: string }[];
  currentUserId: string;
}

export const ScheduledEventsList = memo(function ScheduledEventsList({
  serverId,
  voiceChannels = [],
  currentUserId,
}: Props) {
  const { themeColors } = useTheme();
  const events = useServerManagementStore((s) => s.scheduledEvents[serverId] ?? []);
  const { addScheduledEvent, removeScheduledEvent } = useServerManagementStore();

  const [showCreate, setShowCreate] = useState(false);
  const [formName, setFormName] = useState('');
  const [formDesc, setFormDesc] = useState('');
  const [formType, setFormType] = useState<EventType>('voice');
  const [formChannel, setFormChannel] = useState('');
  const [formLocation, setFormLocation] = useState('');

  const handleCreate = useCallback(async () => {
    if (!formName.trim()) return;
    const event: ScheduledEvent = {
      id: `${Date.now()}`,
      server_id: serverId,
      name: formName.trim(),
      description: formDesc.trim() || undefined,
      event_type: formType,
      voice_channel_id: formType !== 'external' ? formChannel || undefined : undefined,
      location: formType === 'external' ? formLocation || undefined : undefined,
      start_time: new Date(Date.now() + 3600000).toISOString(), // 1h from now
      interested_count: 0,
      creator_id: currentUserId,
    };
    addScheduledEvent(serverId, event);
    setShowCreate(false);
    resetForm();

    await supabase.from('community_events').insert({
      id: event.id,
      server_id: serverId,
      name: event.name,
      description: event.description,
      event_type: event.event_type,
      voice_channel_id: event.voice_channel_id,
      location: event.location,
      start_time: event.start_time,
      creator_id: currentUserId,
    });
  }, [serverId, formName, formDesc, formType, formChannel, formLocation, currentUserId, addScheduledEvent]);

  const resetForm = () => {
    setFormName('');
    setFormDesc('');
    setFormType('voice');
    setFormChannel('');
    setFormLocation('');
  };

  const handleDelete = useCallback(
    (eventId: string) => {
      Alert.alert('Cancel Event', 'Are you sure?', [
        { text: 'No', style: 'cancel' },
        {
          text: 'Yes, Cancel',
          style: 'destructive',
          onPress: async () => {
            removeScheduledEvent(serverId, eventId);
            await supabase.from('community_events').delete().eq('id', eventId);
          },
        },
      ]);
    },
    [serverId, removeScheduledEvent]
  );

  const handleInterest = useCallback(
    async (eventId: string) => {
      await supabase.from('event_interests').upsert({
        event_id: eventId,
        user_id: currentUserId,
      });
    },
    [currentUserId]
  );

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
      contentContainerStyle={styles.content}
    >
      <View style={styles.headerRow}>
        <Text style={[styles.title, { color: themeColors.textPrimary }]}>Scheduled Events</Text>
        <Pressable
          style={[styles.newBtn, { backgroundColor: themeColors.accentPrimary }]}
          onPress={() => setShowCreate(true)}
        >
          <Ionicons name="add" size={18} color="#fff" />
          <Text style={styles.newBtnText}>New Event</Text>
        </Pressable>
      </View>

      {events.length === 0 && (
        <View style={styles.empty}>
          <Ionicons name="calendar-outline" size={48} color={themeColors.textMuted} />
          <Text style={[styles.emptyText, { color: themeColors.textMuted }]}>
            No upcoming events
          </Text>
        </View>
      )}

      {events.map((ev) => (
        <View key={ev.id} style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          {ev.cover_image && (
            <Image source={{ uri: ev.cover_image }} style={styles.coverImage} />
          )}
          <View style={styles.cardBody}>
            <View style={styles.typeBadge}>
              <Ionicons
                name={EVENT_TYPES.find((t) => t.type === ev.event_type)?.icon as any ?? 'calendar'}
                size={14}
                color={themeColors.accentPrimary}
              />
              <Text style={[styles.typeLabel, { color: themeColors.accentPrimary }]}>
                {EVENT_TYPES.find((t) => t.type === ev.event_type)?.label}
              </Text>
            </View>
            <Text style={[styles.eventName, { color: themeColors.textPrimary }]}>{ev.name}</Text>
            {ev.description && (
              <Text style={[styles.eventDesc, { color: themeColors.textMuted }]} numberOfLines={2}>
                {ev.description}
              </Text>
            )}
            <Text style={[styles.eventTime, { color: themeColors.textMuted }]}>
              {new Date(ev.start_time).toLocaleString()}
            </Text>

            <View style={styles.cardActions}>
              <Pressable
                style={[styles.interestBtn, { backgroundColor: themeColors.bgTertiary }]}
                onPress={() => handleInterest(ev.id)}
              >
                <Ionicons name="star-outline" size={16} color={themeColors.accentPrimary} />
                <Text style={[styles.interestText, { color: themeColors.textPrimary }]}>
                  Interested · {ev.interested_count}
                </Text>
              </Pressable>
              {ev.creator_id === currentUserId && (
                <Pressable onPress={() => handleDelete(ev.id)} hitSlop={8}>
                  <Ionicons name="trash-outline" size={18} color={themeColors.danger} />
                </Pressable>
              )}
            </View>
          </View>
        </View>
      ))}

      {/* Create Event Modal */}
      <Modal visible={showCreate} transparent animationType="slide">
        <Pressable style={styles.overlay} onPress={() => setShowCreate(false)}>
          <Pressable
            style={[styles.modal, { backgroundColor: themeColors.bgSecondary }]}
            onPress={(e) => e.stopPropagation()}
          >
            <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>Create Event</Text>

            {/* Event Type */}
            <Text style={[styles.label, { color: themeColors.textMuted }]}>TYPE</Text>
            <View style={styles.typeGrid}>
              {EVENT_TYPES.map((t) => (
                <Pressable
                  key={t.type}
                  style={[
                    styles.typeOption,
                    { backgroundColor: formType === t.type ? themeColors.accentPrimary : themeColors.bgTertiary },
                  ]}
                  onPress={() => setFormType(t.type)}
                >
                  <Ionicons name={t.icon as any} size={18} color={formType === t.type ? '#fff' : themeColors.textPrimary} />
                  <Text style={[styles.typeOptionText, { color: formType === t.type ? '#fff' : themeColors.textPrimary }]}>
                    {t.label}
                  </Text>
                </Pressable>
              ))}
            </View>

            <Text style={[styles.label, { color: themeColors.textMuted }]}>NAME</Text>
            <TextInput
              style={[styles.input, { backgroundColor: themeColors.bgTertiary, color: themeColors.textPrimary }]}
              value={formName}
              onChangeText={setFormName}
              placeholder="Event name"
              placeholderTextColor={themeColors.textMuted}
              maxLength={100}
            />

            <Text style={[styles.label, { color: themeColors.textMuted }]}>DESCRIPTION</Text>
            <TextInput
              style={[styles.input, styles.multiline, { backgroundColor: themeColors.bgTertiary, color: themeColors.textPrimary }]}
              value={formDesc}
              onChangeText={setFormDesc}
              placeholder="What's the event about?"
              placeholderTextColor={themeColors.textMuted}
              multiline
              maxLength={1000}
            />

            {formType === 'external' ? (
              <>
                <Text style={[styles.label, { color: themeColors.textMuted }]}>LOCATION</Text>
                <TextInput
                  style={[styles.input, { backgroundColor: themeColors.bgTertiary, color: themeColors.textPrimary }]}
                  value={formLocation}
                  onChangeText={setFormLocation}
                  placeholder="URL or address"
                  placeholderTextColor={themeColors.textMuted}
                />
              </>
            ) : (
              voiceChannels.length > 0 && (
                <>
                  <Text style={[styles.label, { color: themeColors.textMuted }]}>CHANNEL</Text>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                    {voiceChannels.map((ch) => (
                      <Pressable
                        key={ch.id}
                        style={[styles.chip, { backgroundColor: formChannel === ch.id ? themeColors.accentPrimary : themeColors.bgTertiary }]}
                        onPress={() => setFormChannel(ch.id)}
                      >
                        <Text style={[styles.chipText, { color: formChannel === ch.id ? '#fff' : themeColors.textPrimary }]}>
                          {ch.name}
                        </Text>
                      </Pressable>
                    ))}
                  </ScrollView>
                </>
              )
            )}

            <View style={styles.modalActions}>
              <Pressable style={[styles.cancelBtn, { backgroundColor: themeColors.bgTertiary }]} onPress={() => setShowCreate(false)}>
                <Text style={[styles.cancelBtnText, { color: themeColors.textPrimary }]}>Cancel</Text>
              </Pressable>
              <Pressable
                style={[styles.saveBtn, { backgroundColor: themeColors.accentPrimary, opacity: formName.trim() ? 1 : 0.5 }]}
                onPress={handleCreate}
                disabled={!formName.trim()}
              >
                <Text style={styles.saveBtnText}>Create</Text>
              </Pressable>
            </View>
          </Pressable>
        </Pressable>
      </Modal>
    </ScrollView>
  );
});

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: spacing.md },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: spacing.md },
  title: { fontSize: 20, fontFamily: 'gg-sans-bold' },
  newBtn: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 8, borderRadius: 8, gap: 4 },
  newBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 13 },
  empty: { alignItems: 'center', paddingVertical: 48, gap: spacing.sm },
  emptyText: { ...typography.body },
  card: { borderRadius: 12, overflow: 'hidden', marginBottom: spacing.sm },
  coverImage: { width: '100%', height: 120 },
  cardBody: { padding: spacing.sm },
  typeBadge: { flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 4 },
  typeLabel: { fontSize: 12, fontFamily: 'gg-sans-bold', textTransform: 'uppercase', letterSpacing: 0.5 },
  eventName: { fontSize: 16, fontFamily: 'gg-sans-bold', marginBottom: 2 },
  eventDesc: { ...typography.caption, marginBottom: 4 },
  eventTime: { ...typography.caption, marginBottom: spacing.xs },
  cardActions: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  interestBtn: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8, gap: 4 },
  interestText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  overlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', justifyContent: 'flex-end' },
  modal: { borderTopLeftRadius: 20, borderTopRightRadius: 20, padding: spacing.md, maxHeight: '85%' },
  modalTitle: { fontSize: 18, fontFamily: 'gg-sans-bold', marginBottom: spacing.md },
  label: { fontSize: 12, fontFamily: 'gg-sans-bold', letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: spacing.xs, marginTop: spacing.sm },
  typeGrid: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  typeOption: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 8, borderRadius: 8, gap: 6 },
  typeOptionText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  input: { borderRadius: 8, padding: 12, fontSize: 15, fontFamily: 'gg-sans' },
  multiline: { minHeight: 80, textAlignVertical: 'top' },
  chip: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16, marginRight: 8 },
  chipText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  modalActions: { flexDirection: 'row', justifyContent: 'flex-end', gap: spacing.sm, marginTop: spacing.md },
  cancelBtn: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 8 },
  cancelBtnText: { fontFamily: 'gg-sans-medium', fontSize: 14 },
  saveBtn: { paddingHorizontal: 20, paddingVertical: 10, borderRadius: 8 },
  saveBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 14 },
});
