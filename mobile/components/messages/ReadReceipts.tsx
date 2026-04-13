/**
 * DM Read Receipts (Feature 46)
 *
 * Shows read status indicators for direct messages:
 * - Single check → sent
 * - Double check → delivered
 * - Blue double check → read
 *
 * Also provides a store and service for tracking read status.
 */
import React, { memo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

export type ReadStatus = 'sending' | 'sent' | 'delivered' | 'read' | 'failed';

interface ReadReceiptProps {
  status: ReadStatus;
  timestamp?: string;
  showTimestamp?: boolean;
}

/**
 * Inline read receipt indicator for DM messages.
 */
export const ReadReceipt = memo(function ReadReceipt({
  status,
  timestamp,
  showTimestamp = false,
}: ReadReceiptProps) {
  const renderIcon = () => {
    switch (status) {
      case 'sending':
        return <Ionicons name="time-outline" size={14} color="#72767D" />;
      case 'sent':
        return <Ionicons name="checkmark" size={14} color="#72767D" />;
      case 'delivered':
        return <Ionicons name="checkmark-done" size={14} color="#72767D" />;
      case 'read':
        return <Ionicons name="checkmark-done" size={14} color="#5865F2" />;
      case 'failed':
        return <Ionicons name="alert-circle" size={14} color="#ED4245" />;
      default:
        return null;
    }
  };

  return (
    <View style={styles.container}>
      {renderIcon()}
      {showTimestamp && timestamp && (
        <Text style={styles.time}>{formatReceiptTime(timestamp)}</Text>
      )}
    </View>
  );
});

/**
 * "Seen by" indicator for group DMs — shows avatars of readers.
 */
interface SeenByIndicatorProps {
  readers: { id: string; username: string; avatar_url?: string | null }[];
  totalParticipants: number;
}

export const SeenByIndicator = memo(function SeenByIndicator({
  readers,
  totalParticipants,
}: SeenByIndicatorProps) {
  if (readers.length === 0) return null;

  const allRead = readers.length >= totalParticipants - 1; // -1 for self

  return (
    <View style={styles.seenByContainer}>
      <Ionicons
        name="eye-outline"
        size={12}
        color={allRead ? '#5865F2' : '#72767D'}
      />
      <Text style={[styles.seenByText, allRead && styles.seenByAll]}>
        {allRead
          ? 'Seen by everyone'
          : `Seen by ${readers.map((r) => r.username).join(', ')}`}
      </Text>
    </View>
  );
});

/**
 * Typing indicator with read receipt integration for DMs.
 */
interface TypingWithReceiptProps {
  isTyping: boolean;
  typingUser?: string;
  lastMessageStatus?: ReadStatus;
}

export const TypingWithReceipt = memo(function TypingWithReceipt({
  isTyping,
  typingUser,
  lastMessageStatus,
}: TypingWithReceiptProps) {
  if (isTyping && typingUser) {
    return (
      <View style={styles.typingContainer}>
        <View style={styles.typingDots}>
          <View style={[styles.typingDot, styles.typingDot1]} />
          <View style={[styles.typingDot, styles.typingDot2]} />
          <View style={[styles.typingDot, styles.typingDot3]} />
        </View>
        <Text style={styles.typingText}>
          {typingUser} is typing…
        </Text>
      </View>
    );
  }

  if (lastMessageStatus === 'read') {
    return (
      <View style={styles.typingContainer}>
        <Ionicons name="checkmark-done" size={12} color="#5865F2" />
        <Text style={[styles.typingText, { color: '#5865F2' }]}>Read</Text>
      </View>
    );
  }

  return null;
});

// ─── Helpers ────────────────────────────────────────────────────────────────

function formatReceiptTime(iso: string): string {
  const d = new Date(iso);
  const now = new Date();
  const diff = now.getTime() - d.getTime();

  if (diff < 60000) return 'Just now';
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;

  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

// ─── Read Receipt Store (Zustand integration) ──────────────────────────────

import { create } from 'zustand';
import { supabase } from '@services/supabase';

interface ReadReceiptState {
  /** Map: messageId → ReadStatus */
  statuses: Record<string, ReadStatus>;
  /** Map: messageId → reader user IDs */
  readers: Record<string, string[]>;
  /** Set message status */
  setStatus: (messageId: string, status: ReadStatus) => void;
  /** Mark message as read by a user */
  markRead: (messageId: string, userId: string) => void;
  /** Send read receipt to server */
  sendReadReceipt: (messageId: string, channelId: string, userId: string) => Promise<void>;
  /** Fetch read receipts for a channel */
  fetchReceipts: (channelId: string) => Promise<void>;
}

export const useReadReceiptStore = create<ReadReceiptState>((set, get) => ({
  statuses: {},
  readers: {},

  setStatus: (messageId, status) =>
    set((s) => ({
      statuses: { ...s.statuses, [messageId]: status },
    })),

  markRead: (messageId, userId) =>
    set((s) => ({
      readers: {
        ...s.readers,
        [messageId]: [...new Set([...(s.readers[messageId] || []), userId])],
      },
      statuses: { ...s.statuses, [messageId]: 'read' },
    })),

  sendReadReceipt: async (messageId, channelId, userId) => {
    try {
      const { data } = await supabase.auth.getSession();
      const token = data.session?.access_token;
      if (!token) return;

      const API_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:8080';
      await fetch(`${API_URL}/api/v1/channels/${channelId}/messages/${messageId}/read`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      // Best-effort update of local UI state
      get().markRead(messageId, userId);
    } catch {
      // Silently fail — receipt is best-effort
    }
  },

  fetchReceipts: async (channelId) => {
    try {
      const { data } = await supabase.auth.getSession();
      const token = data.session?.access_token;
      if (!token) return;
      
      const API_URL = process.env.EXPO_PUBLIC_API_URL || 'http://localhost:8080';
      
      // Fetch user's own read states to sync UI
      const res = await fetch(`${API_URL}/api/v1/users/@me/read_states`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      
      if (!res.ok) return;
      const json = await res.json();
      
      const states = json.read_states || [];
      const statuses: Record<string, ReadStatus> = {};
      
      // Iterate over the last_read mapping returned from Option A backend architecture
      for (const st of states) {
        if (st.channel_id === channelId && st.last_read_message_id) {
           statuses[st.last_read_message_id] = 'read';
           // If we've read msg 50, theoretically all before are read, but UI tracks distinct IDs 
           // here we just mark the specific ID for now to align with discord scaling.
        }
      }
      
      set((s) => ({
        statuses: { ...s.statuses, ...statuses },
      }));
    } catch {
      // Silently fail
    }
  },
}));

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    marginLeft: 4,
  },
  time: {
    color: '#72767D',
    fontSize: 10,
    fontFamily: 'GGSans-Regular',
  },
  seenByContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingVertical: 2,
    paddingHorizontal: 4,
  },
  seenByText: {
    color: '#72767D',
    fontSize: 11,
    fontFamily: 'GGSans-Regular',
  },
  seenByAll: {
    color: '#5865F2',
  },
  typingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 16,
    paddingVertical: 4,
  },
  typingDots: {
    flexDirection: 'row',
    gap: 3,
  },
  typingDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: '#72767D',
  },
  typingDot1: { opacity: 1 },
  typingDot2: { opacity: 0.7 },
  typingDot3: { opacity: 0.4 },
  typingText: {
    color: '#72767D',
    fontSize: 12,
    fontFamily: 'GGSans-Regular',
  },
});
