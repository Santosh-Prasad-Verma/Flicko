/**
 * Change Username Screen
 *
 * Allows the authenticated user to change their @username.
 * Validates format, checks uniqueness in the profiles table, then writes the update.
 * Route: /settings/change-username
 */
import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
  Alert,
  ActivityIndicator,
} from 'react-native';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import { supabase } from '../../services/supabase';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

const USERNAME_REGEX = /^[a-zA-Z0-9_]{3,32}$/;

type ValidationState = 'idle' | 'checking' | 'available' | 'taken' | 'invalid';

export default function ChangeUsernameScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: AuthStore) => s.user);
  const setUser = useAuthStore((s: AuthStore) => s.setUser);

  const [username, setUsername] = useState('');
  const [validation, setValidation] = useState<ValidationState>('idle');
  const [loading, setLoading] = useState(false);
  const [checkTimeout, setCheckTimeout] = useState<ReturnType<typeof setTimeout> | null>(null);

  const validateFormat = (value: string) => USERNAME_REGEX.test(value);

  const handleUsernameChange = useCallback(
    (value: string) => {
      // Only allow valid characters as the user types
      const cleaned = value.replace(/[^a-zA-Z0-9_]/g, '').slice(0, 32);
      setUsername(cleaned);

      if (checkTimeout) clearTimeout(checkTimeout);

      if (cleaned.length === 0) {
        setValidation('idle');
        return;
      }

      if (!validateFormat(cleaned)) {
        setValidation('invalid');
        return;
      }

      if (cleaned.toLowerCase() === (user?.username ?? '').toLowerCase()) {
        setValidation('idle');
        return;
      }

      // Debounce uniqueness check
      setValidation('checking');
      const t = setTimeout(async () => {
        try {
          const { data, error } = await supabase
            .from('profiles')
            .select('id')
            .ilike('username', cleaned)
            .limit(1);

          if (error) throw error;
          setValidation(data && data.length > 0 ? 'taken' : 'available');
        } catch {
          setValidation('idle');
        }
      }, 500);
      setCheckTimeout(t);
    },
    [user?.username, checkTimeout],
  );

  const canSave =
    validation === 'available' &&
    validateFormat(username) &&
    username.toLowerCase() !== (user?.username ?? '').toLowerCase() &&
    !loading;

  const handleSave = async () => {
    if (!canSave || !user?.id) return;

    setLoading(true);
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ username, updated_at: new Date().toISOString() })
        .eq('id', user.id);

      if (error) throw error;

      // Update local auth store
      setUser({ ...user, username });

      Alert.alert(
        'Username Updated',
        `Your username has been changed to @${username}.`,
        [{ text: 'OK', onPress: () => router.back() }],
      );
    } catch (err: any) {
      if (err.code === '23505' || err.message?.includes('unique')) {
        Alert.alert('Username Taken', 'That username is already in use. Please choose another.');
        setValidation('taken');
      } else {
        Alert.alert('Error', err.message || 'Failed to update username. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  const validationIcon = () => {
    switch (validation) {
      case 'checking':
        return <ActivityIndicator size="small" color={themeColors.textMuted} />;
      case 'available':
        return <Ionicons name="checkmark-circle" size={20} color={themeColors.success} />;
      case 'taken':
        return <Ionicons name="close-circle" size={20} color={themeColors.danger} />;
      case 'invalid':
        return <Ionicons name="alert-circle" size={20} color={themeColors.warning} />;
      default:
        return null;
    }
  };

  const validationMessage = () => {
    switch (validation) {
      case 'checking':
        return { text: 'Checking availability…', color: themeColors.textMuted };
      case 'available':
        return { text: `@${username} is available!`, color: themeColors.success };
      case 'taken':
        return { text: 'That username is already taken.', color: themeColors.danger };
      case 'invalid':
        return {
          text: 'Username must be 3–32 characters: letters, numbers, or underscores only.',
          color: themeColors.warning,
        };
      default:
        return null;
    }
  };

  const msg = validationMessage();

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Change Username',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
          headerRight: () => (
            <Pressable
              onPress={handleSave}
              disabled={!canSave}
              hitSlop={8}
              style={{ marginRight: 4 }}
            >
              {loading ? (
                <ActivityIndicator size="small" color={themeColors.accentPrimary} />
              ) : (
                <Text
                  style={[
                    styles.saveBtn,
                    { color: canSave ? themeColors.accentPrimary : themeColors.textMuted },
                  ]}
                >
                  Save
                </Text>
              )}
            </Pressable>
          ),
        }}
      />

      <ScrollView
        style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
        keyboardShouldPersistTaps="handled"
        contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
      >
        {/* Current username display */}
        <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>CURRENT USERNAME</Text>
        <View style={[styles.currentBox, { backgroundColor: themeColors.bgSecondary }]}>
          <Text style={[styles.atSign, { color: themeColors.textMuted }]}>@</Text>
          <Text style={[styles.currentUsername, { color: themeColors.textSecondary }]}>
            {user?.username || 'Not set'}
          </Text>
        </View>

        {/* New username input */}
        <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>NEW USERNAME</Text>
        <View style={[styles.inputGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <View
            style={[
              styles.inputRow,
              {
                borderColor:
                  validation === 'taken' || validation === 'invalid'
                    ? themeColors.danger
                    : validation === 'available'
                    ? themeColors.success
                    : themeColors.border,
              },
            ]}
          >
            <Text style={[styles.atSign, { color: themeColors.textMuted }]}>@</Text>
            <TextInput
              value={username}
              onChangeText={handleUsernameChange}
              placeholder={user?.username || 'new_username'}
              placeholderTextColor={themeColors.textMuted}
              autoCapitalize="none"
              autoCorrect={false}
              autoComplete="username"
              returnKeyType="done"
              onSubmitEditing={handleSave}
              style={[styles.input, { color: themeColors.textPrimary }]}
            />
            {validationIcon()}
          </View>
          {msg && (
            <Text style={[styles.validationMsg, { color: msg.color }]}>{msg.text}</Text>
          )}
        </View>

        {/* Rules info box */}
        <View style={[styles.rulesBox, { backgroundColor: themeColors.bgSecondary, borderLeftColor: themeColors.accentPrimary }]}>
          <Text style={[styles.rulesTitle, { color: themeColors.textPrimary }]}>Username rules</Text>
          <Text style={[styles.rulesText, { color: themeColors.textSecondary }]}>• 3–32 characters long</Text>
          <Text style={[styles.rulesText, { color: themeColors.textSecondary }]}>• Letters (a–z), numbers (0–9), and underscores _ only</Text>
          <Text style={[styles.rulesText, { color: themeColors.textSecondary }]}>• Must be unique — no two accounts can share one</Text>
        </View>

        <Pressable
          style={[
            styles.submitBtn,
            { backgroundColor: canSave ? themeColors.accentPrimary : themeColors.bgTertiary },
          ]}
          onPress={handleSave}
          disabled={!canSave}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={[styles.submitBtnText, { color: canSave ? '#fff' : themeColors.textMuted }]}>
              Update Username
            </Text>
          )}
        </Pressable>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  sectionLabel: {
    ...typography.overline,
    fontSize: 11,
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    marginBottom: spacing.xs,
  },
  currentBox: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.lg,
    borderRadius: 12,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm + 2,
    minHeight: 50,
  },
  currentUsername: {
    ...typography.body,
    flex: 1,
  },
  atSign: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
    marginRight: 2,
  },
  inputGroup: {
    marginHorizontal: spacing.lg,
    borderRadius: 12,
    overflow: 'hidden',
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    borderWidth: 1,
    borderRadius: 12,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    minHeight: 50,
  },
  input: {
    flex: 1,
    ...typography.body,
    paddingVertical: 4,
  },
  validationMsg: {
    ...typography.bodySmall,
    marginTop: spacing.xs,
    marginHorizontal: spacing.sm,
    marginBottom: spacing.xs,
  },
  rulesBox: {
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    padding: spacing.md,
    borderRadius: 12,
    borderLeftWidth: 3,
    gap: 4,
  },
  rulesTitle: {
    ...typography.bodySmall,
    fontFamily: 'gg-sans-semibold',
    marginBottom: spacing.xs,
  },
  rulesText: {
    ...typography.bodySmall,
    lineHeight: 18,
  },
  submitBtn: {
    marginHorizontal: spacing.lg,
    marginTop: spacing.xl,
    paddingVertical: spacing.md,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 50,
  },
  submitBtnText: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
    fontSize: 16,
  },
  saveBtn: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
    fontSize: 16,
  },
});
