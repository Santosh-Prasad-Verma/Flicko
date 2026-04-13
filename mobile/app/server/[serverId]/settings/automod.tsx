/**
 * AutoMod Settings Screen
 *
 * List, create, toggle, and delete auto-moderation rules.
 * Requirements: Feature 21 (AutoMod)
 */
import React, { useState, useCallback, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Switch,
  Alert,
  Modal,
  TextInput,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { useLocalSearchParams, Stack } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';
import {
  AutoModRule,
  AutoModTriggerType,
  AUTOMOD_PRESETS,
  getAutoModRules,
  createAutoModRule,
  toggleAutoModRule,
  deleteAutoModRule,
} from '@services/autoModService';

const TRIGGER_ICONS: Record<AutoModTriggerType, keyof typeof Ionicons.glyphMap> = {
  keyword: 'ban',
  spam: 'flash',
  mention_spam: 'at',
  link: 'link',
  invite_link: 'mail',
  caps: 'text',
};

export default function AutoModScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const { themeColors: c } = useTheme();

  const [rules, setRules] = useState<AutoModRule[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);

  const fetchRules = useCallback(async () => {
    if (!serverId) return;
    try {
      const data = await getAutoModRules(serverId);
      setRules(data);
    } catch {}
    setLoading(false);
  }, [serverId]);

  useEffect(() => { fetchRules(); }, [fetchRules]);

  const handleToggle = async (rule: AutoModRule) => {
    const newVal = !rule.enabled;
    setRules((prev) => prev.map((r) => (r.id === rule.id ? { ...r, enabled: newVal } : r)));
    try {
      await toggleAutoModRule(rule.id, newVal);
    } catch {
      setRules((prev) => prev.map((r) => (r.id === rule.id ? { ...r, enabled: rule.enabled } : r)));
    }
  };

  const handleDelete = (rule: AutoModRule) => {
    Alert.alert('Delete Rule', `Delete "${rule.name}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          setRules((prev) => prev.filter((r) => r.id !== rule.id));
          try { await deleteAutoModRule(rule.id); } catch { fetchRules(); }
        },
      },
    ]);
  };

  const renderRule = ({ item }: { item: AutoModRule }) => (
    <View style={[styles.ruleCard, { backgroundColor: c.bgSecondary }]}>
      <View style={styles.ruleHeader}>
        <Ionicons
          name={TRIGGER_ICONS[item.trigger_type] || 'shield'}
          size={20}
          color={item.enabled ? c.accentPrimary : c.textMuted}
        />
        <View style={styles.ruleInfo}>
          <Text style={[styles.ruleName, { color: c.textPrimary }]}>{item.name}</Text>
          <Text style={[styles.ruleType, { color: c.textSecondary }]}>
            {item.trigger_type.replace(/_/g, ' ')} • {item.actions.length} action{item.actions.length !== 1 ? 's' : ''}
          </Text>
        </View>
        <Switch
          value={item.enabled}
          onValueChange={() => handleToggle(item)}
          trackColor={{ false: c.border, true: c.accentPrimary }}
          thumbColor={c.textPrimary}
        />
      </View>
      {item.trigger_metadata?.keyword_filter && item.trigger_metadata.keyword_filter.length > 0 && (
        <Text style={[styles.keywords, { color: c.textMuted }]} numberOfLines={1}>
          Keywords: {item.trigger_metadata.keyword_filter.join(', ')}
        </Text>
      )}
      <Pressable style={styles.deleteBtn} onPress={() => handleDelete(item)}>
        <Ionicons name="trash-outline" size={16} color={c.danger} />
        <Text style={[styles.deleteText, { color: c.danger }]}>Delete</Text>
      </Pressable>
    </View>
  );

  return (
    <View style={[styles.container, { backgroundColor: c.bgPrimary }]}>
      <Stack.Screen
        options={{
          title: 'AutoMod',
          headerStyle: { backgroundColor: c.bgSecondary },
          headerTintColor: c.textPrimary,
          headerRight: () => (
            <Pressable onPress={() => setShowCreate(true)}>
              <Ionicons name="add" size={24} color={c.accentPrimary} />
            </Pressable>
          ),
        }}
      />

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={c.accentPrimary} />
        </View>
      ) : rules.length === 0 ? (
        <View style={styles.center}>
          <Ionicons name="shield-checkmark-outline" size={48} color={c.textMuted} />
          <Text style={[styles.emptyText, { color: c.textSecondary }]}>No AutoMod rules yet</Text>
          <Pressable
            style={[styles.createBtn, { backgroundColor: c.accentPrimary }]}
            onPress={() => setShowCreate(true)}
          >
            <Text style={[styles.createBtnText, { color: c.textPrimary }]}>Create Rule</Text>
          </Pressable>
        </View>
      ) : (
        <FlatList
          data={rules}
          keyExtractor={(item) => item.id}
          renderItem={renderRule}
          contentContainerStyle={{ padding: spacing.md, gap: spacing.sm }}
        />
      )}

      <CreateRuleModal
        visible={showCreate}
        onClose={() => setShowCreate(false)}
        serverId={serverId!}
        onCreated={(rule) => {
          setRules((prev) => [...prev, rule]);
          setShowCreate(false);
        }}
      />
    </View>
  );
}

// ─── Create Rule Modal ─────────────────────────────────────────────────────────

function CreateRuleModal({
  visible,
  onClose,
  serverId,
  onCreated,
}: {
  visible: boolean;
  onClose: () => void;
  serverId: string;
  onCreated: (rule: AutoModRule) => void;
}) {
  const { themeColors: c } = useTheme();
  const [name, setName] = useState('');
  const [triggerType, setTriggerType] = useState<AutoModTriggerType>('keyword');
  const [keywords, setKeywords] = useState('');
  const [saving, setSaving] = useState(false);

  const handleCreate = async () => {
    if (!name.trim()) return;
    setSaving(true);
    try {
      const rule = await createAutoModRule(serverId, {
        name: name.trim(),
        trigger_type: triggerType,
        trigger_metadata:
          triggerType === 'keyword'
            ? { keyword_filter: keywords.split(',').map((k) => k.trim()).filter(Boolean) }
            : triggerType === 'mention_spam'
            ? { mention_limit: 5 }
            : {},
        actions: [{ type: 'block_message' }],
      });
      onCreated(rule);
      setName('');
      setKeywords('');
    } catch (e: any) {
      Alert.alert('Error', e?.message || 'Failed to create rule');
    }
    setSaving(false);
  };

  return (
    <Modal visible={visible} animationType="slide" transparent>
      <View style={[styles.modalOverlay, { backgroundColor: c.overlay }]}>
        <View style={[styles.modalContent, { backgroundColor: c.bgSecondary }]}>
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: c.textPrimary }]}>New AutoMod Rule</Text>
            <Pressable onPress={onClose}>
              <Ionicons name="close" size={24} color={c.textMuted} />
            </Pressable>
          </View>

          <ScrollView style={styles.modalBody}>
            <Text style={[styles.fieldLabel, { color: c.textSecondary }]}>Rule Name</Text>
            <TextInput
              style={[styles.input, { color: c.textPrimary, backgroundColor: c.inputBg, borderColor: c.border }]}
              value={name}
              onChangeText={setName}
              placeholder="e.g. Block profanity"
              placeholderTextColor={c.textMuted}
            />

            <Text style={[styles.fieldLabel, { color: c.textSecondary }]}>Trigger Type</Text>
            <View style={styles.presetGrid}>
              {AUTOMOD_PRESETS.map((preset) => {
                const selected = triggerType === preset.trigger_type;
                return (
                  <Pressable
                    key={preset.trigger_type}
                    style={[
                      styles.presetCard,
                      { backgroundColor: selected ? c.bgTertiary : c.bgPrimary, borderColor: selected ? c.accentPrimary : c.border },
                    ]}
                    onPress={() => {
                      setTriggerType(preset.trigger_type);
                      if (!name) setName(preset.name);
                    }}
                  >
                    <Ionicons
                      name={TRIGGER_ICONS[preset.trigger_type]}
                      size={20}
                      color={selected ? c.accentPrimary : c.textMuted}
                    />
                    <Text style={[styles.presetName, { color: c.textPrimary }]}>{preset.name}</Text>
                    <Text style={[styles.presetDesc, { color: c.textMuted }]}>{preset.description}</Text>
                  </Pressable>
                );
              })}
            </View>

            {triggerType === 'keyword' && (
              <>
                <Text style={[styles.fieldLabel, { color: c.textSecondary }]}>Keywords (comma-separated)</Text>
                <TextInput
                  style={[styles.input, styles.multilineInput, { color: c.textPrimary, backgroundColor: c.inputBg, borderColor: c.border }]}
                  value={keywords}
                  onChangeText={setKeywords}
                  placeholder="bad, words, here"
                  placeholderTextColor={c.textMuted}
                  multiline
                />
              </>
            )}
          </ScrollView>

          <Pressable
            style={[styles.saveButton, { backgroundColor: c.accentPrimary, opacity: saving || !name.trim() ? 0.5 : 1 }]}
            onPress={handleCreate}
            disabled={saving || !name.trim()}
          >
            {saving ? (
              <ActivityIndicator color={c.textPrimary} size="small" />
            ) : (
              <Text style={[styles.saveButtonText, { color: c.textPrimary }]}>Create Rule</Text>
            )}
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', gap: spacing.md },
  ruleCard: {
    borderRadius: borderRadius.md,
    padding: spacing.lg,
  },
  ruleHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  ruleInfo: { flex: 1 },
  ruleName: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  ruleType: { ...typography.caption, marginTop: 2 },
  keywords: { ...typography.caption, marginTop: spacing.sm, paddingLeft: spacing.xxxl },
  deleteBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    marginTop: spacing.sm,
    alignSelf: 'flex-end',
  },
  deleteText: { ...typography.caption },
  emptyText: { ...typography.body, marginTop: spacing.sm },
  createBtn: {
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.md,
    borderRadius: borderRadius.md,
    marginTop: spacing.md,
  },
  createBtnText: { ...typography.bodyBold },
  // Modal
  modalOverlay: { flex: 1, justifyContent: 'flex-end' },
  modalContent: { borderTopLeftRadius: borderRadius.xl, borderTopRightRadius: borderRadius.xl, maxHeight: '85%' },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: spacing.lg,
  },
  modalTitle: { ...typography.headingM },
  modalBody: { paddingHorizontal: spacing.lg },
  fieldLabel: { ...typography.caption, fontFamily: 'gg-sans-semibold', marginTop: spacing.md, marginBottom: spacing.xs },
  input: {
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    paddingHorizontal: spacing.md,
    height: MINIMUM_TOUCH_TARGET,
    ...typography.bodySmall,
  },
  multilineInput: { height: 80, textAlignVertical: 'top', paddingTop: spacing.sm },
  presetGrid: { gap: spacing.sm },
  presetCard: {
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    padding: spacing.md,
    gap: spacing.xs,
  },
  presetName: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold' },
  presetDesc: { ...typography.caption },
  saveButton: {
    margin: spacing.lg,
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: borderRadius.md,
    justifyContent: 'center',
    alignItems: 'center',
  },
  saveButtonText: { ...typography.bodyBold },
});
