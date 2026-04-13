// Shared TypeScript type definitions
// This file contains all database models and type definitions

// Domain models for Flicko application

export interface User {
  id: string;
  email: string;
  username: string;
  discriminator: string;
  display_name: string | null;
  avatar: string | null;
  banner: string | null;
  bio: string | null;
  pronouns: string | null;
  status: 'online' | 'idle' | 'dnd' | 'offline';
  custom_status: string | null;
  custom_status_emoji: string | null;
  custom_status_expires_at: string | null;
  accent_color: string | null;
  badges: Badge[] | null;
  created_at: string;
  updated_at: string;
}

export interface Badge {
  id: string;
  name: string;
  icon: string;
  color: string;
}

export interface Server {
  id: string;
  name: string;
  description: string | null;
  icon: string | null;
  banner: string | null;
  owner_id: string;
  member_count: number;
  created_at: string;
}

export type ChannelType = 'text' | 'voice' | 'category' | 'announcement' | 'forum' | 'stage' | 'dm';

export interface Channel {
  id: string;
  server_id: string;
  name: string;
  type: ChannelType;
  topic: string | null;
  position: number;
  nsfw: boolean;
  parent_id: string | null;           // category channel this belongs to
  slowmode_seconds: number;            // 0 = disabled
  last_message_id: string | null;
  default_thread_auto_archive: number; // minutes
  created_at: string;
  updated_at: string;
}

export interface Message {
  id: string;
  channel_id: string;
  author_id: string | null;
  content: string;
  type: 'default' | 'reply' | 'system' | 'bot' | 'webhook' | string;
  reply_to_id: string | null;
  thread_id: string | null;
  attachments: Attachment[];
  embeds: Embed[];
  reactions: Reaction[];
  mentions: string[];
  mention_roles: string[];
  mention_everyone: boolean;
  pinned: boolean;
  edited: boolean;
  edited_at: string | null;
  created_at: string;
  updated_at: string | null;
  author?: User;
  reply_to?: {
    id: string;
    content: string;
    author?: User;
  };
  thread?: {
    id: string;
    name: string;
    message_count: number;
  };
}

export interface Attachment {
  id: string;
  filename: string;
  url: string;
  size: number;
  content_type: string;
  width: number | null;
  height: number | null;
}

export interface Embed {
  title?: string;
  description?: string;
  url?: string;
  color?: string;
  timestamp?: string;
}

export interface Reaction {
  emoji: string;
  count: number;
  users: string[];
  me: boolean;
}

// ── Poll Types ──────────────────────────────────────────────────────

export interface Poll {
  id: string;
  channel_id: string;
  creator_id: string;
  question: string;
  options: PollOption[];
  allow_multi_vote: boolean;
  expires_at: string | null;
  ended_at: string | null;
  total_votes: number;
  created_at: string;
}

export interface PollOption {
  id: string;
  text: string;
  emoji: string | null;
  position: number;
  vote_count: number;
}

export interface PollVote {
  id: string;
  poll_id: string;
  option_id: string;
  user_id: string;
  voted_at: string;
}

// ── Push Notification Types ─────────────────────────────────────────

export interface PushToken {
  user_id: string;
  token: string;
  platform: 'ios' | 'android' | 'web';
  device_id: string;
  is_active: boolean;
}

export interface DirectMessage {
  id: string;
  sender_id: string;
  recipient_id: string;
  content: string;
  created_at: string;
  updated_at: string | null;
  sender?: User;
}

export interface Member {
  id: string;
  server_id: string;
  user_id: string;
  nickname: string | null;
  joined_at: string;
  user?: User;
}

export interface Presence {
  user_id: string;
  status: 'online' | 'idle' | 'dnd' | 'offline';
  last_seen: string;
}

export interface Invite {
  id: string;
  server_id: string;
  code: string;
  created_by: string;
  expires_at: string | null;
  max_uses: number | null;
  uses: number;
  created_at: string;
}

// Activity Feed Models

export enum ActivityType {
  MESSAGE = 'message',
  MENTION = 'mention',
  FRIEND_REQUEST = 'friend_request',
  SERVER_INVITE = 'server_invite',
  REACTION = 'reaction',
}

export interface ActivityMetadata {
  serverId?: string;
  serverName?: string;
  channelId?: string;
  channelName?: string;
  messageId?: string;
  fromUserId?: string;
  fromUsername?: string;
}

export interface ActivityItem {
  id: string;
  user_id: string;
  type: ActivityType;
  content: string;
  timestamp: Date;
  metadata: ActivityMetadata;
  read: boolean;
}

// Friends Models

export enum FriendshipStatus {
  PENDING = 'pending',
  ACCEPTED = 'accepted',
  BLOCKED = 'blocked',
}

export enum UserStatus {
  ONLINE = 'online',
  IDLE = 'idle',
  DND = 'dnd',
  OFFLINE = 'offline',
}

export interface UserProfile {
  id: string;
  username: string;
  avatar: string | null;
  status: UserStatus;
  custom_status: string | null;
  last_seen: Date;
}

export interface Friend {
  id: string;
  user_id: string;
  friend_user_id: string;
  status: FriendshipStatus;
  created_at: Date;
  user: UserProfile;
}

export interface FriendRequest {
  id: string;
  from_user_id: string;
  to_user_id: string;
  status: FriendshipStatus;
  user: Friend;
  created_at: Date;
}

// Server Discovery Models

export interface RecommendedServer {
  id: string;
  name: string;
  description: string;
  icon: string | null;
  banner: string | null;
  member_count: number;
  online_count: number;
  categories: string[];
  featured: boolean;
  verified: boolean;
  created_at: Date;
}

// Direct message conversation model
export interface DMConversation {
  id: string;
  participant_ids: string[];
  created_at: string;
  updated_at: string;
}

// Thread Models

export interface Thread {
  id: string;
  server_id: string;
  parent_channel_id: string;
  parent_message_id: string;
  name: string;
  creator_id: string;
  type: 'public' | 'private';
  archived: boolean;
  locked: boolean;
  auto_archive_duration: string;
  archive_at: string | null;
  message_count: number;
  member_count: number;
  last_message_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ThreadMember {
  id: string;
  thread_id: string;
  user_id: string;
  muted: boolean;
  joined_at: string;
  user?: User;
}

// Voice Models

export type VoiceConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'reconnecting'
  | 'failed';

export interface VoiceState {
  id: string;
  user_id: string;
  channel_id: string;
  session_id: string;
  self_mute: boolean;
  self_deaf: boolean;
  suppress: boolean;
  joined_at: string;
  user?: User;
}
