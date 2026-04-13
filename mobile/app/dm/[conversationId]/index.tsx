/**
 * DM Conversation Screen
 *
 * Full chat screen for a direct message conversation.
 * Mirrors web DirectMessagePage DM chat view.
 * Route: /dm/[conversationId]
 * Requirements: 7.1, 7.2, 7.3, 7.4, 7.5
 */
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  KeyboardAvoidingView,
  Platform,
  FlatList,
  ActivityIndicator,
  TextInput,
  Alert,
} from 'react-native';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { useLocalSearchParams, router, Stack } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Ionicons } from '@expo/vector-icons';
import { supabase } from '../../../services/supabase';
import { uploadToCloudinary } from '@services/cloudinaryService';
import { uploadAttachment, getSignedUrl, isMediaFile } from '@services/attachmentStorage';
import { Avatar } from '../../../components/ui/Avatar';
import { EmojiPicker } from '../../../components/messages/EmojiPicker';
import { GifPicker } from '../../../components/messages/GifPicker';
import { spacing, typography, MINIMUM_TOUCH_TARGET } from '../../../constants/Colors';
import { useAuthStore } from '@stores/authStore';
import { useTheme } from '../../../hooks/useTheme';
import { initiateCall } from '@services/dmCallService';

const PAGE_SIZE = 50;

interface DMMessage {
  id: string;
  sender_id: string;
  recipient_id: string;
  content: string;
  attachments?: { url: string; type: string; name?: string }[] | null;
  created_at: string;
  sender?: {
    id: string;
    username: string;
    display_name?: string;
    avatar_url?: string;
  };
  recipient?: {
    id: string;
    username: string;
    display_name?: string;
    avatar_url?: string;
  };
}

/* ─── Helpers ─── */
async function getAuthToken(): Promise<string> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error('Not authenticated');
  return session.access_token;
}

async function uriToBlob(uri: string): Promise<Blob> {
  const response = await fetch(uri);
  return response.blob();
}

/* Simple horizontal scrollable row for attachment thumbnails */
function ScrollableRow({ children }: { children: React.ReactNode }) {
  return (
    <FlatList
      horizontal
      data={React.Children.toArray(children)}
      renderItem={({ item }) => <>{item}</>}
      keyExtractor={(_, i) => String(i)}
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={{ gap: spacing.xs, paddingHorizontal: spacing.md }}
    />
  );
}

