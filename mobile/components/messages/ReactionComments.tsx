/**
 * Reaction Comments (Feature 42)
 *
 * Allows users to leave short comments on specific reactions.
 * Shows a bottom sheet with the reaction emoji, who reacted, and threaded comments.
 */
import React, { memo, useCallback, useEffect, useState, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  FlatList,
  TextInput,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { supabase } from '@services/supabase';

interface ReactionUser {
  id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
}

interface ReactionComment {
  id: string;
  user_id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
  content: string;
  created_at: string;
}

interface ReactionCommentsProps {
  messageId: string;
  emoji: string;
  currentUserId: string;
  onClose?: () => void;
}

export const ReactionComments = memo(function ReactionComments({
  messageId,
  emoji,
  currentUserId,
  onClose,
}: ReactionCommentsProps) {
  const [users, setUsers] = useState<ReactionUser[]>([]);
  const [comments, setComments] = useState<ReactionComment[]>([]);
  const [commentText, setCommentText] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const inputRef = useRef<TextInput>(null);

  useEffect(() => {
    fetchData();
  }, [messageId, emoji]);

  const fetchData = async () => {
    setLoading(true);
    try {
      // Fetch users who reacted
      const { data: reactions } = await supabase
        .from('reactions')
        .select('user_id, profiles:user_id(id, username, display_name, avatar_url)')
        .eq('message_id', messageId)
        .eq('emoji', emoji);

      if (reactions) {
        setUsers(
          reactions.map((r: any) => ({
            id: r.profiles?.id || r.user_id,
            username: r.profiles?.username || 'Unknown',
            display_name: r.profiles?.display_name || null,
            avatar_url: r.profiles?.avatar_url || null,
          }))
        );
      }

      // Fetch reaction comments
      const { data: cmts } = await supabase
        .from('reaction_comments')
        .select('id, user_id, content, created_at, profiles:user_id(username, display_name, avatar_url)')
        .eq('message_id', messageId)
        .eq('emoji', emoji)
        .order('created_at', { ascending: true });

      if (cmts) {
        setComments(
          cmts.map((c: any) => ({
            id: c.id,
            user_id: c.user_id,
            username: c.profiles?.username || 'Unknown',
            display_name: c.profiles?.display_name || null,
            avatar_url: c.profiles?.avatar_url || null,
            content: c.content,
            created_at: c.created_at,
          }))
        );
      }
    } catch {
      // Silently fail
    } finally {
      setLoading(false);
    }
  };

  const handleSend = useCallback(async () => {
    const trimmed = commentText.trim();
    if (!trimmed || sending) return;

    setSending(true);
    try {
      const { data, error } = await supabase
        .from('reaction_comments')
        .insert({
          message_id: messageId,
          emoji,
          user_id: currentUserId,
          content: trimmed,
        })
        .select('id, user_id, content, created_at, profiles:user_id(username, display_name, avatar_url)')
        .single();

      if (data && !error) {
        const profile = (data as any).profiles;
        setComments((prev) => [
          ...prev,
          {
            id: data.id,
            user_id: data.user_id,
            username: profile?.username || 'You',
            display_name: profile?.display_name || null,
            avatar_url: profile?.avatar_url || null,
            content: data.content,
            created_at: data.created_at,
          },
        ]);
        setCommentText('');
      }
    } catch {
      // Silently fail
    } finally {
      setSending(false);
    }
  }, [commentText, messageId, emoji, currentUserId, sending]);

  const handleDeleteComment = useCallback(async (commentId: string) => {
    await supabase.from('reaction_comments').delete().eq('id', commentId).eq('user_id', currentUserId);
    setComments((prev) => prev.filter((c) => c.id !== commentId));
  }, [currentUserId]);

  const formatTime = (iso: string) =>
    new Date(iso).toLocaleString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.emojiLarge}>{emoji}</Text>
        <View style={styles.headerInfo}>
          <Text style={styles.title}>Reactions</Text>
          <Text style={styles.subtitle}>
            {users.length} {users.length === 1 ? 'person' : 'people'} reacted
          </Text>
        </View>
        <TouchableOpacity onPress={onClose} style={styles.closeBtn}>
          <Ionicons name="close" size={22} color="#B9BBBE" />
        </TouchableOpacity>
      </View>

      {/* Who reacted */}
      <View style={styles.usersRow}>
        {users.slice(0, 10).map((u) => (
          <View key={u.id} style={styles.userChip}>
            {u.avatar_url ? (
              <Image source={{ uri: u.avatar_url }} style={styles.userAvatar} />
            ) : (
              <View style={styles.userAvatarPlaceholder}>
                <Text style={styles.userInitial}>
                  {(u.display_name || u.username).charAt(0).toUpperCase()}
                </Text>
              </View>
            )}
            <Text style={styles.userName} numberOfLines={1}>
              {u.display_name || u.username}
            </Text>
          </View>
        ))}
        {users.length > 10 && (
          <Text style={styles.moreUsers}>+{users.length - 10} more</Text>
        )}
      </View>

      {/* Divider */}
      <View style={styles.divider} />

      {/* Comments */}
      <Text style={styles.commentsTitle}>Comments ({comments.length})</Text>
      <FlatList
        data={comments}
        keyExtractor={(c) => c.id}
        style={styles.commentsList}
        contentContainerStyle={styles.commentsContent}
        renderItem={({ item }) => (
          <View style={styles.commentRow}>
            {item.avatar_url ? (
              <Image source={{ uri: item.avatar_url }} style={styles.commentAvatar} />
            ) : (
              <View style={styles.commentAvatarPlaceholder}>
                <Text style={styles.commentInitial}>
                  {(item.display_name || item.username).charAt(0).toUpperCase()}
                </Text>
              </View>
            )}
            <View style={styles.commentBody}>
              <View style={styles.commentMeta}>
                <Text style={styles.commentAuthor}>
                  {item.display_name || item.username}
                </Text>
                <Text style={styles.commentTime}>{formatTime(item.created_at)}</Text>
              </View>
              <Text style={styles.commentText}>{item.content}</Text>
            </View>
            {item.user_id === currentUserId && (
              <TouchableOpacity
                onPress={() => handleDeleteComment(item.id)}
                style={styles.deleteBtn}
              >
                <Ionicons name="trash-outline" size={14} color="#ED4245" />
              </TouchableOpacity>
            )}
          </View>
        )}
        ListEmptyComponent={
          <Text style={styles.emptyText}>No comments yet. Be the first!</Text>
        }
      />

      {/* Input */}
      <View style={styles.inputRow}>
        <TextInput
          ref={inputRef}
          style={styles.input}
          value={commentText}
          onChangeText={setCommentText}
          placeholder="Add a comment…"
          placeholderTextColor="#72767D"
          maxLength={200}
          returnKeyType="send"
          onSubmitEditing={handleSend}
        />
        <TouchableOpacity
          onPress={handleSend}
          disabled={!commentText.trim() || sending}
          style={[styles.sendBtn, (!commentText.trim() || sending) && styles.sendBtnDisabled]}
        >
          <Ionicons name="send" size={18} color="#FFF" />
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#36393F',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#202225',
  },
  emojiLarge: {
    fontSize: 32,
  },
  headerInfo: {
    flex: 1,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 18,
    fontFamily: 'GGSans-Bold',
  },
  subtitle: {
    color: '#96989D',
    fontSize: 13,
    fontFamily: 'GGSans-Regular',
  },
  closeBtn: {
    padding: 4,
  },
  usersRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    padding: 12,
    gap: 8,
  },
  userChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#2F3136',
    borderRadius: 16,
    paddingHorizontal: 8,
    paddingVertical: 4,
    gap: 6,
  },
  userAvatar: {
    width: 20,
    height: 20,
    borderRadius: 10,
  },
  userAvatarPlaceholder: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: '#5865F2',
    alignItems: 'center',
    justifyContent: 'center',
  },
  userInitial: {
    color: '#FFF',
    fontSize: 10,
    fontFamily: 'GGSans-Bold',
  },
  userName: {
    color: '#DCDDDE',
    fontSize: 12,
    fontFamily: 'GGSans-Medium',
    maxWidth: 80,
  },
  moreUsers: {
    color: '#72767D',
    fontSize: 12,
    fontFamily: 'GGSans-Regular',
    alignSelf: 'center',
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: '#202225',
    marginHorizontal: 16,
  },
  commentsTitle: {
    color: '#B9BBBE',
    fontSize: 12,
    fontFamily: 'GGSans-Bold',
    letterSpacing: 0.5,
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
  },
  commentsList: {
    flex: 1,
  },
  commentsContent: {
    paddingHorizontal: 16,
    gap: 10,
  },
  commentRow: {
    flexDirection: 'row',
    gap: 10,
    alignItems: 'flex-start',
  },
  commentAvatar: {
    width: 28,
    height: 28,
    borderRadius: 14,
  },
  commentAvatarPlaceholder: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#5865F2',
    alignItems: 'center',
    justifyContent: 'center',
  },
  commentInitial: {
    color: '#FFF',
    fontSize: 12,
    fontFamily: 'GGSans-Bold',
  },
  commentBody: {
    flex: 1,
  },
  commentMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 2,
  },
  commentAuthor: {
    color: '#FFFFFF',
    fontSize: 13,
    fontFamily: 'GGSans-SemiBold',
  },
  commentTime: {
    color: '#72767D',
    fontSize: 11,
    fontFamily: 'GGSans-Regular',
  },
  commentText: {
    color: '#DCDDDE',
    fontSize: 13,
    fontFamily: 'GGSans-Regular',
    lineHeight: 18,
  },
  deleteBtn: {
    padding: 4,
  },
  emptyText: {
    color: '#72767D',
    fontSize: 13,
    fontFamily: 'GGSans-Regular',
    textAlign: 'center',
    paddingVertical: 20,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    gap: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#202225',
  },
  input: {
    flex: 1,
    backgroundColor: '#40444B',
    borderRadius: 20,
    paddingHorizontal: 14,
    paddingVertical: 8,
    color: '#DCDDDE',
    fontSize: 14,
    fontFamily: 'GGSans-Regular',
  },
  sendBtn: {
    backgroundColor: '#5865F2',
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendBtnDisabled: {
    opacity: 0.4,
  },
});
