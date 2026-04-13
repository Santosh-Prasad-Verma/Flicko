import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { createZustandStorage } from '../lib/storage';

/**
 * Valid theme names
 */
const VALID_THEMES = ['light', 'dark', 'amoled', 'auto'] as const;

/**
 * Validates theme value and returns a valid theme or default
 * @param value - Theme value to validate
 * @returns Valid theme name or 'dark' as fallback
 */
function validateTheme(value: unknown): 'light' | 'dark' | 'amoled' | 'auto' {
  if (typeof value === 'string' && VALID_THEMES.includes(value as any)) {
    return value as 'light' | 'dark' | 'amoled' | 'auto';
  }
  if (value !== undefined && value !== null) {
    console.warn('[settingsStore] Invalid theme value detected, falling back to dark:', value);
  }
  return 'dark';
}

/**
 * Notification settings (Feature 10: Notification Suppression)
 */
interface NotificationSettings {
  desktop: boolean;
  sound: boolean;
  mentions: boolean;
  suppressEveryone: boolean;
  suppressRoles: boolean;
  mobilePush: boolean;
  dmNotifications: boolean;
  quietHoursEnabled: boolean;
  quietHoursStart: string; // HH:MM format
  quietHoursEnd: string;
}

/**
 * Per-server/channel notification overrides (Feature 10)
 */
export type NotificationOverride = 'default' | 'all' | 'mentions' | 'nothing' | 'mute';

/**
 * Accessibility settings
 */
interface AccessibilitySettings {
  reducedMotion: boolean;
  highContrast: boolean;
  allowTTS: boolean; // Feature 4: TTS
}

/**
 * Voice settings
 */
interface VoiceSettings {
  inputMode: 'voice_activity' | 'push_to_talk'; // Feature 22: Push to Talk
  voiceActivityThreshold: number; // 0-100
  noiseSuppression: 'off' | 'low' | 'high'; // Feature 21: Noise Suppression
  echoCancellation: boolean;
  autoGainControl: boolean;
}

/**
 * Status scheduling (Feature 18)
 */
interface StatusSchedule {
  autoDndEnabled: boolean;
  autoDndStart: string; // HH:MM
  autoDndEnd: string;   // HH:MM
  idleTimeoutMinutes: number;
}

/** Chat behaviour toggles (mobile + web) */
export interface ChatPreferences {
  linkPreviews: boolean;
  embeds: boolean;
  emojiReactions: boolean;
  autoPlayGifs: boolean;
  autoDownload: boolean;
}

/** Privacy toggles: persisted locally and synced to public.user_privacy_settings (see privacySettingsService). */
export interface PrivacyPreferences {
  allowDmsFromServerMembers: boolean;
  allowDmsFromEveryone: boolean;
  allowFriendRequestsFromEveryone: boolean;
  showOnlineStatus: boolean;
  showCurrentActivity: boolean;
  readReceipts: boolean;
}

/** Data & storage */
export interface DataStoragePreferences {
  autoDownloadImages: boolean;
  autoDownloadVideos: boolean;
  autoDownloadFiles: boolean;
}

const DEFAULT_CHAT: ChatPreferences = {
  linkPreviews: true,
  embeds: true,
  emojiReactions: true,
  autoPlayGifs: true,
  autoDownload: true,
};

const DEFAULT_PRIVACY: PrivacyPreferences = {
  allowDmsFromServerMembers: true,
  allowDmsFromEveryone: false,
  allowFriendRequestsFromEveryone: true,
  showOnlineStatus: true,
  showCurrentActivity: true,
  readReceipts: true,
};

const DEFAULT_DATA_STORAGE: DataStoragePreferences = {
  autoDownloadImages: true,
  autoDownloadVideos: false,
  autoDownloadFiles: false,
};

/**
 * Settings Store with cross-platform persistence
 * Manages user preferences for theme, language, display, notifications, accessibility,
 * voice, developer mode, and more.
 */
interface SettingsStore {
  theme: 'light' | 'dark' | 'amoled' | 'auto';
  language: string;
  fontSize: number;
  messageDisplay: 'cozy' | 'compact'; // Feature 34: Compact Message Mode
  notifications: NotificationSettings;
  accessibility: AccessibilitySettings;
  voice: VoiceSettings;
  statusSchedule: StatusSchedule;
  developerMode: boolean; // Feature 20: Developer Mode
  chatPreferences: ChatPreferences;
  privacyPreferences: PrivacyPreferences;
  dataStorage: DataStoragePreferences;
  // Per-server notification overrides (Feature 10)
  serverNotificationOverrides: Record<string, NotificationOverride>;
  // Per-channel notification overrides (Feature 10)
  channelNotificationOverrides: Record<string, NotificationOverride>;

