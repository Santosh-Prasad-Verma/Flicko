/**
 * Change Email Screen
 *
 * Allows the authenticated user to change their account email address.
 * Supabase will send a confirmation link to both the old and new email before committing the change.
 * Route: /settings/change-email
 */
import React, { useState } from 'react';
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

export default function ChangeEmailScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: AuthStore) => s.user);

  const [newEmail, setNewEmail] = useState('');
  const [loading, setLoading] = useState(false);

  const isValidEmail = (email: string) =>
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());

  const canSave =
    newEmail.trim().length > 0 &&
    isValidEmail(newEmail) &&
    newEmail.trim().toLowerCase() !== (user?.email ?? '').toLowerCase() &&
    !loading;

  const handleSave = async () => {
    const trimmedEmail = newEmail.trim().toLowerCase();

    if (!isValidEmail(trimmedEmail)) {
      Alert.alert('Invalid Email', 'Please enter a valid email address.');
      return;
    }

    if (trimmedEmail === (user?.email ?? '').toLowerCase()) {
      Alert.alert('No Change', 'This is already your current email address.');
      return;
    }

    setLoading(true);
    try {
      const { error } = await supabase.auth.updateUser({ email: trimmedEmail });

      if (error) throw error;

      Alert.alert(
        'Confirmation Sent',
        `A confirmation link has been sent to both ${user?.email} and ${trimmedEmail}.\n\nFollow the links in both emails to complete the change.`,
        [{ text: 'OK', onPress: () => router.back() }],
      );
    } catch (err: any) {
      Alert.alert('Error', err.message || 'Failed to update email. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Change Email',
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
        {/* Current email display */}
        <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>CURRENT EMAIL</Text>
        <View style={[styles.currentEmailBox, { backgroundColor: themeColors.bgSecondary }]}>
          <Ionicons name="mail-outline" size={18} color={themeColors.textMuted} style={styles.emailIcon} />
          <Text style={[styles.currentEmailText, { color: themeColors.textSecondary }]} numberOfLines={1}>
            {user?.email || 'Not set'}
          </Text>
        </View>

        {/* New email input */}
        <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>NEW EMAIL ADDRESS</Text>
        <View style={[styles.inputGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <View
            style={[
              styles.inputRow,
              {
                borderColor:
                  newEmail && !isValidEmail(newEmail) ? themeColors.danger : themeColors.border,
              },
            ]}
          >
            <TextInput
              value={newEmail}
              onChangeText={setNewEmail}
              placeholder="Enter new email address"
              placeholderTextColor={themeColors.textMuted}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
              autoComplete="email"
              returnKeyType="done"
              onSubmitEditing={handleSave}
              style={[styles.input, { color: themeColors.textPrimary }]}
            />
            {newEmail.length > 0 && (
              <Pressable onPress={() => setNewEmail('')} hitSlop={8}>
                <Ionicons name="close-circle" size={18} color={themeColors.textMuted} />
              </Pressable>
            )}
          </View>
          {newEmail.length > 0 && !isValidEmail(newEmail) && (
            <Text style={[styles.errorMsg, { color: themeColors.danger }]}>
              Please enter a valid email address
            </Text>
          )}
        </View>

        {/* Info notice */}
        <View style={[styles.infoBox, { backgroundColor: themeColors.bgSecondary, borderLeftColor: themeColors.accentPrimary }]}>
          <Ionicons name="information-circle-outline" size={18} color={themeColors.accentPrimary} style={{ marginTop: 1 }} />
          <Text style={[styles.infoText, { color: themeColors.textSecondary }]}>
            A confirmation link will be sent to both your current and new email addresses. You must confirm both to complete the change.
          </Text>
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
              Send Confirmation
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
  currentEmailBox: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.lg,
    borderRadius: 12,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm + 2,
    minHeight: 50,
  },
  emailIcon: {
    marginRight: spacing.sm,
  },
  currentEmailText: {
    ...typography.body,
    flex: 1,
  },
  inputGroup: {
    marginHorizontal: spacing.lg,
    borderRadius: 12,
    overflow: 'hidden',
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
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
  errorMsg: {
    ...typography.bodySmall,
    marginTop: spacing.xs,
    marginHorizontal: spacing.sm,
    marginBottom: spacing.xs,
  },
  infoBox: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    padding: spacing.md,
    borderRadius: 12,
    borderLeftWidth: 3,
  },
  infoText: {
    ...typography.bodySmall,
    flex: 1,
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
