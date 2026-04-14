/**
 * QR Code Login (Feature 17)
 *
 * Allows scanning a QR code displayed on desktop/web to authenticate from mobile.
 * Flow:
 *  1. Desktop shows QR code with temp nonce
 *  2. Mobile scans → confirms identity → POST /api/v1/auth/qr-confirm
 *  3. Desktop receives session via WebSocket
 */
import React, { memo, useCallback, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import { supabase } from '@services/supabase';

interface Props {
  onClose: () => void;
  onSuccess?: () => void;
}

export const QRLoginScanner = memo(function QRLoginScanner({ onClose, onSuccess }: Props) {
  const { themeColors } = useTheme();
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [confirming, setConfirming] = useState(false);

  const handleBarCodeScanned = useCallback(
    async ({ data }: { data: string }) => {
      if (scanned || confirming) return;
      setScanned(true);

      // Expected format: flicko://qr-login?nonce=<NONCE>
      try {
        const url = new URL(data);
        const nonce = url.searchParams.get('nonce');
        if (!nonce) {
          Alert.alert('Invalid QR Code', 'This QR code is not a Flicko login code.');
          setScanned(false);
          return;
        }

        setConfirming(true);

        // Get current session token
        const { data: sessionData } = await supabase.auth.getSession();
        const token = sessionData?.session?.access_token;
        if (!token) {
          Alert.alert('Not Logged In', 'Please log in first before scanning.');
          setConfirming(false);
          setScanned(false);
          return;
        }

        // Confirm QR login
        const { error } = await supabase.functions.invoke('qr-confirm', {
          body: { nonce, user_token: token },
        });

        if (error) {
          Alert.alert('Login Failed', 'Could not confirm QR code login. Try again.');
          setScanned(false);
        } else {
          Alert.alert('Success!', 'Desktop is now logged in.', [
            { text: 'OK', onPress: onSuccess },
          ]);
        }
      } catch {
        Alert.alert('Error', 'Invalid QR code format.');
        setScanned(false);
      } finally {
        setConfirming(false);
      }
    },
    [scanned, confirming, onSuccess]
  );

  if (!permission) {
    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <ActivityIndicator color={themeColors.accentPrimary} />
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <Ionicons name="camera-outline" size={48} color={themeColors.textMuted} />
        <Text style={[styles.permText, { color: themeColors.textPrimary }]}>
          Camera permission is required to scan QR codes
        </Text>
        <Pressable
          style={[styles.permButton, { backgroundColor: themeColors.accentPrimary }]}
          onPress={requestPermission}
        >
          <Text style={styles.permButtonText}>Grant Permission</Text>
        </Pressable>
        <Pressable style={styles.closeBtn} onPress={onClose}>
          <Text style={[styles.closeBtnText, { color: themeColors.textMuted }]}>Cancel</Text>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.scannerContainer}>
      <CameraView
        style={StyleSheet.absoluteFillObject}
        barcodeScannerSettings={{ barcodeTypes: ['qr'] }}
        onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
      />

      {/* Overlay */}
      <View style={styles.overlay}>
        <Pressable style={styles.closeIcon} onPress={onClose}>
          <Ionicons name="close" size={28} color="#fff" />
        </Pressable>

        <View style={styles.frame}>
          <View style={[styles.corner, styles.tl]} />
          <View style={[styles.corner, styles.tr]} />
          <View style={[styles.corner, styles.bl]} />
          <View style={[styles.corner, styles.br]} />
        </View>

        <Text style={styles.scanText}>
          {confirming
            ? 'Confirming login...'
            : 'Point your camera at the QR code on your desktop'}
        </Text>

        {confirming && (
          <ActivityIndicator color="#fff" style={{ marginTop: spacing.sm }} />
        )}
      </View>
    </View>
  );
});

const FRAME_SIZE = 240;
const CORNER_SIZE = 30;
const CORNER_WIDTH = 4;

const cornerBase = {
  position: 'absolute' as const,
  width: CORNER_SIZE,
  height: CORNER_SIZE,
  borderColor: '#fff',
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.lg,
    gap: spacing.md,
  },
  permText: {
    ...typography.body,
    textAlign: 'center',
    marginTop: spacing.sm,
  },
  permButton: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    marginTop: spacing.md,
  },
  permButtonText: {
    color: '#fff',
    fontFamily: 'gg-sans-bold',
    fontSize: 15,
  },
  closeBtn: { marginTop: spacing.sm },
  closeBtnText: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  scannerContainer: { flex: 1, backgroundColor: '#000' },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  closeIcon: {
    position: 'absolute',
    top: 60,
    right: 20,
    zIndex: 10,
  },
  frame: {
    width: FRAME_SIZE,
    height: FRAME_SIZE,
  },
  corner: { ...cornerBase },
  tl: {
    top: 0,
    left: 0,
    borderTopWidth: CORNER_WIDTH,
    borderLeftWidth: CORNER_WIDTH,
  },
  tr: {
    top: 0,
    right: 0,
    borderTopWidth: CORNER_WIDTH,
    borderRightWidth: CORNER_WIDTH,
  },
  bl: {
    bottom: 0,
    left: 0,
    borderBottomWidth: CORNER_WIDTH,
    borderLeftWidth: CORNER_WIDTH,
  },
  br: {
    bottom: 0,
    right: 0,
    borderBottomWidth: CORNER_WIDTH,
    borderRightWidth: CORNER_WIDTH,
  },
  scanText: {
    color: '#fff',
    fontFamily: 'gg-sans-medium',
    fontSize: 15,
    textAlign: 'center',
    marginTop: spacing.md,
    paddingHorizontal: spacing.lg,
  },
});
