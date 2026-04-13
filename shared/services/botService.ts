// ============================================================================
// Bot Service — Client-side interface for the Flicko bot system
// ============================================================================
// Uses Supabase for direct DB reads/writes (settings, leaderboard, etc.)
// Uses Go backend REST API for slash command invocation (command router lives there)
// ============================================================================

import { supabase } from '../../mobile/services/supabase';
import { GO_BACKEND_URL } from '../../mobile/constants/Config';

// ── Types ───────────────────────────────────────────────────────────────────

export interface BotInfo {
  name: string;
  display_name: string;
  description: string;
  avatar: string;
  enabled: boolean;
}

export interface CommandDefinition {
  name: string;
  description: string;
  options: CommandOption[];
}

export interface CommandOption {
  name: string;
  description: string;
  type: number; // 1=SubCommand, 3=String, 4=Integer, 5=Boolean, 6=User, 7=Channel, 8=Role
  required: boolean;
  choices?: { name: string; value: string | number }[];
  options?: CommandOption[];
}

export interface CommandResponse {
  content: string;
  embed?: Embed;
  ephemeral: boolean;
  components?: ActionRow[];
  data?: Record<string, any>;
}

export interface Embed {
  title: string;
  description: string;
  color: string;
  fields: EmbedField[];
  footer: string;
  thumbnail: string;
}

export interface EmbedField {
  name: string;
  value: string;
  inline: boolean;
}

export interface ActionRow {
  type: number;
  components: ActionComponent[];
}

export interface ActionComponent {
  type: number;
  custom_id: string;
  label: string;
  style: number;
  disabled: boolean;
  emoji?: string;
}

export interface LeaderboardEntry {
  user_id: string;
  username: string;
  avatar_url: string | null;
  xp: number;
  level: number;
  message_count: number;
  rank: number;
}

export interface UserRank {
  user_id: string;
  server_id: string;
  xp: number;
  level: number;
  message_count: number;
  rank: number;
}

export interface Ticket {
  id: string;
  ticket_number: number;
  subject: string;
  status: string;
  priority: string;
  creator_id: string;
  creator_name: string;
  created_at: string;
  message_count: number;
}

export interface Poll {
  id: string;
  question: string;
  creator_id: string;
  anonymous: boolean;
  multi_vote: boolean;
  status: string;
  expires_at: string | null;
  created_at: string;
  options: PollOption[];
}

export interface PollOption {
  id: string;
  label: string;
  emoji: string;
  votes: number;
}

export interface StarboardEntry {
  id: string;
  original_message_id: string;
  original_channel_id: string;
  author_id: string;
  author_name: string;
  star_count: number;
  content: string;
  created_at: string;
}

export interface ModSettings {
  server_id: string;
  enabled: boolean;
  mod_log_channel_id: string | null;
  mute_role_id: string | null;
  auto_escalate: boolean;
  warn_threshold_mute: number;
  warn_threshold_kick: number;
  warn_threshold_ban: number;
}

export interface AutoModSettings {
  server_id: string;
  enabled: boolean;
  invite_filter: boolean;
  link_filter: boolean;
  caps_filter: boolean;
  caps_threshold: number;
  emoji_filter: boolean;
  emoji_max: number;
  mention_filter: boolean;
  mention_max: number;
  duplicate_filter: boolean;
  exempt_roles: string[];
  exempt_channels: string[];
  log_channel_id: string | null;
}

export interface WelcomeSettings {
  server_id: string;
  enabled: boolean;
  channel_id: string | null;
  message: string;
  leave_message: string | null;
  auto_roles: string[];
  dm_enabled: boolean;
  dm_message: string | null;
  card_enabled: boolean;
  card_bg_url: string | null;
}

export interface LevelSettings {
  server_id: string;
  enabled: boolean;
  announce_channel_id: string | null;
  announce_message: string;
  xp_min: number;
  xp_max: number;
  xp_cooldown: number;
  stack_rewards: boolean;
  no_xp_roles: string[];
  no_xp_channels: string[];
}

export interface TicketSettings {
  server_id: string;
  enabled: boolean;
  category_id: string | null;
  log_channel_id: string | null;
  staff_role_id: string | null;
  welcome_message: string;
  max_open_tickets: number;
  auto_close_hours: number;
}

