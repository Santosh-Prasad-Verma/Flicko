/**
 * DM Types — Discord-style Direct Messages
 */

export type UserStatus = 'online' | 'idle' | 'dnd' | 'offline';

export interface DMParticipant {
  id: string;
  name: string;
  avatar?: string;
  status: UserStatus;
  isBot?: boolean;
}

export interface DMConversation {
  id: string;
  participant: DMParticipant;
  lastMessage?: string;
  lastMessageAt?: string;
  unreadCount: number;
  isPinned?: boolean;
  isMuted?: boolean;
  isTyping?: boolean;
}