  setTheme: (theme: 'light' | 'dark' | 'amoled' | 'auto') => void;
  setLanguage: (language: string) => void;
  setFontSize: (size: number) => void;
  setMessageDisplay: (mode: 'cozy' | 'compact') => void;
  updateNotifications: (settings: Partial<NotificationSettings>) => void;
  updateAccessibility: (settings: Partial<AccessibilitySettings>) => void;
  updateVoice: (settings: Partial<VoiceSettings>) => void;
  updateStatusSchedule: (settings: Partial<StatusSchedule>) => void;
  setDeveloperMode: (enabled: boolean) => void;
  updateChatPreferences: (settings: Partial<ChatPreferences>) => void;
  updatePrivacyPreferences: (settings: Partial<PrivacyPreferences>) => void;
  updateDataStorage: (settings: Partial<DataStoragePreferences>) => void;
  setServerNotificationOverride: (serverId: string, override: NotificationOverride) => void;
  setChannelNotificationOverride: (channelId: string, override: NotificationOverride) => void;
}

export const useSettingsStore = create<SettingsStore>()(
  persist(
    (set) => ({
      theme: 'dark',
      language: 'en',
      fontSize: 16,
      messageDisplay: 'cozy',
      notifications: {
        desktop: true,
        sound: true,
        mentions: true,
        suppressEveryone: false,
        suppressRoles: false,
        mobilePush: true,
        dmNotifications: true,
        quietHoursEnabled: false,
        quietHoursStart: '23:00',
        quietHoursEnd: '07:00',
      },
      accessibility: {
        reducedMotion: false,
        highContrast: false,
        allowTTS: true,
      },
      voice: {
        inputMode: 'voice_activity',
        voiceActivityThreshold: 50,
        noiseSuppression: 'high',
        echoCancellation: true,
        autoGainControl: true,
      },
      statusSchedule: {
        autoDndEnabled: false,
        autoDndStart: '23:00',
        autoDndEnd: '07:00',
        idleTimeoutMinutes: 5,
      },
      developerMode: false,
      chatPreferences: { ...DEFAULT_CHAT },
      privacyPreferences: { ...DEFAULT_PRIVACY },
      dataStorage: { ...DEFAULT_DATA_STORAGE },
      serverNotificationOverrides: {},
      channelNotificationOverrides: {},

      setTheme: (theme) => {
        set({ theme });
        if (typeof document !== 'undefined') {
          if (theme === 'auto') {
            const prefersDark = window.matchMedia(
              '(prefers-color-scheme: dark)'
            ).matches;
            document.documentElement.setAttribute(
              'data-theme',
              prefersDark ? 'dark' : 'light'
            );
          } else {
            document.documentElement.setAttribute('data-theme', theme);
          }
        }
      },

      setLanguage: (language) => {
        set({ language });
      },

      setFontSize: (fontSize) => {
        set({ fontSize });
        if (typeof document !== 'undefined') {
          document.documentElement.style.fontSize = `${fontSize}px`;
        }
      },

      setMessageDisplay: (messageDisplay) => set({ messageDisplay }),

      updateNotifications: (settings) =>
        set((state) => ({
          notifications: { ...state.notifications, ...settings },
        })),

      updateAccessibility: (settings) =>
        set((state) => ({
          accessibility: { ...state.accessibility, ...settings },
        })),

      updateVoice: (settings) =>
        set((state) => ({
          voice: { ...state.voice, ...settings },
        })),

      updateStatusSchedule: (settings) =>
        set((state) => ({
          statusSchedule: { ...state.statusSchedule, ...settings },
        })),

      setDeveloperMode: (developerMode) => set({ developerMode }),

      updateChatPreferences: (settings) =>
        set((state) => ({
          chatPreferences: { ...state.chatPreferences, ...settings },
        })),

      updatePrivacyPreferences: (settings) =>
        set((state) => ({
          privacyPreferences: { ...state.privacyPreferences, ...settings },
        })),

      updateDataStorage: (settings) =>
        set((state) => ({
          dataStorage: { ...state.dataStorage, ...settings },
        })),

      setServerNotificationOverride: (serverId, override) =>
        set((state) => ({
          serverNotificationOverrides: {
            ...state.serverNotificationOverrides,
            [serverId]: override,
          },
        })),

      setChannelNotificationOverride: (channelId, override) =>
        set((state) => ({
          channelNotificationOverrides: {
            ...state.channelNotificationOverrides,
            [channelId]: override,
          },
        })),
    }),
    {
      name: 'flicko-settings',
      storage: createJSONStorage(() => createZustandStorage()),
      onRehydrateStorage: () => (state) => {
        if (!state) return;
        const validatedTheme = validateTheme(state.theme);
        if (validatedTheme !== state.theme) {
          state.theme = validatedTheme;
          console.info('[settingsStore] Theme corrected to:', validatedTheme);
        }
        state.chatPreferences = { ...DEFAULT_CHAT, ...(state.chatPreferences ?? {}) };
        state.privacyPreferences = { ...DEFAULT_PRIVACY, ...(state.privacyPreferences ?? {}) };
        state.dataStorage = { ...DEFAULT_DATA_STORAGE, ...(state.dataStorage ?? {}) };
      },
    }
  )
);
