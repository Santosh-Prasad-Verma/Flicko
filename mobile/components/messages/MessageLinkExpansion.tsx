/**
 * Message Link Expansion (Feature 37)
 *
 * Detects message links in content and renders an embedded quote
 * with the referenced message and a "Jump to Message" action.
 */
import React, { memo, useEffect, useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { supabase } from '@services/supabase';

// Matches links like: https://flicko.app/channels/SERVER_ID/CHANNEL_ID/MESSAGE_ID
// or internal formats: flicko://channels/SERVER_ID/CHANNEL_ID/MESSAGE_ID
const MESSAGE_LINK_RE = /(?:https?:\/\/(?:www\.)?flicko\.app|flicko:\/\/)\/channels\/([a-zA-Z0-9-]+)\/([a-zA-Z0-9-]+)\/([a-zA-Z0-9-]+)/g;

interface LinkedMessage {
  id: string;
  content: string;
  author_name: string;
  channel_name: string;
  created_at: string;
}

interface MessageLinkEmbedProps {
  messageLink: {
    serverId: string;
    channelId: string;
    messageId: string;
  };
  onJump?: (channelId: string, messageId: string) => void;
}

const MessageLinkEmbed = memo(function MessageLinkEmbed({
  messageLink,
  onJump,
}: MessageLinkEmbedProps) {
  const [data, setData] = useState<LinkedMessage | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data: msg, error: err } = await supabase
          .from('messages')
          .select('id, content, created_at, profiles:user_id(display_name, username), channels:channel_id(name)')
          .eq('id', messageLink.messageId)
          .single();

        if (err || !msg || cancelled) {
          if (!cancelled) setError(true);
          return;
        }

        const profile = msg.profiles as any;
        const channel = msg.channels as any;

        setData({
          id: msg.id,
          content: typeof msg.content === 'string' ? msg.content : '',
          author_name: profile?.display_name || profile?.username || 'Unknown',
          channel_name: channel?.name || 'unknown',
          created_at: msg.created_at,
        });
      } catch {
        if (!cancelled) setError(true);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => { cancelled = true; };
  }, [messageLink.messageId]);

  if (loading) {
    return (
      <View style={styles.embedContainer}>
        <View style={styles.accentBar} />
        <View style={styles.embedBody}>
          <Text style={styles.loadingText}>Loading message…</Text>
        </View>
      </View>
    );
  }

  if (error || !data) {
    return (
      <View style={styles.embedContainer}>
        <View style={[styles.accentBar, { backgroundColor: '#ED4245' }]} />
        <View style={styles.embedBody}>
          <Text style={styles.errorText}>Could not load message</Text>
        </View>
      </View>
    );
  }

  const time = new Date(data.created_at).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <TouchableOpacity
      style={styles.embedContainer}
      activeOpacity={0.7}
      onPress={() => onJump?.(messageLink.channelId, messageLink.messageId)}
    >
      <View style={styles.accentBar} />
      <View style={styles.embedBody}>
        <View style={styles.embedHeader}>
          <Text style={styles.channelName}>#{data.channel_name}</Text>
        </View>
        <View style={styles.authorRow}>
          <Text style={styles.authorName}>{data.author_name}</Text>
          <Text style={styles.timestamp}>{time}</Text>
        </View>
        <Text style={styles.contentText} numberOfLines={3}>
          {data.content}
        </Text>
        <Text style={styles.jumpLabel}>Click to jump to message</Text>
      </View>
    </TouchableOpacity>
  );
});

/**
 * Utility: extract all message link references from a string.
 */
export function extractMessageLinks(text: string) {
  const links: { serverId: string; channelId: string; messageId: string }[] = [];
  let match: RegExpExecArray | null;
  const re = new RegExp(MESSAGE_LINK_RE.source, 'g');
  while ((match = re.exec(text)) !== null) {
    links.push({
      serverId: match[1],
      channelId: match[2],
      messageId: match[3],
    });
  }
  return links;
}

interface MessageLinkExpansionProps {
  content: string;
  onJumpToMessage?: (channelId: string, messageId: string) => void;
}

/**
 * Renders embedded previews for all message links found in content.
 */
export const MessageLinkExpansion = memo(function MessageLinkExpansion({
  content,
  onJumpToMessage,
}: MessageLinkExpansionProps) {
  const links = extractMessageLinks(content);
  if (links.length === 0) return null;

  // Deduplicate by messageId
  const unique = links.filter(
    (l, i, arr) => arr.findIndex((a) => a.messageId === l.messageId) === i
  );

  return (
    <View style={styles.container}>
      {unique.map((link) => (
        <MessageLinkEmbed
          key={link.messageId}
          messageLink={link}
          onJump={onJumpToMessage}
        />
      ))}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    marginTop: 4,
    gap: 4,
  },
  embedContainer: {
    flexDirection: 'row',
    backgroundColor: '#2F3136',
    borderRadius: 8,
    overflow: 'hidden',
    marginTop: 4,
  },
  accentBar: {
    width: 4,
    backgroundColor: '#5865F2',
  },
  embedBody: {
    flex: 1,
    padding: 10,
  },
  embedHeader: {
    marginBottom: 2,
  },
  channelName: {
    color: '#96989D',
    fontSize: 11,
    fontFamily: 'GGSans-Medium',
  },
  authorRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 4,
  },
  authorName: {
    color: '#FFFFFF',
    fontSize: 13,
    fontFamily: 'GGSans-SemiBold',
  },
  timestamp: {
    color: '#72767D',
    fontSize: 11,
    fontFamily: 'GGSans-Regular',
  },
  contentText: {
    color: '#DCDDDE',
    fontSize: 13,
    fontFamily: 'GGSans-Regular',
    lineHeight: 18,
  },
  jumpLabel: {
    color: '#00AFF4',
    fontSize: 11,
    fontFamily: 'GGSans-Medium',
    marginTop: 6,
  },
  loadingText: {
    color: '#72767D',
    fontSize: 12,
    fontFamily: 'GGSans-Regular',
  },
  errorText: {
    color: '#ED4245',
    fontSize: 12,
    fontFamily: 'GGSans-Regular',
  },
});
