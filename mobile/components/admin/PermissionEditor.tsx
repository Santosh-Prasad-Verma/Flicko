/**
 * Permission Visual Editor (Feature 28)
 *
 * Visual matrix/grid for managing channel permissions per role.
 * Three-state toggles: Allow (green) / Deny (red) / Neutral (inherit).
 * Includes a "Permission Calculator" that shows the final computed permissions for a member.
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  FlatList,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import { supabase } from '@services/supabase';

/* ───── Permission Definitions ───── */

export const PERMISSIONS = [
  { key: 'VIEW_CHANNEL', label: 'View Channel', bit: 1 << 0 },
  { key: 'SEND_MESSAGES', label: 'Send Messages', bit: 1 << 1 },
  { key: 'MANAGE_MESSAGES', label: 'Manage Messages', bit: 1 << 2 },
  { key: 'EMBED_LINKS', label: 'Embed Links', bit: 1 << 3 },
  { key: 'ATTACH_FILES', label: 'Attach Files', bit: 1 << 4 },
  { key: 'ADD_REACTIONS', label: 'Add Reactions', bit: 1 << 5 },
  { key: 'MENTION_EVERYONE', label: 'Mention Everyone', bit: 1 << 6 },
  { key: 'MANAGE_CHANNELS', label: 'Manage Channel', bit: 1 << 7 },
  { key: 'PRIORITY_SPEAKER', label: 'Priority Speaker', bit: 1 << 8 },
  { key: 'CONNECT', label: 'Connect (Voice)', bit: 1 << 9 },
  { key: 'SPEAK', label: 'Speak', bit: 1 << 10 },
  { key: 'MUTE_MEMBERS', label: 'Mute Members', bit: 1 << 11 },
  { key: 'DEAFEN_MEMBERS', label: 'Deafen Members', bit: 1 << 12 },
  { key: 'MOVE_MEMBERS', label: 'Move Members', bit: 1 << 13 },
  { key: 'MANAGE_ROLES', label: 'Manage Roles', bit: 1 << 14 },
  { key: 'MANAGE_WEBHOOKS', label: 'Manage Webhooks', bit: 1 << 15 },
  { key: 'CREATE_THREADS', label: 'Create Threads', bit: 1 << 16 },
  { key: 'USE_SLASH_COMMANDS', label: 'Use Slash Commands', bit: 1 << 17 },
] as const;

type PermState = 'allow' | 'deny' | 'neutral';

interface PermissionOverwrite {
  role_id: string;
  allow: number; // bitfield
  deny: number;  // bitfield
}

interface Role {
  id: string;
  name: string;
  color?: string;
  permissions: number; // base server-level permission bitfield
}

interface Props {
  channelId: string;
  roles: Role[];
  overwrites: PermissionOverwrite[];
  onSave: (overwrites: PermissionOverwrite[]) => void;
}

