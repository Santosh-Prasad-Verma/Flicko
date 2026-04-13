/**
 * Linked Roles Settings (Feature 15)
 *
 * Admin screen to configure roles that are auto-assigned based on
 * connected accounts (GitHub, Twitch, YouTube, etc.)
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ScrollView,
  TextInput,
  Modal,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '../../hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import {
  useServerManagementStore,
  LinkedRoleRequirement,
} from '@stores/serverManagementStore';
import { supabase } from '@services/supabase';

const PROVIDERS = [
  { id: 'github', icon: 'logo-github', label: 'GitHub' },
  { id: 'twitch', icon: 'logo-twitch', label: 'Twitch' },
  { id: 'youtube', icon: 'logo-youtube', label: 'YouTube' },
  { id: 'spotify', icon: 'musical-notes', label: 'Spotify' },
  { id: 'email', icon: 'mail', label: 'Email Verification' },
] as const;

interface Props {
  serverId: string;
  roles: { id: string; name: string; color?: string }[];
}

export const LinkedRolesSettings = memo(function LinkedRolesSettings({ serverId, roles }: Props) {
  const { themeColors } = useTheme();
  const requirements = useServerManagementStore(
    (s) => s.linkedRoleRequirements[serverId] ?? []
  );
  const { addLinkedRoleRequirement, removeLinkedRoleRequirement } =
    useServerManagementStore();

  const [showModal, setShowModal] = useState(false);
  const [selectedRole, setSelectedRole] = useState('');
  const [selectedProvider, setSelectedProvider] = useState('');
  const [requirementValue, setRequirementValue] = useState('');

  const handleAdd = useCallback(async () => {
    if (!selectedRole || !selectedProvider) return;

    const req: LinkedRoleRequirement = {
      id: `${Date.now()}`,
      role_id: selectedRole,
      provider: selectedProvider as LinkedRoleRequirement['provider'],
      requirement:
        selectedProvider === 'email'
          ? { verified: true }
          : requirementValue
            ? { min_value: parseInt(requirementValue, 10) || 0 }
            : { connected: true },
    };

    addLinkedRoleRequirement(serverId, req);
    setShowModal(false);
    setSelectedRole('');
    setSelectedProvider('');
    setRequirementValue('');

    await supabase.from('linked_role_requirements').insert({
      id: req.id,
      server_id: serverId,
      role_id: req.role_id,
      provider: req.provider,
      requirement: req.requirement,
    });
  }, [serverId, selectedRole, selectedProvider, requirementValue, addLinkedRoleRequirement]);

  const handleRemove = useCallback(
    async (reqId: string) => {
      removeLinkedRoleRequirement(serverId, reqId);
      await supabase.from('linked_role_requirements').delete().eq('id', reqId);
    },
    [serverId, removeLinkedRoleRequirement]
  );

  const getRoleName = (roleId: string) =>
    roles.find((r) => r.id === roleId)?.name ?? 'Unknown Role';

  const getProviderLabel = (provider: string) =>
    PROVIDERS.find((p) => p.id === provider)?.label ?? provider;

  const getProviderIcon = (provider: string) =>
    PROVIDERS.find((p) => p.id === provider)?.icon ?? 'link';

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
      contentContainerStyle={styles.content}
    >
      <Text style={[styles.title, { color: themeColors.textPrimary }]}>Linked Roles</Text>
      <Text style={[styles.subtitle, { color: themeColors.textMuted }]}>
        Auto-assign roles when members connect external accounts.
      </Text>

      {requirements.length > 0 && (
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          {requirements.map((req) => (
            <View key={req.id} style={styles.ruleRow}>
              <Ionicons
                name={getProviderIcon(req.provider) as any}
                size={20}
                color={themeColors.accentPrimary}
              />
              <View style={styles.ruleInfo}>
                <Text style={[styles.ruleName, { color: themeColors.textPrimary }]}>
                  @{getRoleName(req.role_id)}
                </Text>
                <Text style={[styles.ruleDesc, { color: themeColors.textMuted }]}>
                  Requires {getProviderLabel(req.provider)} connection
                  {req.requirement && 'min_value' in req.requirement
                    ? ` (min: ${req.requirement.min_value})`
                    : ''}
                </Text>
              </View>
              <Pressable onPress={() => handleRemove(req.id)} hitSlop={8}>
                <Ionicons name="trash-outline" size={20} color={themeColors.danger} />
              </Pressable>
            </View>
          ))}
        </View>
      )}

      <Pressable
        style={[styles.addButton, { backgroundColor: themeColors.accentPrimary }]}
        onPress={() => setShowModal(true)}
      >
        <Ionicons name="add" size={20} color="#fff" />
        <Text style={styles.addButtonText}>Add Linked Role</Text>
      </Pressable>

      {/* Add Linked Role Modal */}
      <Modal visible={showModal} transparent animationType="fade">
        <Pressable style={styles.overlay} onPress={() => setShowModal(false)}>
          <Pressable
            style={[styles.modal, { backgroundColor: themeColors.bgSecondary }]}
            onPress={(e) => e.stopPropagation()}
          >
            <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>
              New Linked Role
            </Text>

            {/* Role Picker */}
            <Text style={[styles.label, { color: themeColors.textMuted }]}>ROLE</Text>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              style={styles.chipRow}
            >
              {roles.map((r) => (
                <Pressable
                  key={r.id}
                  style={[
                    styles.chip,
                    {
                      backgroundColor:
                        selectedRole === r.id ? themeColors.accentPrimary : themeColors.bgTertiary,
                    },
                  ]}
                  onPress={() => setSelectedRole(r.id)}
                >
                  <Text
                    style={[
                      styles.chipText,
                      {
                        color: selectedRole === r.id ? '#fff' : themeColors.textPrimary,
                      },
                    ]}
                  >
                    @{r.name}
                  </Text>
                </Pressable>
              ))}
            </ScrollView>

            {/* Provider Picker */}
            <Text style={[styles.label, { color: themeColors.textMuted }]}>PROVIDER</Text>
            <View style={styles.providerGrid}>
              {PROVIDERS.map((p) => (
                <Pressable
                  key={p.id}
                  style={[
                    styles.providerOption,
                    {
                      backgroundColor:
                        selectedProvider === p.id
                          ? themeColors.accentPrimary
                          : themeColors.bgTertiary,
                    },
                  ]}
                  onPress={() => setSelectedProvider(p.id)}
                >
                  <Ionicons
                    name={p.icon as any}
                    size={20}
                    color={selectedProvider === p.id ? '#fff' : themeColors.textPrimary}
                  />
                  <Text
                    style={[
                      styles.providerLabel,
                      {
                        color:
                          selectedProvider === p.id ? '#fff' : themeColors.textPrimary,
                      },
                    ]}
                  >
                    {p.label}
                  </Text>
                </Pressable>
              ))}
            </View>

            {/* Optional Requirement Value */}
            {selectedProvider && selectedProvider !== 'email' && (
              <>
                <Text style={[styles.label, { color: themeColors.textMuted }]}>
                  MINIMUM VALUE (optional)
                </Text>
                <TextInput
                  style={[
                    styles.input,
                    {
                      backgroundColor: themeColors.bgTertiary,
                      color: themeColors.textPrimary,
                    },
                  ]}
                  placeholder="e.g. 100 followers"
                  placeholderTextColor={themeColors.textMuted}
                  keyboardType="numeric"
                  value={requirementValue}
                  onChangeText={setRequirementValue}
                />
              </>
            )}

            <View style={styles.modalActions}>
              <Pressable
                style={[styles.cancelBtn, { backgroundColor: themeColors.bgTertiary }]}
                onPress={() => setShowModal(false)}
              >
                <Text style={[styles.cancelBtnText, { color: themeColors.textPrimary }]}>
                  Cancel
                </Text>
              </Pressable>
              <Pressable
                style={[
                  styles.saveBtn,
                  {
                    backgroundColor: themeColors.accentPrimary,
                    opacity: selectedRole && selectedProvider ? 1 : 0.5,
                  },
                ]}
                onPress={handleAdd}
                disabled={!selectedRole || !selectedProvider}
              >
                <Text style={styles.saveBtnText}>Save</Text>
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
  title: { fontSize: 20, fontFamily: 'gg-sans-bold', marginBottom: 4 },
  subtitle: { ...typography.body, marginBottom: spacing.md },
  card: { borderRadius: 12, overflow: 'hidden', marginBottom: spacing.md },
  ruleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    gap: spacing.sm,
  },
  ruleInfo: { flex: 1 },
  ruleName: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  ruleDesc: { ...typography.caption, marginTop: 1 },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 8,
    gap: spacing.xs,
  },
  addButtonText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 15 },
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.6)',
    justifyContent: 'center',
    padding: spacing.md,
  },
  modal: { borderRadius: 16, padding: spacing.md },
  modalTitle: { fontSize: 18, fontFamily: 'gg-sans-bold', marginBottom: spacing.md },
  label: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: spacing.xs,
    marginTop: spacing.sm,
  },
  chipRow: { flexDirection: 'row', marginBottom: spacing.xs },
  chip: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: 16, marginRight: 8 },
  chipText: { fontSize: 14, fontFamily: 'gg-sans-medium' },
  providerGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  providerOption: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    gap: 6,
  },
  providerLabel: { fontSize: 13, fontFamily: 'gg-sans-medium' },
  input: {
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    fontFamily: 'gg-sans',
    marginTop: 4,
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  cancelBtn: { paddingHorizontal: 16, paddingVertical: 10, borderRadius: 8 },
  cancelBtnText: { fontFamily: 'gg-sans-medium', fontSize: 14 },
  saveBtn: { paddingHorizontal: 20, paddingVertical: 10, borderRadius: 8 },
  saveBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 14 },
});
