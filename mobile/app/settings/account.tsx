/**
 * My Account Settings Screen
 *
 * Mirrors web UserSettingsModal "My Account" tab.
 * Shows profile card with banner, avatar, email, username fields.
 * Route: /settings/account
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  Alert,
  TextInput,
  Modal,
  FlatList,
} from 'react-native';
import { Image } from 'expo-image';
import { router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useQuery } from '@tanstack/react-query';
import { useAuthStore } from '@stores/authStore';
import type { AuthStore } from '@stores/authStore';
import { supabase } from '../../services/supabase';
import { Avatar } from '../../components/ui/Avatar';
import { Button } from '../../components/ui/Button';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';
import { COUNTRIES } from '../../constants/countries';

export default function AccountSettingsScreen() {
  const insets = useSafeAreaInsets();
  const { themeColors } = useTheme();
  const user = useAuthStore((s: AuthStore) => s.user);
  const setUser = useAuthStore((s: AuthStore) => s.setUser);
  const [phoneEditing, setPhoneEditing] = useState(false);
  const [phoneNumber, setPhoneNumber] = useState(user?.phone || '');
  const [selectedCountry, setSelectedCountry] = useState(COUNTRIES[0]);
  const [showCountryPicker, setShowCountryPicker] = useState(false);
  const [countrySearch, setCountrySearch] = useState('');

  // Fetch full profile for banner
  const { data: profile } = useQuery({
    queryKey: ['profile', user?.id],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user!.id)
        .single();
      if (error) throw error;
      return data;
    },
    enabled: !!user?.id,
    staleTime: 0,
  });

  const displayName = profile?.display_name || user?.display_name || user?.username || 'User';
  const bannerUrl = profile?.banner || user?.banner;

  const filteredCountries = COUNTRIES.filter(country => 
    country.name.toLowerCase().includes(countrySearch.toLowerCase()) ||
    country.dial.includes(countrySearch)
  );

  const handleSavePhone = async () => {
    if (!user?.id) return;
    const fullNumber = `+${selectedCountry.dial}${phoneNumber.trim()}`;
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ phone: fullNumber, updated_at: new Date().toISOString() })
        .eq('id', user.id);
      if (error) throw error;
      if (user) setUser({ ...user, phone: fullNumber });
      setPhoneEditing(false);
      Alert.alert('Success', 'Phone number updated.');
    } catch (err: any) {
      Alert.alert('Error', err.message || 'Failed to update phone number');
    }
  };

  const handleDisableAccount = () => {
    Alert.alert(
      'Disable Account',
      'Are you sure you want to disable your account? You can re-enable it by logging in again.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Disable',
          style: 'destructive',
          onPress: async () => {
            if (!user?.id) return;
            try {
              await supabase.from('profiles').update({ disabled: true }).eq('id', user.id);
              await supabase.auth.signOut();
              router.replace('/(auth)/login' as any);
            } catch (err: any) {
              Alert.alert('Error', err.message || 'Failed to disable account');
            }
          },
        },
      ],
    );
  };

  const handleDeleteAccount = () => {
    Alert.alert(
      'Delete Account',
      'This action is PERMANENT and cannot be undone. All your data will be deleted. Are you absolutely sure?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete Forever',
          style: 'destructive',
          onPress: () => {
            // Second confirmation
            Alert.alert(
              'Final Confirmation',
              'Type DELETE to confirm account deletion.',
              [
                { text: 'Cancel', style: 'cancel' },
                {
                  text: 'I understand, delete',
                  style: 'destructive',
                  onPress: async () => {
                    if (!user?.id) return;
                    try {
                      // Mark for deletion — actual deletion handled by backend
                      await supabase.from('profiles').update({ deleted_at: new Date().toISOString() }).eq('id', user.id);
                      await supabase.auth.signOut();
                      router.replace('/(auth)/login' as any);
                    } catch (err: any) {
                      Alert.alert('Error', err.message || 'Failed to delete account');
                    }
                  },
                },
              ],
            );
          },
        },
      ],
    );
  };

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'My Account',
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
        }}
      />
      <ScrollView
        style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
        contentContainerStyle={{ paddingBottom: insets.bottom + spacing.xxl }}
      >
        {/* Profile Card */}
        <View style={[styles.profileCard, { backgroundColor: themeColors.bgSecondary }]}>
          <View style={styles.cardBanner}>
            {bannerUrl ? (
              <Image
                source={{ uri: bannerUrl }}
                style={StyleSheet.absoluteFillObject}
                contentFit="cover"
              />
            ) : (
              <LinearGradient
                colors={[themeColors.accentPrimary, themeColors.accentSecondary || themeColors.accentPrimary]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={StyleSheet.absoluteFillObject}
              />
            )}
          </View>
          <View style={styles.cardInfo}>
            <View style={[styles.avatarBorder, { backgroundColor: themeColors.bgSecondary }]}>
              <Avatar
                name={displayName}
                imageUrl={profile?.avatar || user?.avatar || undefined}
                size={72}
              />
            </View>
            <View style={styles.cardDetails}>
              <Text style={[styles.cardName, { color: themeColors.textPrimary }]}>
                {displayName}
              </Text>
              <Text style={[styles.cardTag, { color: themeColors.textSecondary }]}>
                @{user?.username}
              </Text>
            </View>
          </View>
          <Pressable
            style={[styles.editProfileBtn, { backgroundColor: themeColors.accentPrimary }]}
            onPress={() => router.push('/settings/edit-profile')}
          >
            <Text style={styles.editProfileText}>Edit Profile</Text>
          </Pressable>
        </View>

        {/* Account Information */}
        <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>ACCOUNT INFORMATION</Text>
        <View style={[styles.fieldGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <Pressable
            style={styles.fieldItem}
            onPress={() => router.push('/settings/change-email' as any)}
          >
            <View style={styles.fieldContent}>
              <Text style={[styles.fieldLabel, { color: themeColors.textSecondary }]}>Email</Text>
              <Text style={[styles.fieldValue, { color: themeColors.textPrimary }]} numberOfLines={1}>
                {user?.email || 'Not set'}
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={20} color={themeColors.textMuted} />
          </Pressable>

          <View style={[styles.fieldDivider, { backgroundColor: themeColors.border }]} />

          <Pressable
            style={styles.fieldItem}
            onPress={() => router.push('/settings/change-username' as any)}
          >
            <View style={styles.fieldContent}>
              <Text style={[styles.fieldLabel, { color: themeColors.textSecondary }]}>Username</Text>
              <Text style={[styles.fieldValue, { color: themeColors.textPrimary }]}>
                @{user?.username || 'Not set'}
              </Text>
            </View>
            <Ionicons name="chevron-forward" size={20} color={themeColors.textMuted} />
          </Pressable>

          <View style={[styles.fieldDivider, { backgroundColor: themeColors.border }]} />

          {phoneEditing ? (
            <View style={styles.phoneEditContainer}>
              <View style={styles.phoneInputRow}>
                <Pressable 
                  onPress={() => setShowCountryPicker(true)}
                  style={[styles.countryPickerBtn, { backgroundColor: themeColors.inputBg, borderColor: themeColors.border }]}
                >
                  <Text style={styles.flagEmoji}>{selectedCountry.flag}</Text>
                  <Text style={[styles.countryCodeText, { color: themeColors.textPrimary }]}>+{selectedCountry.dial}</Text>
                  <Ionicons name="chevron-down" size={14} color={themeColors.textMuted} />
                </Pressable>
                <TextInput
                  value={phoneNumber}
                  onChangeText={setPhoneNumber}
                  placeholder="234 567 8900"
                  placeholderTextColor={themeColors.textMuted}
                  keyboardType="phone-pad"
                  autoFocus
                  style={[styles.phoneInput, { color: themeColors.textPrimary, backgroundColor: themeColors.inputBg, borderColor: themeColors.border }]}
                />
                <Pressable 
                  onPress={handleSavePhone} 
                  style={[styles.iconBtn, { backgroundColor: themeColors.success }]}
                  hitSlop={8}
                >
                  <Ionicons name="checkmark" size={20} color="#fff" />
                </Pressable>
                <Pressable 
                  onPress={() => { setPhoneEditing(false); setPhoneNumber(user?.phone || ''); }} 
                  style={[styles.iconBtn, { backgroundColor: themeColors.danger }]}
                  hitSlop={8}
                >
                  <Ionicons name="close" size={20} color="#fff" />
                </Pressable>
              </View>
              <Text style={[styles.phoneHint, { color: themeColors.textMuted }]}>Tap flag to select country code</Text>
            </View>
          ) : (
            <Pressable
              style={styles.fieldItem}
              onPress={() => setPhoneEditing(true)}
            >
              <View style={styles.fieldContent}>
                <Text style={[styles.fieldLabel, { color: themeColors.textSecondary }]}>Phone Number</Text>
                <Text style={[styles.fieldValue, { color: user?.phone ? themeColors.textPrimary : themeColors.textMuted }]}>
                  {user?.phone || profile?.phone || 'Not added'}
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={20} color={themeColors.textMuted} />
            </Pressable>
          )}

          <View style={[styles.fieldDivider, { backgroundColor: themeColors.border }]} />

          <Pressable
            style={styles.fieldItem}
            onPress={() => router.push('/settings/change-password' as any)}
          >
            <View style={styles.fieldContent}>
              <Text style={[styles.fieldLabel, { color: themeColors.textSecondary }]}>Password</Text>
              <Text style={[styles.fieldValue, { color: themeColors.textPrimary }]}>••••••••</Text>
            </View>
            <Ionicons name="chevron-forward" size={20} color={themeColors.textMuted} />
          </Pressable>
        </View>

        {/* Danger Zone */}
        <Text style={[styles.sectionTitle, { color: themeColors.textMuted }]}>ACCOUNT MANAGEMENT</Text>
        <View style={[styles.fieldGroup, { backgroundColor: themeColors.bgSecondary }]}>
          <Pressable
            style={styles.fieldItem}
            onPress={handleDisableAccount}
          >
            <View style={styles.dangerContent}>
              <Ionicons name="pause-circle-outline" size={22} color={themeColors.warning} />
              <View style={styles.dangerTextContainer}>
                <Text style={[styles.dangerTitle, { color: themeColors.warning }]}>Disable Account</Text>
                <Text style={[styles.dangerSubtitle, { color: themeColors.textMuted }]}>Temporarily deactivate your account</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={themeColors.textMuted} />
          </Pressable>

          <View style={[styles.fieldDivider, { backgroundColor: themeColors.border }]} />

          <Pressable
            style={styles.fieldItem}
            onPress={handleDeleteAccount}
          >
            <View style={styles.dangerContent}>
              <Ionicons name="trash-outline" size={22} color={themeColors.danger} />
              <View style={styles.dangerTextContainer}>
                <Text style={[styles.dangerTitle, { color: themeColors.danger }]}>Delete Account</Text>
                <Text style={[styles.dangerSubtitle, { color: themeColors.textMuted }]}>Permanently delete your account and data</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={themeColors.textMuted} />
          </Pressable>
        </View>
      </ScrollView>

      {/* Country Picker Dropdown */}
      <Modal
        visible={showCountryPicker}
        transparent
        animationType="fade"
        onRequestClose={() => setShowCountryPicker(false)}
      >
        <Pressable 
          style={styles.modalOverlay}
          onPress={() => setShowCountryPicker(false)}
        >
          <View style={[styles.dropdownContainer, { backgroundColor: themeColors.bgSecondary }]}>
            <View style={styles.dropdownHeader}>
              <Text style={[styles.dropdownTitle, { color: themeColors.textPrimary }]}>Select Country</Text>
              <Pressable onPress={() => { setShowCountryPicker(false); setCountrySearch(''); }} hitSlop={8}>
                <Ionicons name="close" size={24} color={themeColors.textMuted} />
              </Pressable>
            </View>
            <View style={[styles.searchContainer, { backgroundColor: themeColors.inputBg }]}>
              <Ionicons name="search" size={18} color={themeColors.textMuted} />
              <TextInput
                value={countrySearch}
                onChangeText={setCountrySearch}
                placeholder="Search country..."
                placeholderTextColor={themeColors.textMuted}
                style={[styles.searchInput, { color: themeColors.textPrimary }]}
              />
              {countrySearch.length > 0 && (
                <Pressable onPress={() => setCountrySearch('')} hitSlop={8}>
                  <Ionicons name="close-circle" size={20} color={themeColors.textMuted} />
                </Pressable>
              )}
            </View>
            <FlatList
              data={filteredCountries}
              keyExtractor={(item) => item.code}
              renderItem={({ item }) => (
                <Pressable
                  style={[styles.countryItem, selectedCountry.code === item.code && { backgroundColor: themeColors.accentPrimary + '20' }]}
                  onPress={() => {
                    setSelectedCountry(item);
                    setShowCountryPicker(false);
                    setCountrySearch('');
                  }}
                >
                  <Text style={styles.countryFlag}>{item.flag}</Text>
                  <Text style={[styles.countryName, { color: themeColors.textPrimary }]}>{item.name}</Text>
                  <Text style={[styles.countryDial, { color: themeColors.textSecondary }]}>+{item.dial}</Text>
                </Pressable>
              )}
            />
          </View>
        </Pressable>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  profileCard: {
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    marginBottom: spacing.md,
    borderRadius: 16,
    overflow: 'hidden',
  },
  cardBanner: {
    height: 120,
    overflow: 'hidden',
  },
  cardInfo: {
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingTop: 0,
    paddingBottom: spacing.md,
  },
  avatarBorder: {
    marginTop: -36,
    borderRadius: 44,
    padding: 6,
  },
  cardDetails: {
    alignItems: 'center',
    marginTop: spacing.sm,
  },
  cardName: {
    ...typography.headingL,
    fontFamily: 'gg-sans-bold',
  },
  cardTag: {
    ...typography.body,
    marginTop: 2,
  },
  editProfileBtn: {
    marginTop: spacing.md,
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.sm + 2,
    borderRadius: 8,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  editProfileText: {
    color: '#FFFFFF',
    fontSize: 15,
    fontFamily: 'gg-sans-semibold',
  },
  sectionTitle: {
    ...typography.overline,
    fontSize: 11,
    marginHorizontal: spacing.lg,
    marginTop: spacing.lg,
    marginBottom: spacing.sm,
  },
  fieldGroup: {
    marginHorizontal: spacing.lg,
    borderRadius: 12,
    overflow: 'hidden',
  },
  fieldItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    minHeight: MINIMUM_TOUCH_TARGET + 8,
  },
  fieldContent: {
    flex: 1,
  },
  fieldLabel: {
    ...typography.bodySmall,
    marginBottom: 2,
  },
  fieldValue: {
    ...typography.body,
    fontFamily: 'gg-sans-medium',
  },
  fieldDivider: {
    height: StyleSheet.hairlineWidth,
    marginLeft: spacing.lg,
  },
  phoneEditContainer: {
    padding: spacing.lg,
  },
  phoneInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  countryPickerBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: spacing.xs + 2,
    height: 36,
    gap: 4,
    minWidth: 80,
  },
  flagEmoji: {
    fontSize: 18,
  },
  countryCodeText: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  phoneInput: {
    flex: 1,
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: spacing.sm + 2,
    paddingVertical: spacing.xs + 2,
    fontSize: 15,
    height: 36,
  },
  iconBtn: {
    width: 36,
    height: 36,
    borderRadius: 6,
    justifyContent: 'center',
    alignItems: 'center',
  },
  phoneHint: {
    ...typography.bodySmall,
    marginTop: spacing.xs,
    fontSize: 12,
  },
  dangerContent: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
  },
  dangerTextContainer: {
    flex: 1,
  },
  dangerTitle: {
    ...typography.body,
    fontFamily: 'gg-sans-semibold',
  },
  dangerSubtitle: {
    ...typography.bodySmall,
    marginTop: 2,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  dropdownContainer: {
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    maxHeight: '70%',
  },
  dropdownHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: spacing.lg,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#2A2C30',
  },
  dropdownTitle: {
    ...typography.headingM,
  },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: spacing.lg,
    marginBottom: spacing.sm,
    paddingHorizontal: spacing.md,
    height: 40,
    borderRadius: 8,
    gap: spacing.sm,
  },
  searchInput: {
    flex: 1,
    fontSize: 14,
    height: 40,
  },
  countryItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.lg,
    gap: spacing.md,
  },
  countryFlag: {
    fontSize: 24,
  },
  countryName: {
    flex: 1,
    ...typography.body,
  },
  countryDial: {
    ...typography.body,
  },
});
