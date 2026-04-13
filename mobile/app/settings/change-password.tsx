/**
 * Change Password Screen
 *
 * Allows the authenticated user to update their password.
 * Uses Supabase Auth's updateUser() which works on the current session.
 * Route: /settings/change-password
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
import { supabase } from '../../services/supabase';
import { spacing, typography } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

const MIN_PASSWORD_LENGTH = 8;

export default function ChangePasswordScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showCurrent, setShowCurrent] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleSave = async () => {
    if (!currentPassword.trim()) {
      Alert.alert('Validation Error', 'Please enter your current password.');
      return;
    }
    if (newPassword.length < MIN_PASSWORD_LENGTH) {
      Alert.alert('Validation Error', `New password must be at least ${MIN_PASSWORD_LENGTH} characters.`);
      return;
    }
    if (newPassword !== confirmPassword) {
      Alert.alert('Validation Error', 'New passwords do not match.');
      return;
    }
    if (newPassword === currentPassword) {
      Alert.alert('Validation Error', 'New password must be different from your current password.');
      return;
    }

    setLoading(true);
    try {
      // Verify current password by re-authenticating
      const { data: sessionData } = await supabase.auth.getSession();
      const email = sessionData?.session?.user?.email;

      if (!email) {
        Alert.alert('Error', 'Unable to verify identity. Please log in again.');
        return;
      }

      const { error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password: currentPassword,
      });

      if (signInError) {
        Alert.alert('Incorrect Password', 'Your current password is incorrect.');
        return;
      }

      // Update to new password
      const { error: updateError } = await supabase.auth.updateUser({
        password: newPassword,
      });

      if (updateError) throw updateError;

      Alert.alert(
        'Password Updated',
        'Your password has been changed successfully.',
        [{ text: 'OK', onPress: () => router.back() }],
      );
    } catch (err: any) {
      Alert.alert('Error', err.message || 'Failed to update password. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const canSave =
    currentPassword.trim().length > 0 &&
    newPassword.length >= MIN_PASSWORD_LENGTH &&
    confirmPassword.length >= MIN_PASSWORD_LENGTH &&
    !loading;

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Change Password',
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
        <Text style={[styles.sectionHint, { color: themeColors.textMuted }]}>
          Your password must be at least {MIN_PASSWORD_LENGTH} characters.
        </Text>

        {/* Current Password */}
        <Text style={[styles.label, { color: themeColors.textMuted }]}>CURRENT PASSWORD</Text>
        <View style={[styles.inputGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <View style={[styles.inputRow, { borderColor: themeColors.border }]}>
            <TextInput
              value={currentPassword}
              onChangeText={setCurrentPassword}
              placeholder="Enter current password"
              placeholderTextColor={themeColors.textMuted}
              secureTextEntry={!showCurrent}
              autoCapitalize="none"
              autoCorrect={false}
              returnKeyType="next"
              style={[styles.input, { color: themeColors.textPrimary }]}
            />
            <Pressable onPress={() => setShowCurrent(v => !v)} hitSlop={8}>
              <Ionicons
                name={showCurrent ? 'eye-off-outline' : 'eye-outline'}
                size={20}
                color={themeColors.textMuted}
              />
            </Pressable>
          </View>
        </View>

        {/* New Password */}
        <Text style={[styles.label, { color: themeColors.textMuted }]}>NEW PASSWORD</Text>
        <View style={[styles.inputGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <View style={[styles.inputRow, { borderColor: themeColors.border }]}>
            <TextInput
              value={newPassword}
              onChangeText={setNewPassword}
              placeholder="Enter new password"
              placeholderTextColor={themeColors.textMuted}
              secureTextEntry={!showNew}
              autoCapitalize="none"
              autoCorrect={false}
              returnKeyType="next"
              style={[styles.input, { color: themeColors.textPrimary }]}
            />
            <Pressable onPress={() => setShowNew(v => !v)} hitSlop={8}>
              <Ionicons
                name={showNew ? 'eye-off-outline' : 'eye-outline'}
                size={20}
                color={themeColors.textMuted}
              />
            </Pressable>
          </View>
        </View>

        {/* Confirm New Password */}
        <Text style={[styles.label, { color: themeColors.textMuted }]}>CONFIRM NEW PASSWORD</Text>
        <View style={[styles.inputGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <View
            style={[
              styles.inputRow,
              {
                borderColor:
                  confirmPassword && confirmPassword !== newPassword
                    ? themeColors.danger
                    : themeColors.border,
              },
            ]}
          >
            <TextInput
              value={confirmPassword}
              onChangeText={setConfirmPassword}
              placeholder="Re-enter new password"
              placeholderTextColor={themeColors.textMuted}
              secureTextEntry={!showConfirm}
              autoCapitalize="none"
              autoCorrect={false}
              returnKeyType="done"
              onSubmitEditing={handleSave}
              style={[styles.input, { color: themeColors.textPrimary }]}
            />
            <Pressable onPress={() => setShowConfirm(v => !v)} hitSlop={8}>
              <Ionicons
                name={showConfirm ? 'eye-off-outline' : 'eye-outline'}
                size={20}
                color={themeColors.textMuted}
              />
            </Pressable>
          </View>
          {confirmPassword.length > 0 && confirmPassword !== newPassword && (
            <Text style={[styles.errorMsg, { color: themeColors.danger }]}>
              Passwords do not match
            </Text>
          )}
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
              Update Password
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
  sectionHint: {
    ...typography.bodySmall,
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    marginBottom: spacing.md,
  },
  label: {
    ...typography.overline,
    fontSize: 11,
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    marginBottom: spacing.xs,
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
