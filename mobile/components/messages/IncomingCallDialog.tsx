import React from 'react';
import { View, Text, StyleSheet, Pressable, Modal } from 'react-native';
import { BlurView } from 'expo-blur';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useDMCallStore } from '@stores/dmCallStore';
import { answerCall, declineCall } from '@services/dmCallService';
import { useTheme } from '../../hooks/useTheme';
import { spacing, borderRadius, typography, MINIMUM_TOUCH_TARGET } from '../../constants/Colors';

export const IncomingCallDialog = () => {
  const { incomingCall } = useDMCallStore();
  const { themeColors } = useTheme();

  if (!incomingCall) return null;

  const handleAccept = () => {
    answerCall(incomingCall);
  };

  const handleDecline = () => {
    declineCall(incomingCall.id);
  };

  return (
    <Modal transparent animationType="fade" visible={!!incomingCall}>
      <BlurView intensity={80} tint="dark" style={styles.container}>
        <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
          <Image
            source={{ uri: incomingCall.callerProfile?.avatarUrl || 'https://via.placeholder.com/100' }}
            style={styles.avatar}
          />
          
          <Text style={[styles.title, { color: themeColors.textPrimary }]}>
            {incomingCall.callerProfile?.username || 'Someone'} is calling...
          </Text>
          <Text style={[styles.subtitle, { color: themeColors.textMuted }]}>
            Incoming {incomingCall.callType} call
          </Text>

          <View style={styles.buttonRow}>
            <Pressable
              onPress={handleDecline}
              style={[styles.button, styles.declineButton]}
            >
              <Ionicons name="close" size={28} color="#fff" />
            </Pressable>

            <Pressable
              onPress={handleAccept}
              style={[styles.button, styles.acceptButton]}
            >
              <Ionicons
                name={incomingCall.callType === 'video' ? 'videocam' : 'call'}
                size={28}
                color="#fff"
              />
            </Pressable>
          </View>
        </View>
      </BlurView>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  card: {
    width: '80%',
    padding: spacing.xl,
    borderRadius: borderRadius.lg,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
    elevation: 10,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    marginBottom: spacing.lg,
  },
  title: {
    ...typography.headingS,
    marginBottom: spacing.xs,
    textAlign: 'center',
  },
  subtitle: {
    ...typography.body,
    marginBottom: spacing.xxl,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: spacing.xxl,
  },
  button: {
    width: 60,
    height: 60,
    borderRadius: 30,
    justifyContent: 'center',
    alignItems: 'center',
    minWidth: MINIMUM_TOUCH_TARGET,
    minHeight: MINIMUM_TOUCH_TARGET,
  },
  acceptButton: {
    backgroundColor: '#23A559',
  },
  declineButton: {
    backgroundColor: '#F23F43',
  },
});
