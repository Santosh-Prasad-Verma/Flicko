/**
 * Role Management Screen
 *
 * Lists all server roles, allows create/delete, and navigates to role editor.
 * Route: /server/[serverId]/settings/roles
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  Pressable,
  Alert,
  TextInput,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../../../constants/Colors';
import { useServerRoles, useCreateRole, useDeleteRole } from '@hooks/usePermissions';
import type { Role } from '@shared/services/roleService';
import { Modal } from '../../../../../components/ui/Modal';
import { useTheme } from '../../../../../hooks/useTheme';

export default function RolesScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();

  const { data: roles, isLoading } = useServerRoles(serverId ?? '');
  const createRole = useCreateRole();
  const deleteRole = useDeleteRole();

  const [createVisible, setCreateVisible] = useState(false);
  const [newRoleName, setNewRoleName] = useState('');

  const handleCreate = () => {
    if (!newRoleName.trim() || !serverId) return;
    createRole.mutate(
      { serverId, name: newRoleName.trim() },
      {
        onSuccess: () => {
          setNewRoleName('');
          setCreateVisible(false);
        },
        onError: (err) => Alert.alert('Error', err.message),
      },
    );
  };

  const handleDelete = (role: Role) => {
    if (role.is_everyone) {
      Alert.alert('Cannot Delete', 'The @everyone role cannot be deleted.');
      return;
    }
    Alert.alert(
      'Delete Role',
      `Are you sure you want to delete "${role.name}"? This will remove the role from all members.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => deleteRole.mutate({ serverId: serverId!, roleId: role.id }),
        },
      ],
    );
  };

  const renderRole = ({ item }: { item: Role }) => (
    <Pressable
      onPress={() => router.push(`/server/${serverId}/settings/roles/${item.id}` as any)}
      onLongPress={() => handleDelete(item)}
      style={({ pressed }) => [
        styles.roleRow,
        { backgroundColor: pressed ? themeColors.bgTertiary : themeColors.bgSecondary },
      ]}
    >
      {/* Color indicator */}
      <View
        style={[
          styles.roleColor,
          { backgroundColor: item.color || themeColors.textMuted },
        ]}
      />
      <View style={styles.roleInfo}>
        <Text style={[styles.roleName, { color: item.color || themeColors.textPrimary }]}>
          {item.name}
        </Text>
        <Text style={[styles.rolePosition, { color: themeColors.textMuted }]}>
          Position: {item.position}
          {item.hoist ? ' · Hoisted' : ''}
          {item.mentionable ? ' · Mentionable' : ''}
        </Text>
      </View>
      {item.is_everyone && (
        <Text style={[styles.everyoneBadge, { color: themeColors.textMuted }]}>DEFAULT</Text>
      )}
      <Ionicons name="chevron-forward" size={16} color={themeColors.textMuted} />
    </Pressable>
  );

  return (
    <>
      <Stack.Screen options={{ headerShown: false }} />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        {/* Header */}
        <View
          style={[
            styles.header,
            { paddingTop: insets.top + spacing.sm, backgroundColor: themeColors.bgSecondary },
          ]}
        >
          <Pressable onPress={() => router.back()} hitSlop={12} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
          </Pressable>
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>Roles</Text>
          <Pressable onPress={() => setCreateVisible(true)} hitSlop={8} style={styles.addBtn}>
            <Ionicons name="add-circle-outline" size={24} color={themeColors.accentPrimary} />
          </Pressable>
        </View>

        <FlatList
          data={roles}
          keyExtractor={(item) => item.id}
          renderItem={renderRole}
          contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xl }}
          ListHeaderComponent={
            <Text style={[styles.helpText, { color: themeColors.textMuted }]}>
              Roles are listed from highest to lowest. Members get permissions from all their roles.
              Tap a role to edit, long-press to delete.
            </Text>
          }
        />

        {/* Create Role Modal */}
        <Modal visible={createVisible} onClose={() => setCreateVisible(false)}>
          <View style={[styles.createModal, { backgroundColor: themeColors.bgSecondary }]}>
            <Text style={[styles.modalTitle, { color: themeColors.textPrimary }]}>Create Role</Text>
            <TextInput
              style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.inputBg, borderColor: themeColors.border }]}
              placeholder="Role name"
              placeholderTextColor={themeColors.textMuted}
              value={newRoleName}
              onChangeText={setNewRoleName}
              autoFocus
              maxLength={100}
            />
            <View style={styles.modalActions}>
              <Pressable onPress={() => setCreateVisible(false)} style={styles.modalBtn}>
                <Text style={{ color: themeColors.textSecondary }}>Cancel</Text>
              </Pressable>
              <Pressable
                onPress={handleCreate}
                style={[styles.modalBtn, styles.createBtn, { backgroundColor: themeColors.accentPrimary }]}
                disabled={!newRoleName.trim()}
              >
                <Text style={{ color: '#fff', fontFamily: 'gg-sans-semibold' }}>Create</Text>
              </Pressable>
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
  helpText: {
    ...typography.caption,
    padding: spacing.lg,
    lineHeight: 18,
  },
  roleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(255,255,255,0.05)',
  },
  roleColor: {
    width: 14,
    height: 14,
    borderRadius: 7,
    marginRight: spacing.md,
  },
  roleInfo: { flex: 1 },
  roleName: { ...typography.bodyM, fontFamily: 'gg-sans-semibold' },
  rolePosition: { ...typography.caption, marginTop: 2 },
  everyoneBadge: {
    fontSize: 10,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    marginRight: spacing.sm,
  },
  createModal: {
    borderRadius: 12,
    padding: spacing.lg,
    margin: spacing.lg,
  },
  modalTitle: { ...typography.headingS, marginBottom: spacing.md },
  input: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
    fontSize: 16,
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.md,
    marginTop: spacing.lg,
  },
  modalBtn: {
    paddingHorizontal: spacing.lg,
    paddingVertical: 10,
    borderRadius: 8,
  },
  createBtn: {
    minWidth: 80,
    alignItems: 'center',
  },
});
