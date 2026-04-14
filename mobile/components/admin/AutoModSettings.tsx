/**
 * AutoMod v2 Rule Engine UI (Feature 25)
 *
 * Full rule management interface for server automoderation:
 * - Block custom words (exact, wildcard, regex)
 * - Block spam / excessive mentions / links
 * - Actions: block message, send alert, timeout user
 * - Exempt roles and channels per rule
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
  Switch,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import {
  useServerManagementStore,
  AutoModRule,
  AutoModTriggerType,
  AutoModAction,
  AutoModActionType,
} from '@stores/serverManagementStore';
import { supabase } from '@services/supabase';

const TRIGGER_TYPES: { type: AutoModTriggerType; label: string; icon: string; desc: string }[] = [
  { type: 'keyword', label: 'Block Custom Words', icon: 'text-outline', desc: 'Block messages containing specific words or patterns' },
  { type: 'spam', label: 'Block Spam Content', icon: 'warning-outline', desc: 'Block messages with excessive mentions or emojis' },
  { type: 'mention_spam', label: 'Block Mention Spam', icon: 'at-outline', desc: 'Limit the number of mentions per message' },
  { type: 'link', label: 'Block Links', icon: 'link-outline', desc: 'Block or allow specific domains' },
];

const ACTION_TYPES: { type: AutoModActionType; label: string; icon: string }[] = [
  { type: 'block', label: 'Block Message', icon: 'close-circle-outline' },
  { type: 'alert', label: 'Send Alert', icon: 'notifications-outline' },
  { type: 'timeout', label: 'Timeout User', icon: 'timer-outline' },
];

interface Props {
  serverId: string;
}

export const AutoModSettings = memo(function AutoModSettings({ serverId }: Props) {
  const { themeColors: c } = useTheme();
  const rules = useServerManagementStore((s) => s.autoModRules[serverId] ?? []);
  const { toggleAutoModRule, removeAutoModRule, upsertAutoModRule, fetchAutoModRules } =
    useServerManagementStore();

  const [showEditor, setShowEditor] = useState(false);
  const [editingRule, setEditingRule] = useState<AutoModRule | null>(null);

  const handleDeleteRule = useCallback(
    (ruleId: string) => {
      Alert.alert('Delete Rule', 'Are you sure you want to delete this automod rule?', [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            removeAutoModRule(serverId, ruleId);
            await supabase.from('automod_rules').delete().eq('id', ruleId);
          },
        },
      ]);
    },
    [serverId, removeAutoModRule]
  );

  const handleEditRule = useCallback((rule: AutoModRule) => {
    setEditingRule(rule);
    setShowEditor(true);
  }, []);

  const handleNewRule = useCallback(() => {
    setEditingRule(null);
    setShowEditor(true);
  }, []);

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: c.bgPrimary }]}
      contentContainerStyle={styles.content}
    >
      <Text style={[styles.title, { color: c.textPrimary }]}>AutoMod</Text>
      <Text style={[styles.subtitle, { color: c.textMuted }]}>
        Automatically moderate messages based on configurable rules.
      </Text>

      {/* Existing Rules */}
      {rules.map((rule) => (
        <View key={rule.id} style={[styles.ruleCard, { backgroundColor: c.bgSecondary }]}>
          <View style={styles.ruleHeader}>
            <View style={styles.ruleInfo}>
              <Ionicons
                name={TRIGGER_TYPES.find((t) => t.type === rule.trigger_type)?.icon as any ?? 'shield-outline'}
                size={18}
                color={c.accentPrimary}
              />
              <Text style={[styles.ruleName, { color: c.textPrimary }]} numberOfLines={1}>
                {rule.name}
              </Text>
            </View>
            <Switch
              value={rule.enabled}
              onValueChange={() => {
                toggleAutoModRule(serverId, rule.id);
                supabase
                  .from('automod_rules')
                  .update({ enabled: !rule.enabled })
                  .eq('id', rule.id);
              }}
              trackColor={{ false: c.bgTertiary, true: c.accentPrimary }}
            />
          </View>

          <Text style={[styles.ruleType, { color: c.textMuted }]}>
            {TRIGGER_TYPES.find((t) => t.type === rule.trigger_type)?.label}
          </Text>

          {/* Actions summary */}
          <View style={styles.actionsRow}>
            {rule.actions.map((a, i) => (
              <View key={i} style={[styles.actionBadge, { backgroundColor: c.bgTertiary }]}>
                <Ionicons
                  name={ACTION_TYPES.find((t) => t.type === a.type)?.icon as any ?? 'ellipse'}
                  size={12}
                  color={c.textMuted}
                />
                <Text style={[styles.actionBadgeText, { color: c.textMuted }]}>
                  {ACTION_TYPES.find((t) => t.type === a.type)?.label}
                  {a.type === 'timeout' && a.duration ? ` (${a.duration}s)` : ''}
                </Text>
              </View>
            ))}
          </View>

          <View style={styles.ruleActions}>
            <Pressable style={styles.ruleBtn} onPress={() => handleEditRule(rule)}>
              <Ionicons name="pencil-outline" size={16} color={c.accentPrimary} />
              <Text style={[styles.ruleBtnText, { color: c.accentPrimary }]}>Edit</Text>
            </Pressable>
            <Pressable style={styles.ruleBtn} onPress={() => handleDeleteRule(rule.id)}>
              <Ionicons name="trash-outline" size={16} color={c.danger} />
              <Text style={[styles.ruleBtnText, { color: c.danger }]}>Delete</Text>
            </Pressable>
          </View>
        </View>
      ))}

      {/* Add Rule Button */}
      <Pressable
        style={[styles.addButton, { backgroundColor: c.accentPrimary }]}
        onPress={handleNewRule}
      >
        <Ionicons name="add" size={20} color="#fff" />
        <Text style={styles.addButtonText}>Add Rule</Text>
      </Pressable>

      {/* Rule Editor Modal */}
      <AutoModRuleEditor
        visible={showEditor}
        serverId={serverId}
        existingRule={editingRule}
        onClose={() => setShowEditor(false)}
        onSave={async (rule) => {
          upsertAutoModRule(serverId, rule);
          await supabase.from('automod_rules').upsert(rule);
          setShowEditor(false);
        }}
      />
    </ScrollView>
  );
});

