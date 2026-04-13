/**
 * Server Management Store (Features 14, 15, 23, 24, 25, 31, 32, 33)
 *
 * Manages server-level admin settings:
 * - Verification levels (Feature 14)
 * - Linked roles requirements (Feature 15)
 * - Priority speaker permissions (Feature 23)
 * - Server widget settings (Feature 24)
 * - AutoMod rules (Feature 25)
 * - Scheduled events (Feature 31)
 * - Stage channel state (Feature 32)
 * - Forum tags & settings (Feature 33)
 */
import { create } from 'zustand';
import { supabase } from '../lib/supabase';

/* ───── Feature 14: Verification Levels ───── */
export type VerificationLevel = 0 | 1 | 2 | 3 | 4;
export const VERIFICATION_LABELS: Record<VerificationLevel, string> = {
  0: 'None',
  1: 'Low — Verified email',
  2: 'Medium — Registered > 5 min',
  3: 'High — Member > 10 min',
  4: 'Highest — Verified phone',
};

/* ───── Feature 15: Linked Roles ───── */
export interface LinkedRoleRequirement {
  id: string;
  role_id: string;
  provider: 'github' | 'twitch' | 'youtube' | 'spotify' | 'email';
  requirement: Record<string, unknown>; // e.g. { min_followers: 100 }
}

/* ───── Feature 23: Priority Speaker ───── */
export const PERMISSION_PRIORITY_SPEAKER = 1 << 8;

/* ───── Feature 24: Server Widget ───── */
export interface ServerWidget {
  enabled: boolean;
  channel_id?: string;
}

/* ───── Feature 25: AutoMod v2 ───── */
export type AutoModTriggerType = 'keyword' | 'spam' | 'mention_spam' | 'link';
export type AutoModActionType = 'block' | 'alert' | 'timeout';

export interface AutoModAction {
  type: AutoModActionType;
  channel_id?: string; // for alert
  duration?: number;   // for timeout (seconds)
}

export interface AutoModRule {
  id: string;
  server_id: string;
  name: string;
  trigger_type: AutoModTriggerType;
  trigger_config: {
    words?: string[];
    regex?: string[];
    max_mentions?: number;
    allow_domains?: string[];
    block_domains?: string[];
  };
  actions: AutoModAction[];
  exempt_roles: string[];
  exempt_channels: string[];
  enabled: boolean;
}

/* ───── Feature 31: Scheduled Events ───── */
export type EventType = 'voice' | 'stage' | 'external';

export interface ScheduledEvent {
  id: string;
  server_id: string;
  name: string;
  description?: string;
  event_type: EventType;
  voice_channel_id?: string;
  location?: string;
  cover_image?: string;
  start_time: string;
  end_time?: string;
  recurrence?: { type: 'daily' | 'weekly' | 'custom'; interval?: number };
  interested_count: number;
  creator_id: string;
}

/* ───── Feature 32: Stage Channel ───── */
export type SpeakerRequestStatus = 'pending' | 'approved' | 'denied';

export interface StageInstance {
  id: string;
  channel_id: string;
  topic: string;
  privacy: 'public' | 'guild_only';
  started_at: string;
}

export interface SpeakerRequest {
  channel_id: string;
  user_id: string;
  requested_at: string;
  status: SpeakerRequestStatus;
}

/* ───── Feature 33: Forum Tags ───── */
export interface ForumTag {
  id: string;
  channel_id: string;
  name: string;
  emoji?: string;
  moderated: boolean;
}

export interface ForumSettings {
  require_tag: boolean;
  default_sort: 'latest_activity' | 'creation_date';
  default_reaction?: string;
  guidelines?: string;
  auto_archive_hours: number;
}

/* ───── Store State ───── */
interface ServerManagementState {
  // Feature 14
  verificationLevels: Record<string, VerificationLevel>; // serverId → level
  setVerificationLevel: (serverId: string, level: VerificationLevel) => void;

  // Feature 15
  linkedRoleRequirements: Record<string, LinkedRoleRequirement[]>; // serverId → rules
  setLinkedRoleRequirements: (serverId: string, requirements: LinkedRoleRequirement[]) => void;
  addLinkedRoleRequirement: (serverId: string, requirement: LinkedRoleRequirement) => void;
  removeLinkedRoleRequirement: (serverId: string, requirementId: string) => void;

  // Feature 24
  serverWidgets: Record<string, ServerWidget>;
  setServerWidget: (serverId: string, widget: ServerWidget) => void;

  // Feature 25
  autoModRules: Record<string, AutoModRule[]>; // serverId → rules
  setAutoModRules: (serverId: string, rules: AutoModRule[]) => void;
  upsertAutoModRule: (serverId: string, rule: AutoModRule) => void;
  removeAutoModRule: (serverId: string, ruleId: string) => void;
  toggleAutoModRule: (serverId: string, ruleId: string) => void;

  // Feature 31
  scheduledEvents: Record<string, ScheduledEvent[]>;
  setScheduledEvents: (serverId: string, events: ScheduledEvent[]) => void;
  addScheduledEvent: (serverId: string, event: ScheduledEvent) => void;
  removeScheduledEvent: (serverId: string, eventId: string) => void;

  // Feature 32
  stageInstances: Record<string, StageInstance>;
  speakerRequests: Record<string, SpeakerRequest[]>;
  setStageInstance: (channelId: string, instance: StageInstance | null) => void;
  setSpeakerRequests: (channelId: string, requests: SpeakerRequest[]) => void;
  updateSpeakerRequest: (channelId: string, userId: string, status: SpeakerRequestStatus) => void;