export default function DMConversationScreen() {
  const { conversationId } = useLocalSearchParams<{ conversationId: string }>();
  const insets = useSafeAreaInsets();
  const { theme, themeColors } = useTheme();
  const queryClient = useQueryClient();
  const user = useAuthStore((s: any) => s.user);
  const [messageText, setMessageText] = useState('');
  const [pendingAttachments, setPendingAttachments] = useState<
    { uri: string; mimeType: string; name: string; width?: number; height?: number }[]
  >([]);
  const [isUploading, setIsUploading] = useState(false);
  const [emojiPickerVisible, setEmojiPickerVisible] = useState(false);
  const [gifPickerVisible, setGifPickerVisible] = useState(false);
  const [otherUser, setOtherUser] = useState<{
    id: string;
    username: string;
    display_name?: string;
    avatar_url?: string;
  } | null>(null);

  // conversationId is the other user's ID (matching web pattern)
  const otherUserId = conversationId;

  // Fetch the other user's profile
  useEffect(() => {
    if (!otherUserId) return;
    (async () => {
      const { data } = await supabase
        .from('profiles')
        .select('id, username, display_name, avatar')
        .eq('id', otherUserId)
        .single();
      if (data) setOtherUser({ ...data, avatar_url: data.avatar });
    })();
  }, [otherUserId]);

  // Fetch DM messages with infinite scroll
  const {
    data: messagesData,
    isLoading,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfiniteQuery({
    queryKey: ['dm-messages', otherUserId],
    queryFn: async ({ pageParam }: { pageParam: string | undefined }) => {
      if (!user?.id || !otherUserId) return [];

      let query = supabase
        .from('direct_messages')
        .select('*, sender:profiles!sender_id(id, username, display_name, avatar_url:avatar), recipient:profiles!recipient_id(id, username, display_name, avatar_url:avatar)')
        .or(
          `and(sender_id.eq.${user.id},recipient_id.eq.${otherUserId}),and(sender_id.eq.${otherUserId},recipient_id.eq.${user.id})`,
        )
        .order('created_at', { ascending: false })
        .limit(PAGE_SIZE);

      if (pageParam) {
        query = query.lt('created_at', pageParam);
      }

      const { data, error } = await query;
      if (error) throw error;
      return (data ?? []) as DMMessage[];
    },
    enabled: !!otherUserId && !!user?.id,
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => {
      if (!lastPage || lastPage.length < PAGE_SIZE) return undefined;
      return lastPage[lastPage.length - 1]?.created_at;
    },
  });

  const messages = useMemo(() => {
    if (!messagesData?.pages) return [];
    return messagesData.pages.flat();
  }, [messagesData]);

  // Real-time subscription for DMs
  useEffect(() => {
    if (!user?.id || !otherUserId) return;

    const channel = supabase
      .channel(`dm-${[user.id, otherUserId].sort().join('-')}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'direct_messages',
        },
        (payload) => {
          const msg = payload.new as DMMessage;
          const isRelevant =
            (msg.sender_id === user.id && msg.recipient_id === otherUserId) ||
            (msg.sender_id === otherUserId && msg.recipient_id === user.id);

          if (isRelevant) {
            queryClient.invalidateQueries({ queryKey: ['dm-messages', otherUserId] });
          }
        },
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user?.id, otherUserId, queryClient]);

  // Send DM mutation — supports text + media attachments
  const sendMutation = useMutation({
    mutationFn: async ({ content, attachments }: { content: string; attachments?: { url: string; type: string; name: string }[] }) => {
      if (!user?.id || !otherUserId) throw new Error('Missing user');
      const { data, error } = await supabase
        .from('direct_messages')
        .insert({
          sender_id: user.id,
          recipient_id: otherUserId,
          content: content.trim(),
          attachments: attachments && attachments.length > 0 ? attachments : null,
        })
        .select()
        .single();
      if (error) throw error;
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dm-messages', otherUserId] });
      queryClient.invalidateQueries({ queryKey: ['dm-conversations'] });
    },
  });

  // Pick media files for attachment
  const handlePickMedia = useCallback(async () => {
    try {
      const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Needed', 'Media library access is required to send files.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images', 'videos'] as any,
        allowsMultipleSelection: true,
        quality: 0.8,
      });

      if (result.canceled || !result.assets?.length) return;

      const newAttachments = result.assets.map((asset) => ({
        uri: asset.uri,
        mimeType: asset.mimeType || 'image/jpeg',
        name: asset.fileName || `file_${Date.now()}.jpg`,
        width: asset.width,
        height: asset.height,
      }));

      setPendingAttachments((prev) => [...prev, ...newAttachments].slice(0, 10));
    } catch (err: any) {
      Alert.alert('Error', err.message || 'Failed to pick files');
    }
  }, []);

  const removePendingAttachment = useCallback((index: number) => {
    setPendingAttachments((prev) => prev.filter((_, i) => i !== index));
  }, []);

  // Camera capture for DM attachments
  const handleCamera = useCallback(async () => {
    try {
      const { status } = await ImagePicker.requestCameraPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Needed', 'Camera access is required to take photos.');
        return;
      }
      const result = await ImagePicker.launchCameraAsync({
        mediaTypes: ['images'] as any,
        quality: 0.8,
      });
      if (result.canceled || !result.assets?.length) return;
      const asset = result.assets[0];
      setPendingAttachments((prev) => [
        ...prev,
        {
          uri: asset.uri,
          mimeType: asset.mimeType || 'image/jpeg',
          name: asset.fileName || `photo_${Date.now()}.jpg`,
          width: asset.width,
          height: asset.height,
        },
      ]);
    } catch (err: any) {
      Alert.alert('Camera Error', err.message || 'Failed to take photo');
    }
  }, []);

  // Open the emoji picker modal
  const handleEmojiPress = useCallback(() => {
    setEmojiPickerVisible(true);
  }, []);

  // Append selected emoji to message text
  const handleEmojiSelect = useCallback((emoji: string) => {
    setMessageText((prev) => prev + emoji);
    setEmojiPickerVisible(false);
  }, []);

  const handleSend = useCallback(async () => {
    const trimmed = messageText.trim();
    const hasAttachments = pendingAttachments.length > 0;
    if (!trimmed && !hasAttachments) return;
    if (trimmed.length > 2000) return;

    let uploadedAttachments: { url: string; type: string; name: string }[] = [];

    // Upload pending attachments (media → Cloudinary, docs → Supabase Storage)
    if (hasAttachments && user?.id) {
      setIsUploading(true);
      try {
        const token = await getAuthToken();
        uploadedAttachments = await Promise.all(
          pendingAttachments.map(async (att) => {
            if (isMediaFile(att.mimeType)) {
              // Images/videos/GIFs → Cloudinary
              const result = await uploadToCloudinary(att.uri, att.mimeType, token, {
                folder: `flickochat/dm/${conversationId}`,
              });
              return { url: result.secure_url, type: att.mimeType, name: att.name };
            } else {
              // Documents/files → Supabase private storage
              const ext = att.name.split('.').pop()?.toLowerCase() || 'bin';
              const storagePath = `dm/${conversationId}/${user.id}-${Date.now()}.${ext}`;
              const blob = await uriToBlob(att.uri);
              await uploadAttachment(storagePath, blob, att.mimeType);
              const signedUrl = await getSignedUrl(storagePath);
              return { url: signedUrl, type: att.mimeType, name: att.name };
            }
          }),
        );
      } catch (err: any) {
        Alert.alert('Upload Failed', err.message || 'Could not upload files');
        setIsUploading(false);
        return;
      }
      setIsUploading(false);
    }

    sendMutation.mutate({
      content: trimmed || (uploadedAttachments.length > 0 ? '' : ''),
      attachments: uploadedAttachments.length > 0 ? uploadedAttachments : undefined,
    });
    setMessageText('');
    setPendingAttachments([]);
  }, [messageText, pendingAttachments, user?.id, sendMutation]);

  const formatTime = (dateStr: string) => {
    const d = new Date(dateStr);
    return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const formatDate = (dateStr: string) => {
    const d = new Date(dateStr);
    const today = new Date();
    if (d.toDateString() === today.toDateString()) return 'Today';
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    if (d.toDateString() === yesterday.toDateString()) return 'Yesterday';
    return d.toLocaleDateString();
  };

  const renderMessage = useCallback(
    ({ item }: { item: DMMessage }) => {
      const isOwn = item.sender_id === user?.id;
      const senderName = isOwn
        ? user?.username || 'You'
        : otherUser?.display_name || otherUser?.username || 'User';
      const avatarUrl = isOwn ? user?.avatar : otherUser?.avatar_url;
      const attachments = Array.isArray(item.attachments) ? item.attachments : [];

      return (
        <View style={styles.messageRow}>
          <Avatar
            name={senderName}
            imageUrl={avatarUrl || undefined}
            size={36}
          />
          <View style={styles.messageContent}>
            <View style={styles.messageHeader}>
              <Text style={[styles.messageSender, { color: themeColors.textPrimary }]}>
                {senderName}
              </Text>
              <Text style={[styles.messageTime, { color: themeColors.textMuted }]}>
                {formatDate(item.created_at)} {formatTime(item.created_at)}
              </Text>
            </View>
            {item.content ? (
              <Text style={[styles.messageText, { color: themeColors.textPrimary }]}>
                {item.content}
              </Text>
            ) : null}
            {attachments.length > 0 && (
              <View style={styles.attachmentsContainer}>
                {attachments.map((att, idx) => (
                  att.type?.startsWith('image/') ? (
                    <Image
                      key={idx}
                      source={{ uri: att.url }}
                      style={styles.attachmentImage}
                      contentFit="cover"
                      cachePolicy="memory-disk"
                    />
                  ) : att.type?.startsWith('video/') ? (
                    <View key={idx} style={[styles.attachmentFile, { backgroundColor: themeColors.bgTertiary }]}>
                      <Ionicons name="videocam" size={20} color={themeColors.textSecondary} />
                      <Text style={[styles.attachmentFileName, { color: themeColors.textSecondary }]} numberOfLines={1}>
                        {att.name || 'Video'}
                      </Text>
                    </View>
                  ) : (
                    <View key={idx} style={[styles.attachmentFile, { backgroundColor: themeColors.bgTertiary }]}>
                      <Ionicons name="document" size={20} color={themeColors.textSecondary} />
                      <Text style={[styles.attachmentFileName, { color: themeColors.textSecondary }]} numberOfLines={1}>
                        {att.name || 'File'}
                      </Text>
                    </View>
                  )
                ))}
              </View>
            )}
          </View>
        </View>
      );
    },
    [user, otherUser, themeColors],
  );

  const displayName = otherUser?.display_name || otherUser?.username || 'Loading...';

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: {
            backgroundColor: theme === 'dark' ? '#36393F' : themeColors.bgPrimary,
          },
          headerTintColor: themeColors.textPrimary,
          headerTitle: () => (
            <View style={styles.headerTitle}>
              <Avatar
                name={displayName}
                imageUrl={otherUser?.avatar_url || undefined}
                size={28}
              />
              <Text
                style={[styles.headerName, { color: themeColors.textPrimary }]}
                numberOfLines={1}
              >
                {displayName}
              </Text>
            </View>
          ),
          headerLeft: () => (
            <Pressable onPress={() => router.back()} hitSlop={8}>
              <Ionicons name="arrow-back" size={24} color={themeColors.textPrimary} />
            </Pressable>
          ),
          headerRight: () => (
            <View style={styles.headerActions}>
              <Pressable
                style={styles.headerBtn}
                onPress={() => initiateCall(conversationId, otherUserId, 'audio')}
                hitSlop={8}
              >
                <Ionicons name="call-outline" size={20} color={themeColors.textSecondary} />
              </Pressable>
              <Pressable
                style={styles.headerBtn}
                onPress={() => initiateCall(conversationId, otherUserId, 'video')}
                hitSlop={8}
              >
                <Ionicons name="videocam-outline" size={22} color={themeColors.textSecondary} />
              </Pressable>
            </View>
          ),
        }}
      />
      <KeyboardAvoidingView
        style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}
        behavior="padding"
        keyboardVerticalOffset={Platform.OS === 'ios' ? 90 : 0}
      >
        {/* Messages */}
        {isLoading ? (
          <View style={styles.loadingContainer}>
            <ActivityIndicator color={themeColors.accentPrimary} size="large" />
          </View>
        ) : messages.length === 0 ? (
          <View style={styles.emptyContainer}>
            <Avatar
              name={displayName}
              imageUrl={otherUser?.avatar_url || undefined}
              size={80}
            />
            <Text style={[styles.emptyTitle, { color: themeColors.textPrimary }]}>
              {displayName}
            </Text>
            <Text style={[styles.emptySubtitle, { color: themeColors.textMuted }]}>
              This is the beginning of your direct message history with{' '}
              <Text style={{ fontFamily: 'gg-sans-bold' }}>@{otherUser?.username || '...'}</Text>.
            </Text>
          </View>
        ) : (
          <FlatList
            data={messages}
            renderItem={renderMessage}
            keyExtractor={(item) => item.id}
            inverted
            contentContainerStyle={styles.messagesList}
            onEndReached={() => {
              if (hasNextPage && !isFetchingNextPage) fetchNextPage();
            }}
            onEndReachedThreshold={0.3}
            ListFooterComponent={
              isFetchingNextPage ? (
                <ActivityIndicator
                  style={styles.loadingMore}
                  color={themeColors.accentPrimary}
                />
              ) : null
            }
          />
        )}

        {/* Pending Attachment Previews */}
        {pendingAttachments.length > 0 && (
          <View style={[styles.pendingRow, { backgroundColor: themeColors.bgSecondary }]}>
            <ScrollableRow>
              {pendingAttachments.map((att, idx) => (
                <View key={idx} style={[styles.pendingThumb, { backgroundColor: themeColors.bgTertiary }]}>
                  {att.mimeType.startsWith('image/') ? (
                    <Image source={{ uri: att.uri }} style={styles.pendingThumbImg} contentFit="cover" />
                  ) : (
                    <Ionicons name="document" size={24} color={themeColors.textMuted} />
                  )}
                  <Pressable
                    style={styles.pendingRemove}
                    onPress={() => removePendingAttachment(idx)}
                    hitSlop={8}
                  >
                    <Ionicons name="close-circle" size={18} color="#ED4245" />
                  </Pressable>
                </View>
              ))}
            </ScrollableRow>
          </View>
        )}

        {/* Upload indicator */}
        {isUploading && (
          <View style={[styles.uploadingBar, { backgroundColor: themeColors.bgSecondary }]}>
            <ActivityIndicator size="small" color={themeColors.accentPrimary} />
            <Text style={[styles.uploadingText, { color: themeColors.textMuted }]}>Uploading...</Text>
          </View>
        )}

        {/* Input */}
        <View
          style={[
            styles.inputContainer,
            {
              backgroundColor: themeColors.bgPrimary,
              paddingBottom: Math.max(insets.bottom, spacing.sm),
            },
          ]}
        >
          <View
            style={[
              styles.inputWrapper,
              { backgroundColor: themeColors.bgSecondary },
            ]}
          >
            <Pressable style={styles.addCircle} onPress={handlePickMedia}>
              <Ionicons name="add" size={20} color={themeColors.textSecondary} />
            </Pressable>
            <TextInput
              style={[styles.textInput, { color: themeColors.textPrimary }]}
              value={messageText}
              onChangeText={setMessageText}
              placeholder={`Message @${otherUser?.username || '...'}`}
              placeholderTextColor={themeColors.textMuted}
              multiline
              maxLength={2000}
              returnKeyType="default"
              blurOnSubmit={false}
            />
            {messageText.trim().length > 0 || pendingAttachments.length > 0 ? (
              <Pressable
                style={[styles.sendButton, { backgroundColor: themeColors.accentPrimary, opacity: isUploading ? 0.5 : 1 }]}
                onPress={handleSend}
                disabled={isUploading}
              >
                <Ionicons name="send" size={14} color="#FFFFFF" style={{ marginLeft: 2 }} />
              </Pressable>
            ) : (
              <>
                <Pressable style={styles.inlineAction} onPress={() => setGifPickerVisible(true)}>
                  <Ionicons name="gift-outline" size={22} color={themeColors.textSecondary} />
                </Pressable>
                <Pressable style={styles.inlineAction} onPress={handleCamera}>
                  <Ionicons name="camera-outline" size={22} color={themeColors.textSecondary} />
                </Pressable>
                <Pressable style={styles.inlineAction} onPress={handleEmojiPress}>
                  <Ionicons name="happy-outline" size={22} color={themeColors.textSecondary} />
                </Pressable>
              </>
            )}
          </View>
          {messageText.length > 1600 && (
            <Text
              style={[
                styles.charCount,
                {
                  color:
                    messageText.length > 2000
                      ? themeColors.danger
                      : messageText.length > 1800
                        ? '#fbbf24'
                        : themeColors.textMuted,
                },
              ]}
            >
              {messageText.length}/2000
            </Text>
          )}
        </View>
      </KeyboardAvoidingView>

      {/* Emoji picker modal */}
      <EmojiPicker
        visible={emojiPickerVisible}
        onSelect={handleEmojiSelect}
        onClose={() => setEmojiPickerVisible(false)}
      />

      {/* GIF picker */}
      {gifPickerVisible && (
        <View style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: '50%', zIndex: 100 }}>
          <GifPicker
            apiKey={process.env.EXPO_PUBLIC_GIPHY_API_KEY}
            onSelect={(gif) => {
              setGifPickerVisible(false);
              sendMutation.mutate({ content: gif.url });
            }}
            onClose={() => setGifPickerVisible(false)}
          />
        </View>
      )}
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.xl,
  },
  emptyTitle: {
    ...typography.headingL,
    marginTop: spacing.md,
  },
  emptySubtitle: {
    ...typography.body,
    textAlign: 'center',
    marginTop: spacing.xs,
    lineHeight: 22,
  },
  headerTitle: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  headerName: {
    ...typography.bodyBold,
    maxWidth: 180,
  },
  headerActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
  },
  headerSearchPill: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    minWidth: 78,
    height: 21,
    borderRadius: 4,
    paddingHorizontal: 6,
  },
  headerSearchText: {
    ...typography.micro,
  },
  headerBtn: {
    width: 28,
    height: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'center',
  },
  messagesList: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    flexGrow: 1,
  },
  messageRow: {
    flexDirection: 'row',
    paddingVertical: spacing.xs,
    gap: spacing.sm,
  },
  messageContent: {
    flex: 1,
  },
  messageHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: 2,
  },
  messageSender: {
    ...typography.bodyBold,
    fontSize: 15,
  },
  messageTime: {
    ...typography.caption,
    fontSize: 11,
  },
  messageText: {
    ...typography.body,
    lineHeight: 22,
  },
  loadingMore: {
    paddingVertical: spacing.md,
  },
  inputContainer: {
    paddingHorizontal: spacing.md,
    paddingTop: spacing.xs,
    paddingBottom: spacing.sm,
    borderTopWidth: 0,
  },
  inputWrapper: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    borderRadius: 24,
    paddingHorizontal: spacing.sm,
    paddingVertical: Platform.OS === 'ios' ? 6 : 4,
    minHeight: 48,
  },
  addCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(255,255,255,0.1)',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Platform.OS === 'ios' ? 0 : 2,
    marginRight: 4,
  },
  inlineAction: {
    width: 36,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Platform.OS === 'ios' ? -2 : 0,
  },
  textInput: {
    flex: 1,
    ...typography.body,
    maxHeight: 120,
    paddingHorizontal: spacing.sm,
    paddingVertical: Platform.OS === 'ios' ? 8 : 6,
  },
  sendButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Platform.OS === 'ios' ? 0 : 2,
    marginLeft: 4,
  },
  charCount: {
    ...typography.caption,
    textAlign: 'right',
    paddingTop: 4,
    paddingRight: spacing.sm,
  },
  // ── Attachment styles ──
  attachmentsContainer: {
    marginTop: spacing.xs,
    gap: spacing.xs,
  },
  attachmentImage: {
    width: 240,
    height: 180,
    borderRadius: 8,
  },
  attachmentFile: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: 8,
    alignSelf: 'flex-start',
  },
  attachmentFileName: {
    ...typography.bodySmall,
    maxWidth: 200,
  },
  // ── Pending attachment previews ──
  pendingRow: {
    paddingVertical: spacing.xs,
  },
  pendingThumb: {
    width: 64,
    height: 64,
    borderRadius: 8,
    overflow: 'hidden',
    justifyContent: 'center',
    alignItems: 'center',
  },
  pendingThumbImg: {
    width: 64,
    height: 64,
  },
  pendingRemove: {
    position: 'absolute',
    top: 2,
    right: 2,
  },
  uploadingBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
  },
  uploadingText: {
    ...typography.caption,
  },
});