/* ───── Rule Editor Modal ───── */

interface EditorProps {
  visible: boolean;
  serverId: string;
  existingRule: AutoModRule | null;
  onClose: () => void;
  onSave: (rule: AutoModRule) => void;
}

function AutoModRuleEditor({ visible, serverId, existingRule, onClose, onSave }: EditorProps) {
  const { themeColors: c } = useTheme();

  const [name, setName] = useState(existingRule?.name ?? '');
  const [triggerType, setTriggerType] = useState<AutoModTriggerType>(
    existingRule?.trigger_type ?? 'keyword'
  );
  const [words, setWords] = useState(existingRule?.trigger_config?.words?.join(', ') ?? '');
  const [maxMentions, setMaxMentions] = useState(
    String(existingRule?.trigger_config?.max_mentions ?? 5)
  );
  const [allowDomains, setAllowDomains] = useState(
    existingRule?.trigger_config?.allow_domains?.join(', ') ?? ''
  );
  const [blockDomains, setBlockDomains] = useState(
    existingRule?.trigger_config?.block_domains?.join(', ') ?? ''
  );
  const [actions, setActions] = useState<AutoModAction[]>(existingRule?.actions ?? [{ type: 'block' }]);
  const [timeoutDuration, setTimeoutDuration] = useState('60');

  // Reset form when modal opens with different rule
  React.useEffect(() => {
    if (visible) {
      setName(existingRule?.name ?? '');
      setTriggerType(existingRule?.trigger_type ?? 'keyword');
      setWords(existingRule?.trigger_config?.words?.join(', ') ?? '');
      setMaxMentions(String(existingRule?.trigger_config?.max_mentions ?? 5));
      setAllowDomains(existingRule?.trigger_config?.allow_domains?.join(', ') ?? '');
      setBlockDomains(existingRule?.trigger_config?.block_domains?.join(', ') ?? '');
      setActions(existingRule?.actions ?? [{ type: 'block' }]);
    }
  }, [visible, existingRule]);

  const toggleAction = (type: AutoModActionType) => {
    const exists = actions.some((a) => a.type === type);
    if (exists) {
      setActions(actions.filter((a) => a.type !== type));
    } else {
      const action: AutoModAction =
        type === 'timeout'
          ? { type, duration: parseInt(timeoutDuration, 10) || 60 }
          : { type };
      setActions([...actions, action]);
    }
  };

  const handleSave = () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Rule name is required');
      return;
    }

    const rule: AutoModRule = {
      id: existingRule?.id ?? `rule_${Date.now()}`,
      server_id: serverId,
      name: name.trim(),
      trigger_type: triggerType,
      trigger_config: {
        ...(triggerType === 'keyword' && {
          words: words.split(',').map((w) => w.trim()).filter(Boolean),
        }),
        ...(triggerType === 'mention_spam' && {
          max_mentions: parseInt(maxMentions, 10) || 5,
        }),
        ...(triggerType === 'link' && {
          allow_domains: allowDomains.split(',').map((d) => d.trim()).filter(Boolean),
          block_domains: blockDomains.split(',').map((d) => d.trim()).filter(Boolean),
        }),
      },
      actions: actions.map((a) =>
        a.type === 'timeout'
          ? { ...a, duration: parseInt(timeoutDuration, 10) || 60 }
          : a
      ),
      exempt_roles: existingRule?.exempt_roles ?? [],
      exempt_channels: existingRule?.exempt_channels ?? [],
      enabled: existingRule?.enabled ?? true,
    };

    onSave(rule);
  };

  return (
    <Modal visible={visible} transparent animationType="slide">
      <View style={styles.modalOverlay}>
        <View style={[styles.modalSheet, { backgroundColor: c.bgPrimary }]}>
          <ScrollView contentContainerStyle={styles.editorContent}>
            <Text style={[styles.editorTitle, { color: c.textPrimary }]}>
              {existingRule ? 'Edit Rule' : 'New AutoMod Rule'}
            </Text>

            {/* Rule Name */}
            <Text style={[styles.label, { color: c.textMuted }]}>RULE NAME</Text>
            <TextInput
              style={[styles.input, { backgroundColor: c.bgSecondary, color: c.textPrimary }]}
              value={name}
              onChangeText={setName}
              placeholder="e.g. Profanity Filter"
              placeholderTextColor={c.textMuted}
            />

            {/* Trigger Type */}
            <Text style={[styles.label, { color: c.textMuted }]}>TRIGGER TYPE</Text>
            {TRIGGER_TYPES.map((t) => (
              <Pressable
                key={t.type}
                style={[
                  styles.triggerOption,
                  {
                    backgroundColor: triggerType === t.type ? c.bgTertiary : c.bgSecondary,
                    borderColor: triggerType === t.type ? c.accentPrimary : 'transparent',
                  },
                ]}
                onPress={() => setTriggerType(t.type)}
              >
                <Ionicons name={t.icon as any} size={20} color={triggerType === t.type ? c.accentPrimary : c.textMuted} />
                <View style={{ flex: 1 }}>
                  <Text style={[styles.triggerLabel, { color: c.textPrimary }]}>{t.label}</Text>
                  <Text style={[styles.triggerDesc, { color: c.textMuted }]}>{t.desc}</Text>
                </View>
              </Pressable>
            ))}

            {/* Trigger Config */}
            {triggerType === 'keyword' && (
              <>
                <Text style={[styles.label, { color: c.textMuted }]}>BLOCKED WORDS (comma-separated)</Text>
                <TextInput
                  style={[styles.input, styles.multiline, { backgroundColor: c.bgSecondary, color: c.textPrimary }]}
                  value={words}
                  onChangeText={setWords}
                  placeholder="word1, word2, regex:pattern"
                  placeholderTextColor={c.textMuted}
                  multiline
                />
              </>
            )}

            {triggerType === 'mention_spam' && (
              <>
                <Text style={[styles.label, { color: c.textMuted }]}>MAX MENTIONS PER MESSAGE</Text>
                <TextInput
                  style={[styles.input, { backgroundColor: c.bgSecondary, color: c.textPrimary }]}
                  value={maxMentions}
                  onChangeText={setMaxMentions}
                  keyboardType="numeric"
                  placeholder="5"
                  placeholderTextColor={c.textMuted}
                />
              </>
            )}

            {triggerType === 'link' && (
              <>
                <Text style={[styles.label, { color: c.textMuted }]}>ALLOWED DOMAINS (comma-separated)</Text>
                <TextInput
                  style={[styles.input, { backgroundColor: c.bgSecondary, color: c.textPrimary }]}
                  value={allowDomains}
                  onChangeText={setAllowDomains}
                  placeholder="youtube.com, github.com"
                  placeholderTextColor={c.textMuted}
                />
                <Text style={[styles.label, { color: c.textMuted }]}>BLOCKED DOMAINS (comma-separated)</Text>
                <TextInput
                  style={[styles.input, { backgroundColor: c.bgSecondary, color: c.textPrimary }]}
                  value={blockDomains}
                  onChangeText={setBlockDomains}
                  placeholder="malware.com, spam.net"
                  placeholderTextColor={c.textMuted}
                />
              </>
            )}

            {/* Actions */}
            <Text style={[styles.label, { color: c.textMuted }]}>ACTIONS</Text>
            {ACTION_TYPES.map((a) => {
              const active = actions.some((act) => act.type === a.type);
              return (
                <Pressable
                  key={a.type}
                  style={[
                    styles.actionOption,
                    { backgroundColor: active ? c.bgTertiary : c.bgSecondary },
                  ]}
                  onPress={() => toggleAction(a.type)}
                >
                  <Ionicons
                    name={active ? 'checkbox' : 'square-outline'}
                    size={22}
                    color={active ? c.accentPrimary : c.textMuted}
                  />
                  <Ionicons name={a.icon as any} size={18} color={c.textPrimary} />
                  <Text style={[styles.actionOptionLabel, { color: c.textPrimary }]}>{a.label}</Text>
                </Pressable>
              );
            })}

            {actions.some((a) => a.type === 'timeout') && (
              <>
                <Text style={[styles.label, { color: c.textMuted }]}>TIMEOUT DURATION (seconds)</Text>
                <TextInput
                  style={[styles.input, { backgroundColor: c.bgSecondary, color: c.textPrimary }]}
                  value={timeoutDuration}
                  onChangeText={setTimeoutDuration}
                  keyboardType="numeric"
                  placeholder="60"
                  placeholderTextColor={c.textMuted}
                />
              </>
            )}
          </ScrollView>

          {/* Footer */}
          <View style={[styles.editorFooter, { borderTopColor: c.bgTertiary }]}>
            <Pressable
              style={[styles.footerBtn, { backgroundColor: c.bgSecondary }]}
              onPress={onClose}
            >
              <Text style={[styles.footerBtnText, { color: c.textPrimary }]}>Cancel</Text>
            </Pressable>
            <Pressable
              style={[styles.footerBtn, { backgroundColor: c.accentPrimary }]}
              onPress={handleSave}
            >
              <Text style={[styles.footerBtnText, { color: '#fff' }]}>Save Rule</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: spacing.md },
  title: { fontSize: 20, fontFamily: 'gg-sans-bold', marginBottom: 4 },
  subtitle: { ...typography.body, marginBottom: spacing.md },
  ruleCard: {
    borderRadius: 12,
    padding: spacing.sm,
    marginBottom: spacing.sm,
  },
  ruleHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  ruleInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    flex: 1,
  },
  ruleName: { fontSize: 15, fontFamily: 'gg-sans-bold', flex: 1 },
  ruleType: { ...typography.caption, marginTop: 2, marginLeft: 26 },
  actionsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginTop: spacing.xs,
    marginLeft: 26,
  },
  actionBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
    gap: 4,
  },
  actionBadgeText: { fontSize: 11, fontFamily: 'gg-sans-medium' },
  ruleActions: {
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.sm,
    marginLeft: 26,
  },
  ruleBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  ruleBtnText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 8,
    gap: spacing.xs,
    marginTop: spacing.sm,
  },
  addButtonText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 15 },

  // Modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalSheet: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '90%',
  },
  editorContent: { padding: spacing.md, paddingBottom: 0 },
  editorTitle: { fontSize: 18, fontFamily: 'gg-sans-bold', marginBottom: spacing.md },
  label: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: 6,
    marginTop: spacing.md,
  },
  input: {
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    fontFamily: 'gg-sans',
  },
  multiline: {
    minHeight: 80,
    textAlignVertical: 'top',
  },
  triggerOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    borderRadius: 8,
    borderWidth: 1.5,
    gap: spacing.sm,
    marginBottom: 6,
  },
  triggerLabel: { fontSize: 14, fontFamily: 'gg-sans-medium' },
  triggerDesc: { fontSize: 12, fontFamily: 'gg-sans', marginTop: 1 },
  actionOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    borderRadius: 8,
    gap: spacing.sm,
    marginBottom: 6,
  },
  actionOptionLabel: { fontSize: 14, fontFamily: 'gg-sans-medium' },
  editorFooter: {
    flexDirection: 'row',
    padding: spacing.md,
    gap: spacing.sm,
    borderTopWidth: 1,
  },
  footerBtn: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  footerBtnText: { fontFamily: 'gg-sans-bold', fontSize: 15 },
});
