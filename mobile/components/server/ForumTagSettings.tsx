/**
 * Forum Channel Tags & Settings (Feature 33)
 *
 * Admin controls for forum channel tags, required tags,
 * sort order, default reaction, and post guidelines.
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Switch,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import {
  useServerManagementStore,
  ForumTag,
  ForumSettings,
} from '@stores/serverManagementStore';
import { supabase } from '@services/supabase';

const ARCHIVE_OPTIONS = [
  { label: '1 hour', hours: 1 },
  { label: '24 hours', hours: 24 },
  { label: '3 days', hours: 72 },
  { label: '1 week', hours: 168 },
];

interface Props {
  channelId: string;
}

export const ForumTagSettings = memo(function ForumTagSettings({ channelId }: Props) {
  const { themeColors } = useTheme();
  const tags = useServerManagementStore((s) => s.forumTags[channelId] ?? []);
  const settings = useServerManagementStore(
    (s) => s.forumSettings[channelId] ?? {
      require_tag: false,
      default_sort: 'latest_activity',
      auto_archive_hours: 24,
    }
  );
  const { setForumTags, setForumSettings } = useServerManagementStore();

  const [newTagName, setNewTagName] = useState('');
  const [newTagEmoji, setNewTagEmoji] = useState('');
  const [editGuidelines, setEditGuidelines] = useState(settings.guidelines ?? '');
  const [showGuidelines, setShowGuidelines] = useState(false);

  const handleAddTag = useCallback(async () => {
    if (!newTagName.trim() || tags.length >= 20) return;
    const tag: ForumTag = {
      id: `${Date.now()}`,
      channel_id: channelId,
      name: newTagName.trim(),
      emoji: newTagEmoji || undefined,
      moderated: false,
    };
    setForumTags(channelId, [...tags, tag]);
    setNewTagName('');
    setNewTagEmoji('');

    await supabase.from('forum_tags').insert(tag);
  }, [channelId, newTagName, newTagEmoji, tags, setForumTags]);

  const handleRemoveTag = useCallback(
    async (tagId: string) => {
      setForumTags(channelId, tags.filter((t) => t.id !== tagId));
      await supabase.from('forum_tags').delete().eq('id', tagId);
    },
    [channelId, tags, setForumTags]
  );

  const handleToggleModerated = useCallback(
    async (tagId: string) => {
      const updated = tags.map((t) =>
        t.id === tagId ? { ...t, moderated: !t.moderated } : t
      );
      setForumTags(channelId, updated);
      const tag = updated.find((t) => t.id === tagId);
      if (tag) {
        await supabase.from('forum_tags').update({ moderated: tag.moderated }).eq('id', tagId);
      }
    },
    [channelId, tags, setForumTags]
  );

  const handleUpdateSettings = useCallback(
    async (partial: Partial<ForumSettings>) => {
      const updated = { ...settings, ...partial } as ForumSettings;
      setForumSettings(channelId, updated);
      await supabase
        .from('channels')
        .update({
          forum_require_tag: updated.require_tag,
          forum_default_sort: updated.default_sort,
          forum_guidelines: updated.guidelines,
          auto_archive_hours: updated.auto_archive_hours,
          forum_default_reaction: updated.default_reaction,
        })
        .eq('id', channelId);
    },
    [channelId, settings, setForumSettings]
  );

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
      contentContainerStyle={styles.content}
    >
      <Text style={[styles.title, { color: themeColors.textPrimary }]}>Forum Settings</Text>

      {/* Tags */}
      <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>
        TAGS ({tags.length}/20)
      </Text>
      <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
        {tags.map((tag) => (
          <View key={tag.id} style={styles.tagRow}>
            <Text style={styles.tagEmoji}>{tag.emoji || '🏷️'}</Text>
            <Text style={[styles.tagName, { color: themeColors.textPrimary }]}>{tag.name}</Text>
            {tag.moderated && (
              <Ionicons name="shield-checkmark" size={14} color={themeColors.accentPrimary} />
            )}
            <View style={{ flex: 1 }} />
            <Pressable onPress={() => handleToggleModerated(tag.id)} hitSlop={8}>
              <Ionicons
                name={tag.moderated ? 'lock-closed' : 'lock-open'}
                size={16}
                color={themeColors.textMuted}
              />
            </Pressable>
            <Pressable onPress={() => handleRemoveTag(tag.id)} hitSlop={8}>
              <Ionicons name="close-circle" size={18} color={themeColors.danger} />
            </Pressable>
          </View>
        ))}

        {/* Add tag */}
        <View style={styles.addTagRow}>
          <Pressable
            style={[styles.emojiBtn, { backgroundColor: themeColors.bgTertiary }]}
            onPress={() => {
              const emojis = ['🎮', '🎨', '📸', '🎵', '💡', '🐛', '📢', '❓'];
              const cur = emojis.indexOf(newTagEmoji);
              setNewTagEmoji(emojis[(cur + 1) % emojis.length]);
            }}
          >
            <Text style={styles.emojiText}>{newTagEmoji || '+'}</Text>
          </Pressable>
          <TextInput
            style={[styles.tagInput, { backgroundColor: themeColors.bgTertiary, color: themeColors.textPrimary }]}
            value={newTagName}
            onChangeText={setNewTagName}
            placeholder="New tag name"
            placeholderTextColor={themeColors.textMuted}
            maxLength={20}
          />
          <Pressable
            style={[styles.addBtn, { backgroundColor: themeColors.accentPrimary, opacity: newTagName.trim() ? 1 : 0.5 }]}
            onPress={handleAddTag}
            disabled={!newTagName.trim()}
          >
            <Ionicons name="add" size={18} color="#fff" />
          </Pressable>
        </View>
      </View>

      {/* Settings */}
      <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>OPTIONS</Text>
      <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
        <View style={styles.settingRow}>
          <Text style={[styles.settingLabel, { color: themeColors.textPrimary }]}>
            Require Tag on Posts
          </Text>
          <Switch
            value={settings.require_tag}
            onValueChange={(v) => handleUpdateSettings({ require_tag: v })}
            trackColor={{ true: themeColors.accentPrimary }}
          />
        </View>

        <View style={styles.settingRow}>
          <Text style={[styles.settingLabel, { color: themeColors.textPrimary }]}>
            Default Sort
          </Text>
          <View style={styles.sortToggle}>
            {(['latest_activity', 'creation_date'] as const).map((sort) => (
              <Pressable
                key={sort}
                style={[
                  styles.sortBtn,
                  { backgroundColor: settings.default_sort === sort ? themeColors.accentPrimary : themeColors.bgTertiary },
                ]}
                onPress={() => handleUpdateSettings({ default_sort: sort })}
              >
                <Text
                  style={[
                    styles.sortBtnText,
                    { color: settings.default_sort === sort ? '#fff' : themeColors.textPrimary },
                  ]}
                >
                  {sort === 'latest_activity' ? 'Activity' : 'Created'}
                </Text>
              </Pressable>
            ))}
          </View>
        </View>

        <View style={styles.settingRow}>
          <Text style={[styles.settingLabel, { color: themeColors.textPrimary }]}>
            Auto-Archive After
          </Text>
        </View>
        <View style={styles.archiveRow}>
          {ARCHIVE_OPTIONS.map((opt) => (
            <Pressable
              key={opt.hours}
              style={[
                styles.archiveBtn,
                { backgroundColor: settings.auto_archive_hours === opt.hours ? themeColors.accentPrimary : themeColors.bgTertiary },
              ]}
              onPress={() => handleUpdateSettings({ auto_archive_hours: opt.hours })}
            >
              <Text
                style={[
                  styles.archiveBtnText,
                  { color: settings.auto_archive_hours === opt.hours ? '#fff' : themeColors.textPrimary },
                ]}
              >
                {opt.label}
              </Text>
            </Pressable>
          ))}
        </View>
      </View>

      {/* Post Guidelines */}
      <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>POST GUIDELINES</Text>
      <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
        <Pressable
          style={styles.guidelinesToggle}
          onPress={() => setShowGuidelines(!showGuidelines)}
        >
          <Text style={[styles.settingLabel, { color: themeColors.textPrimary }]}>
            {settings.guidelines ? 'Edit Guidelines' : 'Add Guidelines'}
          </Text>
          <Ionicons
            name={showGuidelines ? 'chevron-up' : 'chevron-down'}
            size={18}
            color={themeColors.textMuted}
          />
        </Pressable>
        {showGuidelines && (
          <>
            <TextInput
              style={[styles.guidelinesInput, { backgroundColor: themeColors.bgTertiary, color: themeColors.textPrimary }]}
              value={editGuidelines}
              onChangeText={setEditGuidelines}
              placeholder="Write guidelines shown when creating a new post..."
              placeholderTextColor={themeColors.textMuted}
              multiline
              maxLength={3000}
            />
            <Pressable
              style={[styles.saveGuidelinesBtn, { backgroundColor: themeColors.accentPrimary }]}
              onPress={() => {
                handleUpdateSettings({ guidelines: editGuidelines.trim() || undefined });
                setShowGuidelines(false);
              }}
            >
              <Text style={styles.saveGuidelinesBtnText}>Save</Text>
            </Pressable>
          </>
        )}
      </View>
    </ScrollView>
  );
});

