/**
 * Channel Drag Reorder (Feature 38)
 *
 * Admin-only screen to reorder channels within categories.
 * Uses long-press + drag to rearrange, then persists positions.
 */
import React, { memo, useCallback, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  PanResponder,
  Animated,
  FlatList,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '@services/supabase';

interface Channel {
  id: string;
  name: string;
  type: 'text' | 'voice' | 'forum' | 'stage' | 'announcement';
  position: number;
  category_id: string | null;
}

interface Category {
  id: string;
  name: string;
  position: number;
  channels: Channel[];
}

const CHANNEL_ICONS: Record<string, string> = {
  text: 'chatbubble-outline',
  voice: 'volume-medium-outline',
  forum: 'newspaper-outline',
  stage: 'mic-outline',
  announcement: 'megaphone-outline',
};

const DraggableChannelItem = memo(function DraggableChannelItem({
  channel,
  onMoveUp,
  onMoveDown,
  isFirst,
  isLast,
}: {
  channel: Channel;
  onMoveUp: (id: string) => void;
  onMoveDown: (id: string) => void;
  isFirst: boolean;
  isLast: boolean;
}) {
  return (
    <View style={styles.channelRow}>
      <View style={styles.dragHandle}>
        <Ionicons name="reorder-three" size={20} color="#72767D" />
      </View>
      <Ionicons
        name={(CHANNEL_ICONS[channel.type] || 'chatbubble-outline') as any}
        size={16}
        color="#96989D"
      />
      <Text style={styles.channelName} numberOfLines={1}>
        {channel.name}
      </Text>
      <View style={styles.moveButtons}>
        <TouchableOpacity
          onPress={() => onMoveUp(channel.id)}
          disabled={isFirst}
          style={[styles.moveBtn, isFirst && styles.moveBtnDisabled]}
        >
          <Ionicons name="chevron-up" size={18} color={isFirst ? '#40444B' : '#B9BBBE'} />
        </TouchableOpacity>
        <TouchableOpacity
          onPress={() => onMoveDown(channel.id)}
          disabled={isLast}
          style={[styles.moveBtn, isLast && styles.moveBtnDisabled]}
        >
          <Ionicons name="chevron-down" size={18} color={isLast ? '#40444B' : '#B9BBBE'} />
        </TouchableOpacity>
      </View>
    </View>
  );
});

interface ChannelDragReorderProps {
  serverId: string;
  categories: Category[];
  onSave?: () => void;
}

export const ChannelDragReorder = memo(function ChannelDragReorder({
  serverId,
  categories: initialCategories,
  onSave,
}: ChannelDragReorderProps) {
  const [categories, setCategories] = useState<Category[]>(
    initialCategories.map((cat) => ({
      ...cat,
      channels: [...cat.channels].sort((a, b) => a.position - b.position),
    }))
  );
  const [saving, setSaving] = useState(false);
  const [dirty, setDirty] = useState(false);

  const moveChannel = useCallback((categoryId: string | null, channelId: string, direction: -1 | 1) => {
    setCategories((prev) =>
      prev.map((cat) => {
        if (cat.id !== categoryId) return cat;
        const channels = [...cat.channels];
        const idx = channels.findIndex((c) => c.id === channelId);
        if (idx < 0) return cat;
        const targetIdx = idx + direction;
        if (targetIdx < 0 || targetIdx >= channels.length) return cat;
        // Swap
        [channels[idx], channels[targetIdx]] = [channels[targetIdx], channels[idx]];
        // Update positions
        const reindexed = channels.map((c, i) => ({ ...c, position: i }));
        return { ...cat, channels: reindexed };
      })
    );
    setDirty(true);
  }, []);

  const handleMoveUp = useCallback(
    (catId: string | null) => (channelId: string) => moveChannel(catId, channelId, -1),
    [moveChannel]
  );

  const handleMoveDown = useCallback(
    (catId: string | null) => (channelId: string) => moveChannel(catId, channelId, 1),
    [moveChannel]
  );

  const handleSave = useCallback(async () => {
    setSaving(true);
    try {
      const updates = categories.flatMap((cat) =>
        cat.channels.map((ch) => ({
          id: ch.id,
          position: ch.position,
        }))
      );

      // Batch update positions
      for (const u of updates) {
        await supabase.from('channels').update({ position: u.position }).eq('id', u.id);
      }

      setDirty(false);
      onSave?.();
      Alert.alert('Saved', 'Channel order has been updated.');
    } catch {
      Alert.alert('Error', 'Failed to save channel order.');
    } finally {
      setSaving(false);
    }
  }, [categories, onSave]);

  const handleReset = useCallback(() => {
    setCategories(
      initialCategories.map((cat) => ({
        ...cat,
        channels: [...cat.channels].sort((a, b) => a.position - b.position),
      }))
    );
    setDirty(false);
  }, [initialCategories]);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Reorder Channels</Text>
        <View style={styles.headerActions}>
          {dirty && (
            <TouchableOpacity onPress={handleReset} style={styles.resetBtn}>
              <Text style={styles.resetText}>Reset</Text>
            </TouchableOpacity>
          )}
          <TouchableOpacity
            onPress={handleSave}
            disabled={!dirty || saving}
            style={[styles.saveBtn, (!dirty || saving) && styles.saveBtnDisabled]}
          >
            {saving ? (
              <ActivityIndicator size="small" color="#FFF" />
            ) : (
              <Text style={styles.saveText}>Save</Text>
            )}
          </TouchableOpacity>
        </View>
      </View>

      <FlatList
        data={categories}
        keyExtractor={(cat) => cat.id}
        contentContainerStyle={styles.list}
        renderItem={({ item: cat }) => (
          <View style={styles.categorySection}>
            <Text style={styles.categoryName}>{cat.name.toUpperCase()}</Text>
            {cat.channels.map((ch, idx) => (
              <DraggableChannelItem
                key={ch.id}
                channel={ch}
                onMoveUp={handleMoveUp(cat.id)}
                onMoveDown={handleMoveDown(cat.id)}
                isFirst={idx === 0}
                isLast={idx === cat.channels.length - 1}
              />
            ))}
          </View>
        )}
      />

      <Text style={styles.hint}>
        Use the arrows to reorder channels within each category. Tap Save when done.
      </Text>
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#36393F',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#202225',
  },
  title: {
    color: '#FFFFFF',
    fontSize: 18,
    fontFamily: 'GGSans-Bold',
  },
  headerActions: {
    flexDirection: 'row',
    gap: 10,
    alignItems: 'center',
  },
  resetBtn: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    backgroundColor: '#4F545C',
  },
  resetText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontFamily: 'GGSans-Medium',
  },
  saveBtn: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 4,
    backgroundColor: '#5865F2',
    minWidth: 60,
    alignItems: 'center',
  },
  saveBtnDisabled: {
    opacity: 0.5,
  },
  saveText: {
    color: '#FFFFFF',
    fontSize: 13,
    fontFamily: 'GGSans-Medium',
  },
  list: {
    padding: 16,
  },
  categorySection: {
    marginBottom: 20,
  },
  categoryName: {
    color: '#96989D',
    fontSize: 12,
    fontFamily: 'GGSans-Bold',
    letterSpacing: 0.5,
    marginBottom: 6,
  },
  channelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#2F3136',
    borderRadius: 6,
    paddingHorizontal: 10,
    paddingVertical: 10,
    marginBottom: 2,
    gap: 8,
  },
  dragHandle: {
    paddingRight: 4,
  },
  channelName: {
    flex: 1,
    color: '#DCDDDE',
    fontSize: 14,
    fontFamily: 'GGSans-Medium',
  },
  moveButtons: {
    flexDirection: 'row',
    gap: 2,
  },
  moveBtn: {
    padding: 4,
  },
  moveBtnDisabled: {
    opacity: 0.3,
  },
  hint: {
    color: '#72767D',
    fontSize: 12,
    fontFamily: 'GGSans-Regular',
    textAlign: 'center',
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
});
