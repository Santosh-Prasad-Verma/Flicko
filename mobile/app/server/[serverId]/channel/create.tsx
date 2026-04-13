/**
 * Create Channel Screen
 *
 * Mirrors web CreateChannelModal. Allows creating a text or voice channel.
 * Route: /server/[serverId]/channel/create
 * Requirements: 4.1, 4.2
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../../services/supabase';
import { Button } from '../../../../components/ui/Button';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../../constants/Colors';
import { useTheme } from '../../../../hooks/useTheme';

type ChannelType = 'text' | 'voice';

export default function CreateChannelScreen() {
  const { serverId } = useLocalSearchParams<{ serverId: string }>();
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const queryClient = useQueryClient();

  const [name, setName] = useState('');
  const [type, setType] = useState<ChannelType>('text');
  const [error, setError] = useState('');

  // Auto-format channel name (lowercase, replace spaces with hyphens)
  const handleNameChange = (value: string) => {
    setName(value.toLowerCase().replace(/\s+/g, '-'));
    if (error) setError('');
  };

  const createMutation = useMutation({
    mutationFn: async () => {
      const trimmed = name.trim();
      if (!trimmed) throw new Error('Channel name is required');
      if (trimmed.length > 100) throw new Error('Channel name must be 100 characters or less');

      const { data, error: createErr } = await supabase
        .from('channels')
        .insert({
          name: trimmed,
          type,
          server_id: serverId,
        })
        .select()
        .single();
      if (createErr) throw createErr;
      return data;
    },
    onSuccess: (channel) => {
      queryClient.invalidateQueries({ queryKey: ['channels', serverId] });
      router.replace(`/server/${serverId}/channel/${channel.id}`);
    },
    onError: (err: Error) => {
      setError(err.message);
    },
  });

  const handleCreate = () => {
    setError('');
    if (!name.trim()) {
      setError('Channel name is required');
      return;
    }
    createMutation.mutate();
  };

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Create Channel',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="close" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <KeyboardAvoidingView
        style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <ScrollView
          contentContainerStyle={[
            styles.content,
            { paddingBottom: insets.bottom + spacing.xxl },
          ]}
          keyboardShouldPersistTaps="handled"
        >
          {/* Channel Type */}
          <Text style={[styles.fieldLabel, { color: themeColors.textMuted }]}>
            CHANNEL TYPE
          </Text>
          <View style={[styles.typeGroup, { backgroundColor: themeColors.bgSecondary }]}>
            <Pressable
              style={[
                styles.typeOption,
                type === 'text' && { backgroundColor: themeColors.bgTertiary },
              ]}
              onPress={() => setType('text')}
            >
              <Ionicons
                name="text"
                size={24}
                color={type === 'text' ? themeColors.textPrimary : themeColors.textMuted}
              />
              <View style={styles.typeInfo}>
                <Text style={[styles.typeLabel, { color: themeColors.textPrimary }]}>
                  Text
                </Text>
                <Text style={[styles.typeDesc, { color: themeColors.textMuted }]}>
                  Send messages, images, GIFs, and more
                </Text>
              </View>
              <View
                style={[
                  styles.radio,
                  { borderColor: type === 'text' ? themeColors.accentPrimary : themeColors.textMuted },
                ]}
              >
                {type === 'text' && (
                  <View style={[styles.radioInner, { backgroundColor: themeColors.accentPrimary }]} />
                )}
              </View>
            </Pressable>

            <View style={[styles.typeDivider, { backgroundColor: themeColors.border }]} />

            <Pressable
              style={[
                styles.typeOption,
                type === 'voice' && { backgroundColor: themeColors.bgTertiary },
              ]}
              onPress={() => setType('voice')}
            >
              <Ionicons
                name="volume-high"
                size={24}
                color={type === 'voice' ? themeColors.textPrimary : themeColors.textMuted}
              />
              <View style={styles.typeInfo}>
                <Text style={[styles.typeLabel, { color: themeColors.textPrimary }]}>
                  Voice
                </Text>
                <Text style={[styles.typeDesc, { color: themeColors.textMuted }]}>
                  Hang out together with voice, video, and screen share
                </Text>
              </View>
              <View
                style={[
                  styles.radio,
                  { borderColor: type === 'voice' ? themeColors.accentPrimary : themeColors.textMuted },
                ]}
              >
                {type === 'voice' && (
                  <View style={[styles.radioInner, { backgroundColor: themeColors.accentPrimary }]} />
                )}
              </View>
            </Pressable>
          </View>

          {/* Channel Name */}
          <Text style={[styles.fieldLabel, { color: themeColors.textMuted, marginTop: spacing.xl }]}>
            CHANNEL NAME
          </Text>
          <View
            style={[
              styles.nameInputWrapper,
              {
                backgroundColor: themeColors.bgTertiary,
                borderColor: error ? themeColors.danger : 'transparent',
              },
            ]}
          >
            <Ionicons
              name={type === 'text' ? 'text' : 'volume-high'}
              size={18}
              color={themeColors.textMuted}
            />
            <TextInput
              style={[styles.nameInput, { color: themeColors.textPrimary }]}
              value={name}
              onChangeText={handleNameChange}
              placeholder="new-channel"
              placeholderTextColor={themeColors.textMuted}
              autoFocus
              maxLength={100}
              autoCapitalize="none"
              returnKeyType="done"
              onSubmitEditing={handleCreate}
            />
          </View>
          {error ? (
            <Text style={[styles.errorText, { color: themeColors.danger }]}>{error}</Text>
          ) : null}

          <View style={{ marginTop: spacing.xl }}>
            <Button
              title={createMutation.isPending ? 'Creating...' : 'Create Channel'}
              onPress={handleCreate}
              disabled={!name.trim() || createMutation.isPending}
              variant="primary"
            />
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    padding: spacing.xl,
  },
  fieldLabel: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: spacing.sm,
  },
  typeGroup: {
    borderRadius: 12,
    overflow: 'hidden',
  },
  typeOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.md,
    gap: spacing.sm,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  typeInfo: {
    flex: 1,
  },
  typeLabel: {
    ...typography.bodyBold,
  },
  typeDesc: {
    ...typography.caption,
    marginTop: 2,
  },
  typeDivider: {
    height: StyleSheet.hairlineWidth,
    marginHorizontal: spacing.md,
  },
  radio: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    justifyContent: 'center',
    alignItems: 'center',
  },
  radioInner: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  nameInputWrapper: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 8,
    paddingHorizontal: spacing.sm,
    gap: spacing.xs,
    borderWidth: 1,
  },
  nameInput: {
    flex: 1,
    ...typography.body,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  errorText: {
    ...typography.caption,
    marginTop: spacing.xs,
  },
});