export interface StarboardSettings {
  server_id: string;
  enabled: boolean;
  channel_id: string | null;
  threshold: number;
  emoji: string;
  self_star: boolean;
  ignore_channels: string[];
}

// ── Helper: Authenticated fetch to Go Backend ───────────────────────────────

async function backendFetch<T = any>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.access_token) throw new Error('Not authenticated');

  const url = `${GO_BACKEND_URL}/api/v1${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${session.access_token}`,
      ...(options.headers ?? {}),
    },
  });

  if (!res.ok) {
    const errBody = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(errBody.error || `Request failed: ${res.status}`);
  }

  return res.json();
}

// ── All Available Bots ──────────────────────────────────────────────────────

export const ALL_BOTS: BotInfo[] = [
  {
    name: 'moderation',
    display_name: 'Moderation',
    description: 'Kick, ban, mute, warn and manage your server with powerful moderation tools.',
    avatar: '🛡️',
    enabled: false,
  },
  {
    name: 'automod',
    display_name: 'AutoMod',
    description: 'Automatically filter spam, links, excessive caps and more.',
    avatar: '🤖',
    enabled: false,
  },
  {
    name: 'welcome',
    display_name: 'Welcome',
    description: 'Greet new members, assign auto-roles and send goodbye messages.',
    avatar: '👋',
    enabled: false,
  },
  {
    name: 'leveling',
    display_name: 'Leveling & XP',
    description: 'Reward active members with XP, levels, role rewards and leaderboards.',
    avatar: '⭐',
    enabled: false,
  },
  {
    name: 'ticket',
    display_name: 'Tickets',
    description: 'Support ticket system with panels, priorities and auto-close.',
    avatar: '🎫',
    enabled: false,
  },
  {
    name: 'poll',
    display_name: 'Polls',
    description: 'Create polls with multiple options, anonymous voting and expiry.',
    avatar: '📊',
    enabled: false,
  },
  {
    name: 'starboard',
    display_name: 'Starboard',
    description: 'Highlight the best messages by tracking star reactions.',
    avatar: '⭐',
    enabled: false,
  },
  {
    name: 'music',
    display_name: 'Music',
    description: 'Play music, manage queues, create playlists and DJ controls.',
    avatar: '🎵',
    enabled: false,
  },
];

// ── Slash Command Operations ────────────────────────────────────────────────

/** Fetch all registered command definitions from the Go backend. */
export async function fetchCommandDefinitions(): Promise<CommandDefinition[]> {
  return backendFetch<CommandDefinition[]>('/commands');
}

/** Fetch command definitions available for a specific server. */
export async function fetchServerCommands(serverId: string): Promise<CommandDefinition[]> {
  return backendFetch<CommandDefinition[]>(`/commands/${serverId}`);
}

/** Invoke a slash command and get the response. */
export async function invokeCommand(
  commandName: string,
  serverId: string,
  channelId: string,
  options: Record<string, any> = {}
): Promise<{ interaction_id: string; response: CommandResponse }> {
  return backendFetch('/commands/invoke', {
    method: 'POST',
    body: JSON.stringify({
      command_name: commandName,
      server_id: serverId,
      channel_id: channelId,
      options,
    }),
  });
}

// ── Bot Settings (Read/Write via Go Backend) ────────────────────────────────

/** Get settings for a specific bot in a server. */
export async function getBotSettings<T = Record<string, any>>(
  serverId: string,
  botName: string
): Promise<T> {
  return backendFetch<T>(`/servers/${serverId}/bots/${botName}/settings`);
}

/** Enable or disable a bot in a server. */
export async function toggleBot(
  serverId: string,
  botName: string,
  enabled: boolean
): Promise<{ success: boolean; enabled: boolean }> {
  return backendFetch(`/servers/${serverId}/bots/${botName}/settings`, {
    method: 'PUT',
    body: JSON.stringify({ enabled }),
  });
}

/** Update full settings for a bot. */
export async function updateBotSettings(
  serverId: string,
  botName: string,
  settings: Record<string, any>
): Promise<{ success: boolean }> {
  return backendFetch(`/servers/${serverId}/bots/${botName}/settings`, {
    method: 'PUT',
    body: JSON.stringify(settings),
  });
}

