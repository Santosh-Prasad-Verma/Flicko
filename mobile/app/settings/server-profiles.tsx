/**
 * Per-Server Profile Selector
 *
 * Lists all servers the user is a member of, allowing them
 * to customise their nickname and avatar per-server (like Discord).
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { Stack, router } from 'expo-router';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { Avatar } from '../../components/ui/Avatar';
import { spacing, borderRadius, typography } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import { supabase } from '../../services/supabase';

interface ServerWithMembership {
  id: string;
  name: string;
  icon: string | null;
  nickname: string | null;
}

export default function ServerProfilesScreen() {
  const { themeColors: c } = useTheme();
  const user = useAuthStore((s: AuthStore) => s.user);
  const queryClient = useQueryClient();
  const [editingServerId, setEditingServerId] = useState<string | null>(null);
  const [nickname, setNickname] = useState('');

  const { data: servers, isLoading } = useQuery({
    queryKey: ['server-profiles', user?.id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('server_members')
        .select('server_id, nickname, servers(id, name, icon)')
        .eq('user_id', user!.id);
      if (error) throw error;
      return (data ?? []).map((d: any) => ({
        id: d.servers.id,
        name: d.servers.name,
        icon: d.servers.icon,
        nickname: d.nickname,
      })) as ServerWithMembership[];
    },
    enabled: !!user?.id,
  });

  const updateNickname = useMutation({
    mutationFn: async ({ serverId, newNickname }: { serverId: string; newNickname: string | null }) => {
      const { error } = await supabase
        .from('server_members')
        .update({ nickname: newNickname || null })
        .eq('server_id', serverId)
        .eq('user_id', user!.id);
      if (error) throw error;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['server-profiles', user?.id] });
      setEditingServerId(null);
      setNickname('');
    },
    onError: (err: Error) => {
      Alert.alert('Error', err.message);
    },
  });

  const handleStartEdit = (server: ServerWithMembership) => {
    setEditingServerId(server.id);
    setNickname(server.nickname || '');
  };

  const handleSave = (serverId: string) => {
    updateNickname.mutate({ serverId, newNickname: nickname.trim() || null });
  };

  return (
    <ScrollView style={[styles.container, { backgroundColor: c.bgPrimary }]}>
      <Stack.Screen
        options={{
          title: 'Server Profiles',
          headerStyle: { backgroundColor: c.bgSecondary },
          headerTintColor: c.textPrimary,
        }}
      />

      <Text style={[styles.description, { color: c.textSecondary }]}>
        Set a unique nickname for each server. Other members will see this name instead of your global display name.
      </Text>

      {isLoading ? (
        <ActivityIndicator color={c.accentPrimary} style={{ marginTop: 40 }} />
      ) : !servers?.length ? (
        <View style={styles.emptyState}>
          <Ionicons name="server-outline" size={48} color={c.textMuted} />
          <Text style={[styles.emptyText, { color: c.textMuted }]}>
            You're not in any servers yet
          </Text>
        </View>
      ) : (
        <View style={styles.serverList}>
          {servers.map((server) => {
            const isEditing = editingServerId === server.id;
            return (
              <View
                key={server.id}
                style={[styles.serverCard, { backgroundColor: c.bgSecondary }]}
              >
                <View style={styles.serverHeader}>
                  <Avatar
                    name={server.name}
                    imageUrl={server.icon ?? undefined}
                    size={40}
                  />
                  <View style={styles.serverInfo}>
                    <Text style={[styles.serverName, { color: c.textPrimary }]}>
                      {server.name}
                    </Text>
                    <Text style={[styles.currentNickname, { color: c.textSecondary }]}>
                      {server.nickname ? `Nickname: ${server.nickname}` : 'No server nickname set'}
                    </Text>
                  </View>
                  {!isEditing && (
                    <Pressable
                      style={[styles.editBtn, { backgroundColor: c.bgTertiary }]}
                      onPress={() => handleStartEdit(server)}
                    >
                      <Ionicons name="pencil" size={16} color={c.textSecondary} />
                    </Pressable>
                  )}
                </View>

                {isEditing && (
                  <View style={styles.editSection}>
                    <TextInput
                      style={[styles.nicknameInput, { color: c.textPrimary, backgroundColor: c.inputBg, borderColor: c.border }]}
                      value={nickname}
                      onChangeText={setNickname}
                      placeholder="Server nickname"
                      placeholderTextColor={c.textMuted}
                      maxLength={32}
                      autoFocus
                    />
                    <View style={styles.editActions}>
                      <Pressable
                        style={[styles.cancelBtn, { borderColor: c.border }]}
                        onPress={() => { setEditingServerId(null); setNickname(''); }}
                      >
                        <Text style={[styles.cancelBtnText, { color: c.textSecondary }]}>Cancel</Text>
                      </Pressable>
                      <Pressable
                        style={[styles.saveBtn, { backgroundColor: c.accentPrimary }]}
                        onPress={() => handleSave(server.id)}
                        disabled={updateNickname.isPending}
                      >
                        {updateNickname.isPending ? (
                          <ActivityIndicator color="#fff" size="small" />
                        ) : (
                          <Text style={styles.saveBtnText}>Save</Text>
                        )}
                      </Pressable>
                    </View>
                  </View>
                )}
              </View>
            );
          })}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  description: {
    fontSize: 14,
    lineHeight: 20,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.lg,
    paddingBottom: spacing.md,
  },
  serverList: {
    paddingHorizontal: spacing.md,
    gap: spacing.sm,
    paddingBottom: 40,
  },
  serverCard: {
    borderRadius: borderRadius.md,
    padding: spacing.md,
  },
  serverHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  serverInfo: {
    flex: 1,
  },
  serverName: {
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
  },
  currentNickname: {
    fontSize: 12,
    marginTop: 2,
  },
  editBtn: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  editSection: {
    marginTop: spacing.sm,
    gap: spacing.sm,
  },
  nicknameInput: {
    height: 42,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
    paddingHorizontal: spacing.md,
    fontSize: 14,
  },
  editActions: {
    flexDirection: 'row',
    gap: spacing.sm,
    justifyContent: 'flex-end',
  },
  cancelBtn: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: borderRadius.sm,
    borderWidth: 1,
  },
  cancelBtnText: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
  },
  saveBtn: {
    paddingHorizontal: 20,
    paddingVertical: 8,
    borderRadius: borderRadius.sm,
    minWidth: 70,
    alignItems: 'center',
  },
  saveBtnText: {
    color: '#fff',
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  emptyState: {
    alignItems: 'center',
    paddingTop: 60,
    gap: 12,
  },
  emptyText: {
    fontSize: 15,
  },
});
