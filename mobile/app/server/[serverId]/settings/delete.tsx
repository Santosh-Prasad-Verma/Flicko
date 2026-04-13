/**
 * Delete Server Screen — Discord-style confirmation
 *
 * Requires the user to type the server name to confirm deletion.
 * Only the server owner can access this screen.
 *
 * Route: /server/[serverId]/settings/delete
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../services/supabase';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';
import { useAuthStore, type AuthStore } from '@stores/authStore';

export default function DeleteServerScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: AuthStore) => s.user);
  const [confirmName, setConfirmName] = useState('');

  const { data: server } = useQuery({
    queryKey: ['server', serverId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('servers')
        .select('*')
        .eq('id', serverId)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!serverId,
  });

  const isOwner = server?.owner_id === user?.id;
  const nameMatches = confirmName.trim() === server?.name;

  const deleteMutation = useMutation({
    mutationFn: async () => {
      if (!isOwner) throw new Error('Only the server owner can delete this server');
      if (!nameMatches) throw new Error('Server name does not match');

      const { error } = await supabase
        .from('servers')
        .delete()
        .eq('id', serverId)
        .eq('owner_id', user?.id);

      if (error) throw new Error(`Failed to delete server: ${error.message}`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['servers'] });
      queryClient.removeQueries({ queryKey: ['server', serverId] });
      queryClient.removeQueries({ queryKey: ['channels', serverId] });
      // Navigate back to home
      router.replace('/(tabs)');
    },
    onError: (err: Error) => {
      Alert.alert('Delete Failed', err.message);
    },
  });

  const handleDelete = () => {
    Alert.alert(
      'Delete Server',
      `Are you absolutely sure? This will permanently delete "${server?.name}" and all its channels, messages, and data. This action cannot be undone.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => deleteMutation.mutate(),
        },
      ],
    );
  };

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
          <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
            Delete Server
          </Text>
        </View>

        <View style={styles.content}>
          {/* Warning */}
          <View style={[styles.warningBox, { backgroundColor: '#ED424520' }]}>
            <Ionicons name="warning" size={24} color="#ED4245" />
            <Text style={[styles.warningText, { color: '#ED4245' }]}>
              This action is irreversible. All channels, messages, roles, and data will be
              permanently deleted.
            </Text>
          </View>

          {!isOwner ? (
            <Text style={[styles.notOwnerText, { color: themeColors.textSecondary }]}>
              Only the server owner can delete this server.
            </Text>
          ) : (
            <>
              {/* Confirm input */}
              <Text style={[styles.label, { color: themeColors.textSecondary }]}>
                Enter the server name{' '}
                <Text style={{ fontFamily: 'gg-sans-bold', color: themeColors.textPrimary }}>
                  {server?.name}
                </Text>{' '}
                to confirm
              </Text>
              <TextInput
                style={[
                  styles.input,
                  {
                    color: themeColors.textPrimary,
                    backgroundColor: themeColors.bgTertiary,
                    borderColor: nameMatches ? '#ED4245' : themeColors.border,
                  },
                ]}
                value={confirmName}
                onChangeText={setConfirmName}
                placeholder="Type server name here..."
                placeholderTextColor={themeColors.textMuted}
                autoCapitalize="none"
                autoCorrect={false}
              />

              {/* Delete button */}
              <Pressable
                onPress={handleDelete}
                disabled={!nameMatches || deleteMutation.isPending}
                style={[
                  styles.deleteBtn,
                  {
                    backgroundColor: nameMatches ? '#ED4245' : themeColors.bgTertiary,
                    opacity: nameMatches ? 1 : 0.5,
                  },
                ]}
              >
                {deleteMutation.isPending ? (
                  <ActivityIndicator size="small" color="#fff" />
                ) : (
                  <Text style={styles.deleteBtnText}>Delete Server</Text>
                )}
              </Pressable>
            </>
          )}
        </View>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingBottom: spacing.md,
    gap: spacing.sm,
  },
  backBtn: {
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerTitle: {
    ...typography.headingM,
  },
  content: {
    padding: spacing.xl,
    gap: spacing.lg,
  },
  warningBox: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    padding: spacing.md,
    borderRadius: 8,
    gap: spacing.sm,
  },
  warningText: {
    flex: 1,
    fontSize: 14,
    lineHeight: 20,
    fontFamily: 'gg-sans-medium',
  },
  notOwnerText: {
    fontSize: 15,
    textAlign: 'center',
    marginTop: spacing.lg,
  },
  label: {
    fontSize: 14,
    lineHeight: 20,
  },
  input: {
    borderRadius: 8,
    padding: spacing.sm,
    fontSize: 16,
    minHeight: MINIMUM_TOUCH_TARGET,
    borderWidth: 1,
  },
  deleteBtn: {
    height: MINIMUM_TOUCH_TARGET,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: spacing.sm,
  },
  deleteBtnText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
  },
});