  // Feature 33
  forumTags: Record<string, ForumTag[]>; // channelId → tags
  forumSettings: Record<string, ForumSettings>;
  setForumTags: (channelId: string, tags: ForumTag[]) => void;
  setForumSettings: (channelId: string, settings: ForumSettings) => void;

  // Fetch helpers
  fetchServerSettings: (serverId: string) => Promise<void>;
  fetchAutoModRules: (serverId: string) => Promise<void>;
}

export const useServerManagementStore = create<ServerManagementState>()((set, get) => ({
  verificationLevels: {},
  linkedRoleRequirements: {},
  serverWidgets: {},
  autoModRules: {},
  scheduledEvents: {},
  stageInstances: {},
  speakerRequests: {},
  forumTags: {},
  forumSettings: {},

  // Feature 14
  setVerificationLevel: (serverId, level) =>
    set((s) => ({
      verificationLevels: { ...s.verificationLevels, [serverId]: level },
    })),

  // Feature 15
  setLinkedRoleRequirements: (serverId, requirements) =>
    set((s) => ({
      linkedRoleRequirements: { ...s.linkedRoleRequirements, [serverId]: requirements },
    })),
  addLinkedRoleRequirement: (serverId, requirement) =>
    set((s) => {
      const existing = s.linkedRoleRequirements[serverId] ?? [];
      return {
        linkedRoleRequirements: {
          ...s.linkedRoleRequirements,
          [serverId]: [...existing, requirement],
        },
      };
    }),
  removeLinkedRoleRequirement: (serverId, requirementId) =>
    set((s) => ({
      linkedRoleRequirements: {
        ...s.linkedRoleRequirements,
        [serverId]: (s.linkedRoleRequirements[serverId] ?? []).filter(
          (r) => r.id !== requirementId
        ),
      },
    })),

  // Feature 24
  setServerWidget: (serverId, widget) =>
    set((s) => ({
      serverWidgets: { ...s.serverWidgets, [serverId]: widget },
    })),

  // Feature 25
  setAutoModRules: (serverId, rules) =>
    set((s) => ({ autoModRules: { ...s.autoModRules, [serverId]: rules } })),
  upsertAutoModRule: (serverId, rule) =>
    set((s) => {
      const existing = s.autoModRules[serverId] ?? [];
      const idx = existing.findIndex((r) => r.id === rule.id);
      const updated = idx >= 0
        ? existing.map((r, i) => (i === idx ? rule : r))
        : [...existing, rule];
      return { autoModRules: { ...s.autoModRules, [serverId]: updated } };
    }),
  removeAutoModRule: (serverId, ruleId) =>
    set((s) => ({
      autoModRules: {
        ...s.autoModRules,
        [serverId]: (s.autoModRules[serverId] ?? []).filter((r) => r.id !== ruleId),
      },
    })),
  toggleAutoModRule: (serverId, ruleId) =>
    set((s) => ({
      autoModRules: {
        ...s.autoModRules,
        [serverId]: (s.autoModRules[serverId] ?? []).map((r) =>
          r.id === ruleId ? { ...r, enabled: !r.enabled } : r
        ),
      },
    })),

  // Feature 31
  setScheduledEvents: (serverId, events) =>
    set((s) => ({ scheduledEvents: { ...s.scheduledEvents, [serverId]: events } })),
  addScheduledEvent: (serverId, event) =>
    set((s) => ({
      scheduledEvents: {
        ...s.scheduledEvents,
        [serverId]: [...(s.scheduledEvents[serverId] ?? []), event],
      },
    })),
  removeScheduledEvent: (serverId, eventId) =>
    set((s) => ({
      scheduledEvents: {
        ...s.scheduledEvents,
        [serverId]: (s.scheduledEvents[serverId] ?? []).filter((e) => e.id !== eventId),
      },
    })),

  // Feature 32
  setStageInstance: (channelId, instance) =>
    set((s) => {
      if (!instance) {
        const { [channelId]: _, ...rest } = s.stageInstances;
        return { stageInstances: rest };
      }
      return { stageInstances: { ...s.stageInstances, [channelId]: instance } };
    }),
  setSpeakerRequests: (channelId, requests) =>
    set((s) => ({ speakerRequests: { ...s.speakerRequests, [channelId]: requests } })),
  updateSpeakerRequest: (channelId, userId, status) =>
    set((s) => ({
      speakerRequests: {
        ...s.speakerRequests,
        [channelId]: (s.speakerRequests[channelId] ?? []).map((r) =>
          r.user_id === userId ? { ...r, status } : r
        ),
      },
    })),

  // Feature 33
  setForumTags: (channelId, tags) =>
    set((s) => ({ forumTags: { ...s.forumTags, [channelId]: tags } })),
  setForumSettings: (channelId, settings) =>
    set((s) => ({ forumSettings: { ...s.forumSettings, [channelId]: settings } })),

  // Fetch helpers
  fetchServerSettings: async (serverId) => {
    const { data } = await supabase
      .from('servers')
      .select('verification_level')
      .eq('id', serverId)
      .single();
    if (data?.verification_level !== undefined) {
      get().setVerificationLevel(serverId, data.verification_level as VerificationLevel);
    }

    const { data: linked } = await supabase
      .from('linked_role_requirements')
      .select('*')
      .eq('server_id', serverId);
    if (linked) {
      get().setLinkedRoleRequirements(serverId, linked as LinkedRoleRequirement[]);
    }
  },

  fetchAutoModRules: async (serverId) => {
    const { data } = await supabase
      .from('automod_rules')
      .select('*')
      .eq('server_id', serverId)
      .order('created_at', { ascending: true });
    if (data) {
      get().setAutoModRules(serverId, data as AutoModRule[]);
    }
  },
}));
