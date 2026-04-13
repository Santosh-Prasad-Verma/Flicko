/**
 * Register Screen — Discord-inspired
 *
 * Flicko logo at top, "Create an account" heading, dark form with blurple accent.
 */
import React, { useCallback, useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Pressable,
} from 'react-native';
import { Image } from 'expo-image';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { spacing, borderRadius } from '../../constants/Colors';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { validateEmail, validatePassword, validateUsername } from '@utils/validation.utils';
import { supabase } from '../../services/supabase';
import { useAuthStore } from '@stores/authStore';
import { sendWelcomeEmail } from '../../services/mail.service';
import { useTheme } from '../../hooks/useTheme';
import { loginWithOAuth, type OAuthProvider } from '../../services/oauth.service';
import { Ionicons } from '@expo/vector-icons';

export default function RegisterScreen() {
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [emailError, setEmailError] = useState('');
  const [usernameError, setUsernameError] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [confirmError, setConfirmError] = useState('');
  const [generalError, setGeneralError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [tosAccepted, setTosAccepted] = useState(false);
  const [tosError, setTosError] = useState('');
  const [checkingUsername, setCheckingUsername] = useState(false);
  const [showResend, setShowResend] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [resendMessage, setResendMessage] = useState('');
  const [oauthLoading, setOauthLoading] = useState<OAuthProvider | null>(null);
  const usernameCheckTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const { setUser, setSession, setIsAuthenticated } = useAuthStore();
  const { themeColors, theme } = useTheme();
  const insets = useSafeAreaInsets();

  /** Check if username is already taken */
  const checkUsernameAvailability = useCallback(
    async (name: string) => {
      if (!name || name.length < 2) return;
      setCheckingUsername(true);
      try {
        const { data, error } = await supabase
          .from('profiles')
          .select('id')
          .ilike('username', name)
          .limit(1);
        if (!error && data && data.length > 0) {
          setUsernameError('Username is already taken');
        }
      } catch {
        // silently ignore network errors during check
      } finally {
        setCheckingUsername(false);
      }
    },
    [],
  );

  /** Debounce username check as user types */
  const handleUsernameChange = useCallback(
    (v: string) => {
      setUsername(v);
      setUsernameError('');
      if (usernameCheckTimer.current) clearTimeout(usernameCheckTimer.current);
      const trimmed = v.trim();
      if (trimmed.length >= 2 && validateUsername(trimmed)) {
        usernameCheckTimer.current = setTimeout(() => {
          checkUsernameAvailability(trimmed);
        }, 500);
      }
    },
    [checkUsernameAvailability],
  );

  // Cleanup timer on unmount
  useEffect(() => {
    return () => {
      if (usernameCheckTimer.current) clearTimeout(usernameCheckTimer.current);
    };
  }, []);

  const validate = useCallback((): boolean => {
    let valid = true;
    setEmailError('');
    setUsernameError('');
    setPasswordError('');
    setConfirmError('');
    setGeneralError('');
    setSuccessMessage('');
    setTosError('');

    const trimmedEmail = email.trim();
    if (!trimmedEmail) {
      setEmailError('Email is required');
      valid = false;
    } else if (!validateEmail(trimmedEmail)) {
      setEmailError('Enter a valid email address');
      valid = false;
    }

    const trimmedUsername = username.trim();
    if (!trimmedUsername) {
      setUsernameError('Username is required');
      valid = false;
    } else if (!validateUsername(trimmedUsername)) {
      setUsernameError('2-32 chars: letters, numbers, _ . -');
      valid = false;
    }

    if (!password) {
      setPasswordError('Password is required');
      valid = false;
    } else if (password.length < 8) {
      setPasswordError('Password must be at least 8 characters');
      valid = false;
    } else if (!/[A-Z]/.test(password)) {
      setPasswordError('Password needs at least one uppercase letter');
      valid = false;
    } else if (!/[a-z]/.test(password)) {
      setPasswordError('Password needs at least one lowercase letter');
      valid = false;
    } else if (!/\d/.test(password)) {
      setPasswordError('Password needs at least one number');
      valid = false;
    } else if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
      setPasswordError('Password needs at least one special character (!@#$%...)');
      valid = false;
    } else if (/(.)\1{2,}/.test(password)) {
      setPasswordError('Password must not have 3+ repeated characters in a row');
      valid = false;
    } else if (!validatePassword(password)) {
      setPasswordError('Password is too common or contains keyboard patterns');
      valid = false;
    }

    if (!confirmPassword) {
      setConfirmError('Please confirm your password');
      valid = false;
    } else if (password !== confirmPassword) {
      setConfirmError('Passwords do not match');
      valid = false;
    }

    if (!tosAccepted) {
      setTosError('You must accept the Terms of Service and Privacy Policy');
      valid = false;
    }

    return valid;
  }, [email, username, password, confirmPassword, tosAccepted]);

  const handleResend = useCallback(async () => {
    if (!email) return;
    setResendLoading(true);
    setResendMessage('');
    try {
      const { error } = await supabase.auth.resend({
        type: 'signup',
        email: email.trim().toLowerCase(),
      });
      if (error) {
        setResendMessage('Could not resend — try again in a minute.');
      } else {
        setResendMessage('Confirmation email sent! Check your inbox and spam folder.');
      }
    } catch {
      setResendMessage('Could not resend — try again in a minute.');
    } finally {
      setResendLoading(false);
    }
  }, [email]);

  const handleRegister = useCallback(async () => {
    if (!validate()) return;

    setLoading(true);
    setGeneralError('');
    setSuccessMessage('');

    try {
      // Final server-side username uniqueness check
      const trimmedUsername = username.trim();
      const { data: existing } = await supabase
        .from('profiles')
        .select('id')
        .ilike('username', trimmedUsername)
        .limit(1);
      if (existing && existing.length > 0) {
        setUsernameError('Username is already taken');
        setLoading(false);
        return;
      }

      // HIGH-002: Sanitize and validate inputs
      const sanitizedEmail = email.trim().toLowerCase();
      const sanitizedUsername = username.trim().replace(/[^\w.-]/g, '');
      const sanitizedDisplayName = username.trim()
        .replace(/[<>"'&]/g, '') // Remove XSS chars
        .substring(0, 32); // Enforce max length

      if (sanitizedUsername !== username.trim()) {
        setUsernameError('Username contains invalid characters (only letters, numbers, _ . - allowed)');
        setLoading(false);
        return;
      }

      const { data, error } = await supabase.auth.signUp({
        email: sanitizedEmail,
        password,
        options: {
          data: {
            username: sanitizedUsername,
            display_name: sanitizedDisplayName,
          },
        },
      });

      if (error) {
        // Supabase returns this when email confirmation is enabled but SMTP
        // isn't configured — the account IS created, just the email failed.
        const isEmailDeliveryError = /confirm|email/i.test(error.message);
        if (isEmailDeliveryError) {
          // Try auto sign-in since the account was created
          const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
            email: email.trim().toLowerCase(),
            password,
          });
          if (!signInError && signInData.session && signInData.user) {
            setSession(signInData.session);
            setUser(signInData.user as any);
            setIsAuthenticated(true);
            sendWelcomeEmail(email.trim().toLowerCase(), username.trim());
            router.replace('/(tabs)');
            return;
          }
          // Auto sign-in failed — email confirmation is truly required
          sendWelcomeEmail(email.trim().toLowerCase(), username.trim());
          setShowResend(true);
          setSuccessMessage('Account created! A confirmation link has been sent to your email. Check your spam folder too.');
          return;
        }
        setGeneralError(error.message);
        return;
      }

      if (data.session && data.user) {
        setSession(data.session);
        setUser(data.user as any);
        setIsAuthenticated(true);
        sendWelcomeEmail(email.trim().toLowerCase(), username.trim());
        router.replace('/(tabs)');
      } else {
        sendWelcomeEmail(email.trim().toLowerCase(), username.trim());
        setShowResend(true);
        setSuccessMessage('Account created! A confirmation link has been sent to your email. Check your spam folder too.');
      }
    } catch (err: any) {
      setGeneralError(err.message || 'An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  }, [email, username, password, validate, setSession, setUser, setIsAuthenticated]);

  const handleOAuth = useCallback(async (provider: OAuthProvider) => {
    setOauthLoading(provider);
    setGeneralError('');
    try {
      const result = await loginWithOAuth(provider);
      if (result.success) {
        const { data: { session, user } } = await supabase.auth.getSession();
        if (session && user) {
          setSession(session);
          setUser(user as any);
          setIsAuthenticated(true);
          router.replace('/(tabs)');
        }
      } else if (result.error && result.error !== 'Authentication was cancelled') {
        setGeneralError(result.error);
      }
    } catch {
      setGeneralError('OAuth sign-up failed. Please try again.');
    } finally {
      setOauthLoading(null);
    }
  }, [setSession, setUser, setIsAuthenticated]);

  return (
    <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
      <KeyboardAvoidingView
        style={{ flex: 1 }}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <ScrollView
          contentContainerStyle={[
            styles.scrollContent,
            { paddingTop: insets.top + 24, paddingBottom: insets.bottom + 30 },
          ]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {/* Back button */}
          <Pressable
            onPress={() => router.back()}
            hitSlop={12}
            style={styles.backBtn}
            accessibilityLabel="Go back"
          >
            <Text style={[styles.backText, { color: themeColors.textSecondary }]}>{'< Back'}</Text>
          </Pressable>

          {/* Logo + Brand */}
          <View style={styles.logoRow}>
            <Image
              source={require('../../assets/Flicko_icon.png')}
              style={styles.logo}
              contentFit="contain"
              transition={300}
              cachePolicy="none"
            />
            <Text style={[styles.brandName, { color: themeColors.textPrimary }]}>Flicko</Text>
          </View>

          {/* Header */}
          <View style={styles.header}>
            <Text style={[styles.title, { color: themeColors.textPrimary }]}>
              Create an account
            </Text>
          </View>

          {/* Form */}
          <View style={styles.form}>
            {successMessage ? (
              <View style={[styles.infoBanner, { backgroundColor: themeColors.success + '20' }]}>
                <Text style={[styles.infoBannerText, { color: themeColors.success }]}>
                  {successMessage}
                </Text>
                {showResend ? (
                  <>
                    {resendMessage ? (
                      <Text style={[styles.resendFeedback, { color: themeColors.success }]}>
                        {resendMessage}
                      </Text>
                    ) : null}
                    <Pressable
                      onPress={handleResend}
                      disabled={resendLoading}
                      style={styles.resendBtn}
                    >
                      <Text style={[styles.resendBtnText, { color: themeColors.accentPrimary }]}>
                        {resendLoading ? 'Sending...' : 'Resend confirmation email'}
                      </Text>
                    </Pressable>
                  </>
                ) : null}
              </View>
            ) : null}

            {generalError ? (
              <View style={[styles.errorBanner, { backgroundColor: themeColors.danger + '18' }]}>
                <Text style={[styles.errorBannerText, { color: themeColors.danger }]}>
                  {generalError}
                </Text>
              </View>
            ) : null}

            <Input
              label="EMAIL"
              placeholder="Enter your email address"
              value={email}
              onChangeText={(v: string) => { setEmail(v); setEmailError(''); }}
              error={emailError}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
              autoComplete="email"
              textContentType="emailAddress"
              returnKeyType="next"
              theme={theme}
            />

            <Input
              label="USERNAME"
              placeholder="Choose a username"
              value={username}
              onChangeText={handleUsernameChange}
              error={usernameError}
              hint={checkingUsername ? 'Checking availability...' : ''}
              autoCapitalize="none"
              autoCorrect={false}
              autoComplete="username-new"
              textContentType="username"
              returnKeyType="next"
              theme={theme}
            />

            <Input
              label="PASSWORD"
              placeholder="Create a password"
              value={password}
              onChangeText={(v: string) => { setPassword(v); setPasswordError(''); }}
              error={passwordError}
              isPassword
              autoCapitalize="none"
              autoComplete="password-new"
              textContentType="newPassword"
              returnKeyType="next"
              theme={theme}
            />

            <Input
              label="CONFIRM PASSWORD"
              placeholder="Confirm your password"
              value={confirmPassword}
              onChangeText={(v: string) => { setConfirmPassword(v); setConfirmError(''); }}
              error={confirmError}
              isPassword
              autoCapitalize="none"
              autoComplete="password-new"
              textContentType="newPassword"
              returnKeyType="done"
              onSubmitEditing={handleRegister}
              theme={theme}
            />

            <View style={styles.tosRow}>
              <Pressable
                onPress={() => { setTosAccepted(v => !v); setTosError(''); }}
                accessibilityRole="checkbox"
                accessibilityState={{ checked: tosAccepted }}
                accessibilityLabel="Accept Terms of Service and Privacy Policy"
                hitSlop={6}
              >
                <View style={[
                  styles.checkbox,
                  tosAccepted && { backgroundColor: themeColors.accentPrimary, borderColor: themeColors.accentPrimary },
                  !!tosError && { borderColor: themeColors.danger },
                ]}>
                  {tosAccepted && (
                    <Text style={styles.checkmark}>✓</Text>
                  )}
                </View>
              </Pressable>
              <Text style={[styles.tosLabel, { color: themeColors.textMuted }]}>
                I agree to Flicko's{' '}
                <Text style={{ color: themeColors.accentPrimary, fontFamily: 'gg-sans-medium' }}>Terms of Service</Text>
                {' '}and{' '}
                <Text style={{ color: themeColors.accentPrimary, fontFamily: 'gg-sans-medium' }}>Privacy Policy</Text>
              </Text>
            </View>
            {tosError ? (
              <Text style={[styles.tosError, { color: themeColors.danger }]}>{tosError}</Text>
            ) : null}

            <Button
              title="Continue"
              onPress={handleRegister}
              loading={loading}
              disabled={loading}
              fullWidth
              theme={theme}
              accessibilityHint="Create a new account"
            />

            {/* OAuth Divider */}
            <View style={styles.oauthDivider}>
              <View style={[styles.dividerLine, { backgroundColor: themeColors.border }]} />
              <Text style={[styles.dividerText, { color: themeColors.textMuted }]}>OR</Text>
              <View style={[styles.dividerLine, { backgroundColor: themeColors.border }]} />
            </View>

            {/* OAuth Buttons */}
            <Pressable
              style={[styles.oauthButton, { backgroundColor: themeColors.bgSecondary }]}
              onPress={() => handleOAuth('google')}
              disabled={!!oauthLoading}
            >
              <Ionicons name="logo-google" size={20} color={themeColors.textPrimary} />
              <Text style={[styles.oauthButtonText, { color: themeColors.textPrimary }]}>
                {oauthLoading === 'google' ? 'Signing up...' : 'Continue with Google'}
              </Text>
            </Pressable>

            <Pressable
              style={[styles.oauthButton, { backgroundColor: themeColors.bgSecondary }]}
              onPress={() => handleOAuth('discord')}
              disabled={!!oauthLoading}
            >
              <Ionicons name="logo-discord" size={20} color="#5865F2" />
              <Text style={[styles.oauthButtonText, { color: themeColors.textPrimary }]}>
                {oauthLoading === 'discord' ? 'Signing up...' : 'Continue with Discord'}
              </Text>
            </Pressable>

            <Pressable
              style={[styles.oauthButton, { backgroundColor: themeColors.bgSecondary }]}
              onPress={() => handleOAuth('github')}
              disabled={!!oauthLoading}
            >
              <Ionicons name="logo-github" size={20} color={themeColors.textPrimary} />
              <Text style={[styles.oauthButtonText, { color: themeColors.textPrimary }]}>
                {oauthLoading === 'github' ? 'Signing up...' : 'Continue with GitHub'}
              </Text>
            </Pressable>

            <View style={styles.footer}>
              <Pressable onPress={() => router.back()} hitSlop={8}>
                <Text style={[styles.loginLink, { color: themeColors.accentPrimary }]}>
                  Already have an account?
                </Text>
              </Pressable>
            </View>
          </View>
        </ScrollView>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
    paddingHorizontal: 28,
  },
  backBtn: {
    alignSelf: 'flex-start',
    marginBottom: 12,
    paddingVertical: 4,
  },
  backText: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
  },
  logoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
    gap: 10,
    overflow: 'visible',
  },
  logo: {
    width: 48,
    height: 48,
    borderRadius: 14,
  },
  brandName: {
    fontSize: 28,
    fontFamily: 'Pacifico_400Regular',
    letterSpacing: 0.5,
    lineHeight: 44,
    includeFontPadding: false,
  },
  header: {
    alignItems: 'center',
    marginBottom: 20,
  },
  title: {
    fontSize: 25,
    fontFamily: 'gg-sans-bold',
    textAlign: 'center',
    letterSpacing: -0.3,
  },
  form: {
    width: '100%',
  },
  infoBanner: {
    borderRadius: 8,
    padding: spacing.md,
    marginBottom: spacing.lg,
    gap: 8,
  },
  infoBannerText: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
    textAlign: 'center',
  },
  resendFeedback: {
    fontSize: 12,
    fontFamily: 'gg-sans',
    textAlign: 'center',
  },
  resendBtn: {
    alignSelf: 'center',
    paddingVertical: 4,
    paddingHorizontal: 8,
  },
  resendBtnText: {
    fontSize: 13,
    fontFamily: 'gg-sans-semibold',
    textDecorationLine: 'underline',
  },
  errorBanner: {
    borderRadius: 8,
    padding: spacing.md,
    marginBottom: spacing.lg,
  },
  errorBannerText: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
    textAlign: 'center',
  },
  tosRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 8,
    gap: 10,
  },
  checkbox: {
    width: 20,
    height: 20,
    borderRadius: 5,
    borderWidth: 2,
    borderColor: '#72767d',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 1,
    flexShrink: 0,
  },
  checkmark: {
    color: '#ffffff',
    fontSize: 13,
    fontFamily: 'gg-sans-bold',
    lineHeight: 16,
    includeFontPadding: false,
  },
  tosLabel: {
    flex: 1,
    fontSize: 12,
    fontFamily: 'gg-sans',
    lineHeight: 18,
  },
  tosError: {
    fontSize: 11,
    fontFamily: 'gg-sans',
    marginBottom: 12,
    marginTop: -4,
  },
  footer: {
    alignItems: 'center',
    marginTop: 16,
  },
  loginLink: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  oauthDivider: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 20,
    gap: 12,
  },
  dividerLine: {
    flex: 1,
    height: 1,
  },
  dividerText: {
    fontSize: 12,
    fontFamily: 'gg-sans-semibold',
    letterSpacing: 1,
  },
  oauthButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 8,
    marginBottom: 10,
    gap: 10,
  },
  oauthButtonText: {
    fontSize: 15,
    fontFamily: 'gg-sans-medium',
  },
});