/**
 * Tag picker shown when creating a forum post
 */
export const ForumTagPicker = memo(function ForumTagPicker({
  channelId,
  selectedTags,
  onToggleTag,
}: {
  channelId: string;
  selectedTags: string[];
  onToggleTag: (tagId: string) => void;
}) {
  const { themeColors } = useTheme();
  const tags = useServerManagementStore((s) => s.forumTags[channelId] ?? []);

  if (tags.length === 0) return null;

  return (
    <View style={pickerStyles.container}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        {tags.map((tag) => {
          const selected = selectedTags.includes(tag.id);
          return (
            <Pressable
              key={tag.id}
              style={[
                pickerStyles.tag,
                { backgroundColor: selected ? themeColors.accentPrimary : themeColors.bgTertiary },
              ]}
              onPress={() => onToggleTag(tag.id)}
            >
              {tag.emoji && <Text style={pickerStyles.emoji}>{tag.emoji}</Text>}
              <Text style={[pickerStyles.tagText, { color: selected ? '#fff' : themeColors.textPrimary }]}>
                {tag.name}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>
    </View>
  );
});

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: spacing.md },
  title: { fontSize: 20, fontFamily: 'gg-sans-bold', marginBottom: spacing.md },
  sectionLabel: { fontSize: 12, fontFamily: 'gg-sans-bold', letterSpacing: 0.5, textTransform: 'uppercase', marginBottom: spacing.xs, marginTop: spacing.sm },
  card: { borderRadius: 12, overflow: 'hidden', marginBottom: spacing.sm },
  tagRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.sm, gap: spacing.xs },
  tagEmoji: { fontSize: 18 },
  tagName: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  addTagRow: { flexDirection: 'row', alignItems: 'center', padding: spacing.sm, gap: spacing.xs },
  emojiBtn: { width: 36, height: 36, borderRadius: 18, justifyContent: 'center', alignItems: 'center' },
  emojiText: { fontSize: 18 },
  tagInput: { flex: 1, height: 36, borderRadius: 8, paddingHorizontal: 12, fontSize: 14, fontFamily: 'gg-sans' },
  addBtn: { width: 36, height: 36, borderRadius: 18, justifyContent: 'center', alignItems: 'center' },
  settingRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: spacing.sm },
  settingLabel: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  sortToggle: { flexDirection: 'row', gap: 6 },
  sortBtn: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8 },
  sortBtnText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  archiveRow: { flexDirection: 'row', gap: 8, paddingHorizontal: spacing.sm, paddingBottom: spacing.sm, flexWrap: 'wrap' },
  archiveBtn: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 8 },
  archiveBtnText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  guidelinesToggle: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: spacing.sm },
  guidelinesInput: { marginHorizontal: spacing.sm, borderRadius: 8, padding: 12, minHeight: 100, textAlignVertical: 'top', fontSize: 14, fontFamily: 'gg-sans' },
  saveGuidelinesBtn: { margin: spacing.sm, paddingVertical: 10, borderRadius: 8, alignItems: 'center' },
  saveGuidelinesBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 14 },
});

const pickerStyles = StyleSheet.create({
  container: { paddingVertical: spacing.xs, paddingHorizontal: spacing.sm },
  tag: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14, marginRight: 8, gap: 4 },
  emoji: { fontSize: 14 },
  tagText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
});
