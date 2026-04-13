/**
 * Login Screen — Discord-inspired
 *
 * Flicko logo at top, "Welcome back!" heading, dark form with blurple accent.
 */
import React, { useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Pressable,
  Dimensions,
} from 'react-native';
import { Image } from 'expo-image';
import { router } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius } from '../../constants/Colors';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { validateEmail } from '@utils/validation.utils';
import { supabase } from '../../services/supabase';
import { useAuthStore } from '@stores/authStore';
import { useTheme } from '../../hooks/useTheme';
import { loginWithOAuth, type OAuthProvider } from '../../services/oauth.service';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [emailError, setEmailError] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [generalError, setGeneralError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showEmailNotConfirmed, setShowEmailNotConfirmed] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [resendMessage, setResendMessage] = useState('');
  const [oauthLoading, setOauthLoading] = useState<OAuthProvider | null>(null);

  const { setUser, setSession, setIsAuthenticated } = useAuthStore();
  const { themeColors, theme } = useTheme();
  const insets = useSafeAreaInsets();

  const validate = useCallback((): boolean => {
    let valid = true;
    setEmailError('');
    setPasswordError('');
    setGeneralError('');

    const trimmedEmail = email.trim();
    if (!trimmedEmail) {
      setEmailError('Email is required');
      valid = false;
    } else if (!validateEmail(trimmedEmail)) {
      setEmailError('Enter a valid email address');
      valid = false;
    }

    if (!password) {
      setPasswordError('Password is required');
      valid = false;
    } else if (password.length < 6) {
      setPasswordError('Password must be at least 6 characters');
      valid = false;
    }

    return valid;
  }, [email, password]);

  const handleLogin = useCallback(async () => {
    if (!validate()) return;

    setLoading(true);
    setGeneralError('');
    setShowEmailNotConfirmed(false);
    setResendMessage('');

    try {
      // CRIT-008: Sanitize inputs
      const sanitizedEmail = email.trim().toLowerCase();
      const sanitizedPassword = password.trim();

      // CRIT-008: Additional validation
      if (sanitizedEmail.length > 254) {
        setGeneralError('Email address too long');
        return;
      }

      if (sanitizedPassword.length > 128) {
        setGeneralError('Password too long');
        return;
      }

      // CRIT-008: Check for null bytes (potential injection)
      if (sanitizedEmail.includes('\0') || sanitizedPassword.includes('\0')) {
        setGeneralError('Invalid characters in credentials');
        return;
      }

      const { data, error } = await supabase.auth.signInWithPassword({
        email: sanitizedEmail,
        password: sanitizedPassword,
      });

      if (error) {
        // CRIT-008: Don't expose detailed error messages
        const isEmailNotConfirmed = /email.*not.*confirm|not.*confirm.*email|confirm.*email/i.test(error.message);
        if (isEmailNotConfirmed) {
          setShowEmailNotConfirmed(true);
          setGeneralError('Your email address has not been verified yet. Please check your inbox (and spam folder) for the verification link.');
        } else if (error.message.includes('Invalid login credentials')) {
          setGeneralError('Invalid email or password');
        } else {
          setGeneralError('Login failed. Please try again.');
        }
        return;
      }

      if (data.session && data.user) {
        setSession(data.session);
        setUser(data.user as any);
        setIsAuthenticated(true);
        router.replace('/(tabs)');
      }
    } catch (err: any) {
      console.error('Login error:', err);
      setGeneralError('An unexpected error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [email, password, validate, setSession, setUser, setIsAuthenticated]);

  const navigateToRegister = useCallback(() => {
    router.push('/register');
  }, []);

  const handleResendVerification = useCallback(async () => {
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
        setResendMessage('Verification email sent! Check your inbox and spam folder.');
      }
    } catch {
      setResendMessage('Could not resend — try again in a minute.');
    } finally {
      setResendLoading(false);
    }
  }, [email]);

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
      setGeneralError('OAuth sign-in failed. Please try again.');
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
            { paddingTop: insets.top + 40, paddingBottom: insets.bottom + 40 },
          ]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {/* Logo */}
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
              Welcome back!
            </Text>
            <Text style={[styles.subtitle, { color: themeColors.textSecondary }]}>
              We're so excited to see you again!
            </Text>
          </View>

          {/* Form */}
          <View style={styles.form}>
            {generalError ? (
              <View style={[styles.errorBanner, { backgroundColor: themeColors.danger + '18' }]}>
                <Text style={[styles.errorBannerText, { color: themeColors.danger }]}>
                  {generalError}
                </Text>
                {showEmailNotConfirmed ? (
                  <View style={styles.resendSection}>
                    <Pressable
                      onPress={handleResendVerification}
                      disabled={resendLoading}
                      hitSlop={8}
                    >
                      <Text style={[styles.resendLink, { color: themeColors.accentPrimary, opacity: resendLoading ? 0.5 : 1 }]}>
                        {resendLoading ? 'Sending...' : 'Resend verification email'}
                      </Text>
                    </Pressable>
                    {resendMessage ? (
                      <Text style={[styles.resendMessage, { color: themeColors.textSecondary }]}>
                        {resendMessage}
                      </Text>
                    ) : null}
                  </View>
                ) : null}
              </View>
            ) : null}

            <Input
              label="EMAIL"
              placeholder="Email or Phone Number"
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
              label="PASSWORD"
              placeholder="Password"
              value={password}
              onChangeText={(v: string) => { setPassword(v); setPasswordError(''); }}
              error={passwordError}
              isPassword
              autoCapitalize="none"
              autoComplete="password"
              textContentType="password"
              returnKeyType="done"
              onSubmitEditing={handleLogin}
              theme={theme}
            />

            <Pressable onPress={() => {}} hitSlop={8}>
              <Text style={[styles.forgotText, { color: themeColors.accentPrimary }]}>
                Forgot your password?
              </Text>
            </Pressable>

            <Button
              title="Log In"
              onPress={handleLogin}
              loading={loading}
              disabled={loading}
              fullWidth
              theme={theme}
              accessibilityHint="Sign in to your account"
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
                {oauthLoading === 'google' ? 'Signing in...' : 'Continue with Google'}
              </Text>
            </Pressable>

            <Pressable
              style={[styles.oauthButton, { backgroundColor: themeColors.bgSecondary }]}
              onPress={() => handleOAuth('discord')}
              disabled={!!oauthLoading}
            >
              <Ionicons name="logo-discord" size={20} color="#5865F2" />
              <Text style={[styles.oauthButtonText, { color: themeColors.textPrimary }]}>
                {oauthLoading === 'discord' ? 'Signing in...' : 'Continue with Discord'}
              </Text>
            </Pressable>

            <Pressable
              style={[styles.oauthButton, { backgroundColor: themeColors.bgSecondary }]}
              onPress={() => handleOAuth('github')}
              disabled={!!oauthLoading}
            >
              <Ionicons name="logo-github" size={20} color={themeColors.textPrimary} />
              <Text style={[styles.oauthButtonText, { color: themeColors.textPrimary }]}>
                {oauthLoading === 'github' ? 'Signing in...' : 'Continue with GitHub'}
              </Text>
            </Pressable>

            <View style={styles.footer}>
              <Text style={[styles.footerText, { color: themeColors.textMuted }]}>
                Need an account?{' '}
              </Text>
              <Pressable onPress={navigateToRegister} hitSlop={8}>
                <Text style={[styles.registerLink, { color: themeColors.accentPrimary }]}>
                  Register
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
    justifyContent: 'center',
    paddingHorizontal: 28,
  },
  logoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 16,
    gap: 10,
    overflow: 'visible',
  },
  logo: {
    width: 52,
    height: 52,
    borderRadius: 14,
  },
  iconPlaceholder: {
    width: 52,
    height: 52,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  brandName: {
    fontSize: 30,
    fontFamily: 'Pacifico_400Regular',
    letterSpacing: 0.5,
    lineHeight: 46,
    includeFontPadding: false,
  },
  header: {
    alignItems: 'center',
    marginBottom: 24,
  },
  title: {
    fontSize: 25,
    fontFamily: 'gg-sans-bold',
    marginBottom: 8,
    textAlign: 'center',
    letterSpacing: -0.3,
  },
  subtitle: {
    fontSize: 15,
    fontFamily: 'gg-sans',
    textAlign: 'center',
    lineHeight: 22,
  },
  form: {
    width: '100%',
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
  resendSection: {
    marginTop: 10,
    alignItems: 'center',
  },
  resendLink: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
    textDecorationLine: 'underline',
  },
  resendMessage: {
    fontSize: 12,
    fontFamily: 'gg-sans',
    marginTop: 6,
    textAlign: 'center',
  },
  forgotText: {
    fontSize: 13,
    fontFamily: 'gg-sans-medium',
    marginBottom: 20,
    marginTop: -8,
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 20,
  },
  footerText: {
    fontSize: 14,
    fontFamily: 'gg-sans',
  },
  registerLink: {
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