// ── Moderation ──────────────────────────────────────────────────────────────

/** Get moderation settings for a server. */
export async function getModSettings(serverId: string): Promise<ModSettings> {
  return getBotSettings<ModSettings>(serverId, 'moderation');
}

/** Get recent warnings for a user in a server. */
export async function getUserWarnings(serverId: string, userId: string) {
  const { data, error } = await supabase
    .from('warnings')
    .select('id, user_id, moderator_id, reason, created_at')
    .eq('server_id', serverId)
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(20);

  if (error) throw error;
  return data ?? [];
}

/** Get recent audit log entries for a server. */
export async function getAuditLog(serverId: string, limit = 50) {
  const { data, error } = await supabase
    .from('audit_logs')
    .select('id, action, user_id, target_id, reason, metadata, created_at')
    .eq('server_id', serverId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return data ?? [];
}

// ── AutoMod ─────────────────────────────────────────────────────────────────

/** Get automod settings for a server. */
export async function getAutoModSettings(serverId: string): Promise<AutoModSettings> {
  return getBotSettings<AutoModSettings>(serverId, 'automod');
}

// ── Welcome ─────────────────────────────────────────────────────────────────

/** Get welcome settings for a server. */
export async function getWelcomeSettings(serverId: string): Promise<WelcomeSettings> {
  return getBotSettings<WelcomeSettings>(serverId, 'welcome');
}

// ── Leveling & XP ───────────────────────────────────────────────────────────

/** Get level settings for a server. */
export async function getLevelSettings(serverId: string): Promise<LevelSettings> {
  return getBotSettings<LevelSettings>(serverId, 'leveling');
}

/** Get the XP leaderboard for a server. */
export async function getLeaderboard(serverId: string): Promise<LeaderboardEntry[]> {
  return backendFetch<LeaderboardEntry[]>(`/servers/${serverId}/leaderboard`);
}

/** Get rank info for a specific user. */
export async function getUserRank(serverId: string, userId: string): Promise<UserRank> {
  return backendFetch<UserRank>(`/servers/${serverId}/rank/${userId}`);
}

/** Get level role rewards for a server. */
export async function getLevelRewards(serverId: string) {
  const { data, error } = await supabase
    .from('level_role_rewards')
    .select('id, server_id, level, role_id, role_name')
    .eq('server_id', serverId)
    .order('level', { ascending: true });

  if (error) throw error;
  return data ?? [];
}

// ── Tickets ─────────────────────────────────────────────────────────────────

/** Get ticket settings for a server. */
export async function getTicketSettings(serverId: string): Promise<TicketSettings> {
  return getBotSettings<TicketSettings>(serverId, 'ticket');
}

/** Get tickets for a server. */
export async function getServerTickets(
  serverId: string,
  status: 'open' | 'closed' | 'all' = 'open'
): Promise<Ticket[]> {
  return backendFetch<Ticket[]>(`/servers/${serverId}/tickets?status=${status}`);
}

// ── Polls ───────────────────────────────────────────────────────────────────

/** Get active polls for a server. */
export async function getActivePolls(serverId: string): Promise<Poll[]> {
  return backendFetch<Poll[]>(`/servers/${serverId}/polls`);
}

/** Vote on a poll option. */
export async function votePoll(
  pollId: string,
  optionId: string
): Promise<{ status: string }> {
  return backendFetch('/polls/vote', {
    method: 'POST',
    body: JSON.stringify({ poll_id: pollId, option_id: optionId }),
  });
}

// ── Starboard ───────────────────────────────────────────────────────────────

/** Get starboard settings for a server. */
export async function getStarboardSettings(serverId: string): Promise<StarboardSettings> {
  return getBotSettings<StarboardSettings>(serverId, 'starboard');
}

/** Get top starred messages. */
export async function getStarboardEntries(serverId: string): Promise<StarboardEntry[]> {
  return backendFetch<StarboardEntry[]>(`/servers/${serverId}/starboard`);
}

// ── Utility: Get all bot statuses for a server ──────────────────────────────

/** Get enabled/disabled status of all bots for a server. */
export async function getAllBotStatuses(serverId: string): Promise<BotInfo[]> {
  const bots = ALL_BOTS.map((b) => ({ ...b }));

  // Check each settings table for enabled status
  const tables = [
    { name: 'moderation', table: 'mod_settings' },
    { name: 'automod', table: 'automod_settings' },
    { name: 'welcome', table: 'welcome_settings' },
    { name: 'leveling', table: 'level_settings' },
    { name: 'ticket', table: 'ticket_settings' },
    { name: 'starboard', table: 'starboard_settings' },
  ];

  await Promise.all(
    tables.map(async ({ name, table }) => {
      const { data, error } = await supabase
        .from(table)
        .select('enabled')
        .eq('server_id', serverId)
        .maybeSingle();

      const bot = bots.find((b) => b.name === name);
      if (bot && !error && data) {
        bot.enabled = data.enabled ?? false;
      }
    }),
  );

  // Music and poll bots don't have a dedicated settings table with enabled column
  // They are always available — check via music_settings if it exists
  const { data: musicData } = await supabase
    .from('music_settings')
    .select('enabled')
    .eq('server_id', serverId)
    .maybeSingle();
  const musicBot = bots.find((b) => b.name === 'music');
  if (musicBot && musicData) musicBot.enabled = musicData.enabled ?? false;

  // Poll bot is always available (uses polls table directly)
  const pollBot = bots.find((b) => b.name === 'poll');
  if (pollBot) pollBot.enabled = true;

  return bots;
}

// ── Member Join Notification ────────────────────────────────────────────────

/**
 * Notify the Go backend that a user joined a server, so bots (e.g. WelcomeBot)
 * can react. Call this after adding the member via Supabase.
 */
export async function notifyMemberJoin(serverId: string): Promise<void> {
  try {
    await backendFetch(`/servers/${serverId}/members/join-notify`, {
      method: 'POST',
    });
  } catch {
    // Non-critical: welcome message is nice-to-have, don't block join flow
    console.warn('Failed to notify backend of member join (welcome bot may not fire)');
  }
}

/**
 * Notify the Go backend that a user left a server, so bots (e.g. WelcomeBot
 * goodbye message) can react. Call this BEFORE deleting the member row.
 */
export async function notifyMemberLeave(serverId: string): Promise<void> {
  try {
    await backendFetch(`/servers/${serverId}/members/leave-notify`, {
      method: 'POST',
    });
  } catch {
    console.warn('Failed to notify backend of member leave');
  }
}

/**
 * Notify the Go backend that a message was created, so bots (AutoMod,
 * Leveling) can process it.
 */
export async function notifyMessageCreate(params: {
  messageId: string;
  channelId: string;
  serverId: string;
  content: string;
}): Promise<void> {
  try {
    await backendFetch('/messages/notify', {
      method: 'POST',
      body: JSON.stringify({
        message_id: params.messageId,
        channel_id: params.channelId,
        server_id: params.serverId,
        content: params.content,
      }),
    });
  } catch {
    console.warn('Failed to notify backend of message create');
  }
}

/**
 * Notify the Go backend that a reaction was added, so bots (Starboard) can react.
 */
export async function notifyReactionAdd(params: {
  messageId: string;
  channelId: string;
  serverId: string;
  emoji: string;
}): Promise<void> {
  try {
    await backendFetch('/reactions/add-notify', {
      method: 'POST',
      body: JSON.stringify({
        message_id: params.messageId,
        channel_id: params.channelId,
        server_id: params.serverId,
        emoji: params.emoji,
      }),
    });
  } catch {
    console.warn('Failed to notify backend of reaction add');
  }
}

/**
 * Notify the Go backend that a reaction was removed, so bots (Starboard) can react.
 */
export async function notifyReactionRemove(params: {
  messageId: string;
  channelId: string;
  serverId: string;
  emoji: string;
}): Promise<void> {
  try {
    await backendFetch('/reactions/remove-notify', {
      method: 'POST',
      body: JSON.stringify({
        message_id: params.messageId,
        channel_id: params.channelId,
        server_id: params.serverId,
        emoji: params.emoji,
      }),
    });
  } catch {
    console.warn('Failed to notify backend of reaction remove');
  }
}