export const PermissionEditor = memo(function PermissionEditor({
  channelId,
  roles,
  overwrites: initialOverwrites,
  onSave,
}: Props) {
  const { themeColors: c } = useTheme();
  const [overwrites, setOverwrites] = useState<PermissionOverwrite[]>(initialOverwrites);
  const [selectedRole, setSelectedRole] = useState<string>(roles[0]?.id ?? '');
  const [showCalculator, setShowCalculator] = useState(false);
  const [calcMemberId, setCalcMemberId] = useState('');

  const getOverwrite = (roleId: string): PermissionOverwrite =>
    overwrites.find((o) => o.role_id === roleId) ?? { role_id: roleId, allow: 0, deny: 0 };

  const getPermState = (roleId: string, bit: number): PermState => {
    const ow = getOverwrite(roleId);
    if (ow.allow & bit) return 'allow';
    if (ow.deny & bit) return 'deny';
    return 'neutral';
  };

  const cyclePermState = useCallback(
    (roleId: string, bit: number) => {
      const current = getPermState(roleId, bit);
      const next: PermState =
        current === 'neutral' ? 'allow' : current === 'allow' ? 'deny' : 'neutral';

      setOverwrites((prev) => {
        const existing = prev.find((o) => o.role_id === roleId);
        let allow = existing?.allow ?? 0;
        let deny = existing?.deny ?? 0;

        // Clear bit from both
        allow &= ~bit;
        deny &= ~bit;

        // Set new state
        if (next === 'allow') allow |= bit;
        else if (next === 'deny') deny |= bit;

        const updated: PermissionOverwrite = { role_id: roleId, allow, deny };
        const idx = prev.findIndex((o) => o.role_id === roleId);
        if (idx >= 0) return prev.map((o, i) => (i === idx ? updated : o));
        return [...prev, updated];
      });
    },
    [overwrites]
  );

  const computeFinalPermissions = (roleList: Role[], memberRoleIds: string[]): number => {
    let final = 0;
    for (const role of roleList.filter((r) => memberRoleIds.includes(r.id))) {
      final |= role.permissions;
    }
    // Apply overwrites
    for (const ow of overwrites) {
      if (memberRoleIds.includes(ow.role_id)) {
        final |= ow.allow;
        final &= ~ow.deny;
      }
    }
    return final;
  };

  const StateIcon = ({ state }: { state: PermState }) => {
    switch (state) {
      case 'allow':
        return <Ionicons name="checkmark-circle" size={22} color="#57F287" />;
      case 'deny':
        return <Ionicons name="close-circle" size={22} color="#ED4245" />;
      default:
        return <Ionicons name="remove-circle-outline" size={22} color={c.textMuted} />;
    }
  };

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: c.bgPrimary }]}
      contentContainerStyle={styles.content}
    >
      <Text style={[styles.title, { color: c.textPrimary }]}>Channel Permissions</Text>
      <Text style={[styles.subtitle, { color: c.textMuted }]}>
        Tap a permission to cycle: Neutral → Allow → Deny
      </Text>

      {/* Role Tabs */}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.roleTabs}>
        {roles.map((role) => (
          <Pressable
            key={role.id}
            style={[
              styles.roleTab,
              {
                backgroundColor: selectedRole === role.id ? c.accentPrimary : c.bgSecondary,
              },
            ]}
            onPress={() => setSelectedRole(role.id)}
          >
            {role.color && (
              <View style={[styles.roleColor, { backgroundColor: role.color }]} />
            )}
            <Text
              style={[
                styles.roleTabText,
                { color: selectedRole === role.id ? '#fff' : c.textPrimary },
              ]}
            >
              @{role.name}
            </Text>
          </Pressable>
        ))}
      </ScrollView>

      {/* Permission Grid */}
      <View style={[styles.grid, { backgroundColor: c.bgSecondary }]}>
        {PERMISSIONS.map((perm) => {
          const state = getPermState(selectedRole, perm.bit);
          return (
            <Pressable
              key={perm.key}
              style={[styles.permRow, state !== 'neutral' && { backgroundColor: c.bgTertiary }]}
              onPress={() => cyclePermState(selectedRole, perm.bit)}
            >
              <StateIcon state={state} />
              <Text style={[styles.permLabel, { color: c.textPrimary }]}>{perm.label}</Text>
            </Pressable>
          );
        })}
      </View>

      {/* Save Button */}
      <Pressable
        style={[styles.saveBtn, { backgroundColor: c.accentPrimary }]}
        onPress={() => onSave(overwrites)}
      >
        <Text style={styles.saveBtnText}>Save Permissions</Text>
      </Pressable>

      {/* Permission Calculator */}
      <Pressable
        style={[styles.calcToggle, { backgroundColor: c.bgSecondary }]}
        onPress={() => setShowCalculator(!showCalculator)}
      >
        <Ionicons name="calculator-outline" size={20} color={c.accentPrimary} />
        <Text style={[styles.calcToggleText, { color: c.textPrimary }]}>Permission Calculator</Text>
        <Ionicons
          name={showCalculator ? 'chevron-up' : 'chevron-down'}
          size={16}
          color={c.textMuted}
        />
      </Pressable>

      {showCalculator && (
        <View style={[styles.calcPanel, { backgroundColor: c.bgSecondary }]}>
          <Text style={[styles.calcHint, { color: c.textMuted }]}>
            Select a member's roles to see their final computed permissions in this channel.
          </Text>
          <View style={styles.calcRoles}>
            {roles.map((role) => {
              const selected = calcMemberId.includes(role.id);
              return (
                <Pressable
                  key={role.id}
                  style={[
                    styles.calcRoleChip,
                    { backgroundColor: selected ? c.accentPrimary : c.bgTertiary },
                  ]}
                  onPress={() => {
                    setCalcMemberId((prev) =>
                      prev.includes(role.id)
                        ? prev.replace(role.id + ',', '').replace(role.id, '')
                        : prev + role.id + ','
                    );
                  }}
                >
                  <Text
                    style={[
                      styles.calcRoleText,
                      { color: selected ? '#fff' : c.textPrimary },
                    ]}
                  >
                    @{role.name}
                  </Text>
                </Pressable>
              );
            })}
          </View>

          {calcMemberId && (
            <View style={styles.calcResults}>
              {PERMISSIONS.map((perm) => {
                const memberRoleIds = calcMemberId.split(',').filter(Boolean);
                const final = computeFinalPermissions(roles, memberRoleIds);
                const has = !!(final & perm.bit);
                return (
                  <View key={perm.key} style={styles.calcResultRow}>
                    <Ionicons
                      name={has ? 'checkmark-circle' : 'close-circle'}
                      size={16}
                      color={has ? '#57F287' : '#ED4245'}
                    />
                    <Text style={[styles.calcResultText, { color: c.textPrimary }]}>
                      {perm.label}
                    </Text>
                  </View>
                );
              })}
            </View>
          )}
        </View>
      )}
    </ScrollView>
  );
});

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { padding: spacing.md },
  title: { fontSize: 20, fontFamily: 'gg-sans-bold', marginBottom: 4 },
  subtitle: { ...typography.body, marginBottom: spacing.md },
  roleTabs: {
    flexDirection: 'row',
    marginBottom: spacing.md,
  },
  roleTab: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
    marginRight: 8,
    gap: 6,
  },
  roleColor: { width: 10, height: 10, borderRadius: 5 },
  roleTabText: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  grid: { borderRadius: 12, overflow: 'hidden', marginBottom: spacing.md },
  permRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.sm,
    paddingVertical: 10,
    gap: spacing.sm,
  },
  permLabel: { fontSize: 14, fontFamily: 'gg-sans-medium', flex: 1 },
  saveBtn: {
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: spacing.md,
  },
  saveBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 15 },
  calcToggle: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    borderRadius: 12,
    gap: spacing.sm,
    marginBottom: spacing.xs,
  },
  calcToggleText: { fontSize: 15, fontFamily: 'gg-sans-medium', flex: 1 },
  calcPanel: {
    borderRadius: 12,
    padding: spacing.sm,
    marginBottom: spacing.md,
  },
  calcHint: { ...typography.caption, marginBottom: spacing.sm },
  calcRoles: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginBottom: spacing.sm,
  },
  calcRoleChip: {
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 12,
  },
  calcRoleText: { fontSize: 12, fontFamily: 'gg-sans-medium' },
  calcResults: { marginTop: spacing.xs },
  calcResultRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 3,
  },
  calcResultText: { fontSize: 13, fontFamily: 'gg-sans' },
});
