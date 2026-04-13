/**
 * Role Editor Screen
 *
 * Edit a single role: name, color, hoist, mentionable, and all 40+ permissions
 * organized by category with toggle switches.
 *
 * Route: /server/[serverId]/settings/roles/[roleId]
 */
import React, { useCallback, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Switch,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../../../constants/Colors';
import { useRole, useUpdateRole } from '@hooks/usePermissions';
import { useTheme } from '../../../../../hooks/useTheme';
import {
  Permissions,
  PERMISSION_DEFINITIONS,
  parsePermissions,
  hasPermission,
  addPermission,
  removePermission,
  type PermissionMeta,
} from '@shared/constants/permissions';

const COLOR_PRESETS = [
  '#99AAB5', '#1ABC9C', '#2ECC71', '#3498DB', '#9B59B6',
  '#E91E63', '#F1C40F', '#E67E22', '#E74C3C', '#95A5A6',
  '#607D8B', '#11806A', '#1F8B4C', '#206694', '#71368A',
  '#AD1457', '#C27C0E', '#A84300', '#992D22', '#979C9F',
];

const CATEGORIES = ['general', 'membership', 'text', 'voice', 'advanced'] as const;
const CATEGORY_LABELS: Record<string, string> = {
  general: 'General Server Permissions',
  membership: 'Membership Permissions',
  text: 'Text Channel Permissions',
  voice: 'Voice Channel Permissions',
  advanced: 'Advanced Permissions',
};

export default function RoleEditorScreen() {
  const { serverId, roleId } = useLocalSearchParams<{ serverId: string; roleId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();

  const { data: role, isLoading } = useRole(roleId ?? '');
  const updateRole = useUpdateRole();

  // Local editable state
  const [name, setName] = useState('');
  const [roleColor, setRoleColor] = useState<string | null>(null);
  const [hoist, setHoist] = useState(false);
  const [mentionable, setMentionable] = useState(false);
  const [perms, setPerms] = useState(0n);
  const [dirty, setDirty] = useState(false);

  // Initialize from fetched role
  useEffect(() => {
    if (!role) return;
    setName(role.name);
    setRoleColor(role.color);
    setHoist(role.hoist);
    setMentionable(role.mentionable);
    setPerms(parsePermissions(role.permissions));
    setDirty(false);
  }, [role]);

  const togglePerm = useCallback((perm: bigint) => {
    setPerms((prev) => {
      const next = hasPermission(prev, perm) ? removePermission(prev, perm) : addPermission(prev, perm);
      setDirty(true);
      return next;
    });
  }, []);

  const handleSave = () => {
    if (!roleId) return;
    updateRole.mutate(
      {
        roleId,
        input: {
          name: name.trim(),
          color: roleColor,
          hoist,
          mentionable,
          permissions: perms,
        },
      },
      {
        onSuccess: () => {
          setDirty(false);
          Alert.alert('Saved', 'Role updated successfully.');
        },
        onError: (err) => Alert.alert('Error', err.message),
      },
    );
  };

  if (isLoading || !role) {
    return (
      <View style={[styles.container, styles.center, { backgroundColor: themeColors.bgPrimary }]}>
        <ActivityIndicator color={themeColors.accentPrimary} />
      </View>
    );
  }

  const isAdmin = hasPermission(perms, Permissions.ADMINISTRATOR);

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
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]} numberOfLines={1}>
            Edit Role
          </Text>
          {dirty && (
            <Pressable
              onPress={handleSave}
              disabled={updateRole.isPending}
              style={[styles.saveBtn, { backgroundColor: themeColors.success }]}
            >
              {updateRole.isPending ? (
                <ActivityIndicator size="small" color="#fff" />
              ) : (
                <Text style={styles.saveBtnText}>Save</Text>
              )}
            </Pressable>
          )}
        </View>

        <ScrollView contentContainerStyle={{ paddingBottom: insets.bottom + 80 }}>
          {/* Role Name */}
          <View style={[styles.section, { backgroundColor: themeColors.bgSecondary }]}>
            <Text style={[styles.label, { color: themeColors.textMuted }]}>ROLE NAME</Text>
            <TextInput
              style={[styles.input, { color: themeColors.textPrimary, backgroundColor: themeColors.inputBg, borderColor: themeColors.border }]}
              value={name}
              onChangeText={(v) => { setName(v); setDirty(true); }}
              maxLength={100}
              placeholder="Role name"
              placeholderTextColor={themeColors.textMuted}
              editable={!role.is_everyone}
            />
          </View>

          {/* Role Color */}
          <View style={[styles.section, { backgroundColor: themeColors.bgSecondary }]}>
            <Text style={[styles.label, { color: themeColors.textMuted }]}>ROLE COLOR</Text>
            <View style={styles.colorGrid}>
              {COLOR_PRESETS.map((c) => (
                <Pressable
                  key={c}
                  onPress={() => { setRoleColor(c); setDirty(true); }}
                  style={[
                    styles.colorSwatch,
                    { backgroundColor: c },
                    roleColor === c && styles.colorSelected,
                  ]}
                />
              ))}
              <Pressable
                onPress={() => { setRoleColor(null); setDirty(true); }}
                style={[
                  styles.colorSwatch,
                  { backgroundColor: themeColors.bgTertiary, borderWidth: 1, borderColor: themeColors.border },
                  !roleColor && styles.colorSelected,
                ]}
              >
                <Ionicons name="close" size={14} color={themeColors.textMuted} />
              </Pressable>
            </View>
          </View>

          {/* Toggles */}
          <View style={[styles.section, { backgroundColor: themeColors.bgSecondary }]}>
            <View style={styles.toggleRow}>
              <View style={styles.toggleInfo}>
                <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>
                  Display role members separately
                </Text>
                <Text style={[styles.toggleDesc, { color: themeColors.textMuted }]}>
                  Members with this role will be shown separately in the member list
                </Text>
              </View>
              <Switch
                value={hoist}
                onValueChange={(v) => { setHoist(v); setDirty(true); }}
                trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
              />
            </View>
            <View style={styles.divider} />
            <View style={styles.toggleRow}>
              <View style={styles.toggleInfo}>
                <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>
                  Allow anyone to @mention this role
                </Text>
                <Text style={[styles.toggleDesc, { color: themeColors.textMuted }]}>
                  Members can mention this role in messages
                </Text>
              </View>
              <Switch
                value={mentionable}
                onValueChange={(v) => { setMentionable(v); setDirty(true); }}
                trackColor={{ false: themeColors.bgTertiary, true: themeColors.accentPrimary }}
              />
            </View>
          </View>

          {/* Permissions by category */}
          {isAdmin && (
            <View style={[styles.adminBanner, { backgroundColor: themeColors.warning + '20' }]}>
              <Ionicons name="warning" size={16} color={themeColors.warning} />
              <Text style={[styles.adminText, { color: themeColors.warning }]}>
                Administrator permission grants ALL permissions and bypasses channel overrides.
              </Text>
            </View>
          )}

          {CATEGORIES.map((cat) => {
            const categoryPerms = PERMISSION_DEFINITIONS.filter((p) => p.category === cat);
            if (categoryPerms.length === 0) return null;

            return (
              <View key={cat} style={styles.permSection}>
                <Text style={[styles.permSectionTitle, { color: themeColors.textMuted }]}>
                  {CATEGORY_LABELS[cat]}
                </Text>
                <View style={[styles.permList, { backgroundColor: themeColors.bgSecondary }]}>
                  {categoryPerms.map((perm, idx) => {
                    const bit = Permissions[perm.name];
                    const enabled = hasPermission(perms, bit);
                    const isDangerous = perm.dangerous;

                    return (
                      <React.Fragment key={perm.name}>
                        {idx > 0 && <View style={styles.divider} />}
                        <View style={styles.permRow}>
                          <View style={styles.permInfo}>
                            <Text
                              style={[
                                styles.permLabel,
                                { color: isDangerous && enabled ? themeColors.danger : themeColors.textPrimary },
                              ]}
                            >
                              {perm.label}
                              {isDangerous ? ' ⚠️' : ''}
                            </Text>
                            <Text style={[styles.permDesc, { color: themeColors.textMuted }]}>
                              {perm.description}
                            </Text>
                          </View>
                          <Switch
                            value={enabled}
                            onValueChange={() => {
                              if (perm.name === 'ADMINISTRATOR' && !enabled) {
                                Alert.alert(
                                  'Enable Administrator?',
                                  'This grants ALL permissions and bypasses channel overrides.',
                                  [
                                    { text: 'Cancel', style: 'cancel' },
                                    { text: 'Enable', onPress: () => togglePerm(bit) },
                                  ],
                                );
                              } else {
                                togglePerm(bit);
                              }
                            }}
                            trackColor={{
                              false: themeColors.bgTertiary,
                              true: isDangerous ? themeColors.danger : themeColors.accentPrimary,
                            }}
                          />
                        </View>
                      </React.Fragment>
                    );
                  })}
                </View>
              </View>
            );
          })}
        </ScrollView>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  center: { justifyContent: 'center', alignItems: 'center' },
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
  saveBtn: {
    paddingHorizontal: spacing.lg,
    paddingVertical: 8,
    borderRadius: 8,
    minWidth: 70,
    alignItems: 'center',
  },
  saveBtnText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 14 },
  section: {
    marginTop: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
  },
  label: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    marginBottom: spacing.sm,
  },
  input: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: spacing.md,
    paddingVertical: 12,
    fontSize: 16,
  },
  colorGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  colorSwatch: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
  colorSelected: {
    borderWidth: 3,
    borderColor: '#fff',
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.sm,
  },
  toggleInfo: { flex: 1, marginRight: spacing.md },
  toggleLabel: { ...typography.bodyM },
  toggleDesc: { ...typography.caption, marginTop: 2 },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: 'rgba(255,255,255,0.05)',
  },
  adminBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginHorizontal: spacing.lg,
    marginTop: spacing.md,
    padding: spacing.md,
    borderRadius: 8,
  },
  adminText: { flex: 1, fontSize: 13, lineHeight: 18 },
  permSection: { marginTop: spacing.lg },
  permSectionTitle: {
    fontSize: 11,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.6,
    paddingHorizontal: spacing.lg,
    paddingBottom: spacing.sm,
  },
  permList: {
    paddingHorizontal: spacing.lg,
  },
  permRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
  },
  permInfo: { flex: 1, marginRight: spacing.md },
  permLabel: { ...typography.bodyM },
  permDesc: { ...typography.caption, marginTop: 2, lineHeight: 16 },
});
