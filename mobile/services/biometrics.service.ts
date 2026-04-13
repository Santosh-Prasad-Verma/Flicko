/**
 * Biometric Authentication Service
 *
 * Wraps expo-local-authentication for Face ID, Touch ID, and Fingerprint.
 * Supports availability check, enrollment check, authentication with fallback,
 * and user preference persistence.
 *
 * Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9
 */
import * as LocalAuthentication from 'expo-local-authentication';
import * as SecureStore from 'expo-secure-store';

const BIOMETRIC_ENABLED_KEY = 'flicko_biometric_enabled';
const BIOMETRIC_FAIL_COUNT_KEY = 'flicko_biometric_fail_count';
const MAX_FAILED_ATTEMPTS = 3;

export type BiometricType = 'fingerprint' | 'facial' | 'iris' | 'none';

/**
 * Check if biometric hardware is available on the device.
 */
export async function isAvailable(): Promise<boolean> {
  const compatible = await LocalAuthentication.hasHardwareAsync();
  if (!compatible) return false;
  const enrolled = await LocalAuthentication.isEnrolledAsync();
  return enrolled;
}

/**
 * Get the type of biometric authentication available.
 */
export async function getBiometricType(): Promise<BiometricType> {
  const types = await LocalAuthentication.supportedAuthenticationTypesAsync();
  if (types.includes(LocalAuthentication.AuthenticationType.FACIAL_RECOGNITION)) {
    return 'facial';
  }
  if (types.includes(LocalAuthentication.AuthenticationType.FINGERPRINT)) {
    return 'fingerprint';
  }
  if (types.includes(LocalAuthentication.AuthenticationType.IRIS)) {
    return 'iris';
  }
  return 'none';
}

/**
 * Get a human-friendly label for the biometric type.
 */
export async function getBiometricLabel(): Promise<string> {
  const type = await getBiometricType();
  switch (type) {
    case 'facial':
      return 'Face ID';
    case 'fingerprint':
      return 'Fingerprint';
    case 'iris':
      return 'Iris';
    default:
      return 'Biometric';
  }
}

/**
 * Attempt biometric authentication.
 * Returns { success, error, shouldFallback }.
 * shouldFallback is true when the user has exceeded MAX_FAILED_ATTEMPTS.
 */
export async function authenticate(
  promptMessage = 'Authenticate to continue',
): Promise<{
  success: boolean;
  error?: string;
  shouldFallback: boolean;
}> {
  try {
    const available = await isAvailable();
    if (!available) {
      return { success: false, error: 'Biometrics not available', shouldFallback: true };
    }

    const failCountStr = await SecureStore.getItemAsync(BIOMETRIC_FAIL_COUNT_KEY);
    const failCount = failCountStr ? parseInt(failCountStr, 10) : 0;

    if (failCount >= MAX_FAILED_ATTEMPTS) {
      return {
        success: false,
        error: 'Too many failed attempts. Please use your password.',
        shouldFallback: true,
      };
    }

    const result = await LocalAuthentication.authenticateAsync({
      promptMessage,
      fallbackLabel: 'Use password',
      disableDeviceFallback: false,
      cancelLabel: 'Cancel',
    });

    if (result.success) {
      // Reset fail counter on success
      await SecureStore.setItemAsync(BIOMETRIC_FAIL_COUNT_KEY, '0');
      return { success: true, shouldFallback: false };
    }

    // Increment fail counter
    const newCount = failCount + 1;
    await SecureStore.setItemAsync(BIOMETRIC_FAIL_COUNT_KEY, String(newCount));

    return {
      success: false,
      error: result.error || 'Authentication failed',
      shouldFallback: newCount >= MAX_FAILED_ATTEMPTS,
    };
  } catch (err: any) {
    return {
      success: false,
      error: err.message || 'Biometric authentication error',
      shouldFallback: true,
    };
  }
}

/**
 * Check if the user has enabled biometric authentication.
 */
export async function isEnabled(): Promise<boolean> {
  const value = await SecureStore.getItemAsync(BIOMETRIC_ENABLED_KEY);
  return value === 'true';
}

/**
 * Enable or disable biometric authentication.
 */
export async function setEnabled(enabled: boolean): Promise<void> {
  await SecureStore.setItemAsync(BIOMETRIC_ENABLED_KEY, enabled ? 'true' : 'false');
  if (enabled) {
    // Reset fail counter when enabling
    await SecureStore.setItemAsync(BIOMETRIC_FAIL_COUNT_KEY, '0');
  }
}

/**
 * Reset the failed attempt counter.
 */
export async function resetFailCount(): Promise<void> {
  await SecureStore.setItemAsync(BIOMETRIC_FAIL_COUNT_KEY, '0');
}
