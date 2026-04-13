/**
 * Activity Store (Zustand)
 *
 * Manages voice channel activities: available activities, active sessions,
 * and the activity session lifecycle (IDLE → LAUNCHING → ACTIVE → CLOSING → ENDED).
 *
 * Requirements: Activity Picker & Activity Session Lifecycle
 */
import { create } from 'zustand';

// ── Types ─────────────────────────────────────────────────────────────────

export type ActivityCategory = 'games' | 'watch_together' | 'premium';

export interface Activity {
  id: string;
  name: string;
  description: string;
  /** Icon/thumbnail URL */
  iconUrl: string;
  /** Category for filtering */
  category: ActivityCategory;
  /** Max concurrent players */
  maxParticipants: number;
  /** Whether this is a premium-only activity */
  isPremium: boolean;
  /** Embed URL for the WebView */
  embedUrl: string;
  /** Developer / creator name */
  developer: string;
  /** Average session duration label */
  avgDuration: string;
}

export type ActivitySessionState =
  | 'idle'
  | 'launching'
  | 'active'
  | 'closing'
  | 'ended';

export interface ActivityParticipant {
  userId: string;
  displayName: string;
  avatarUrl: string | null;
  joinedAt: string;
}

export interface ActivitySession {
  id: string;
  activityId: string;
  activity: Activity;
  channelId: string;
  serverId: string;
  hostUserId: string;
  state: ActivitySessionState;
  participants: ActivityParticipant[];
  embedUrl: string;
  createdAt: string;
  startedAt: string | null;
  endedAt: string | null;
  errorMessage: string | null;
}

// ── Store ─────────────────────────────────────────────────────────────────

interface ActivityState {
  // Picker
  pickerVisible: boolean;
  selectedCategory: ActivityCategory;
  activities: Activity[];
  searchQuery: string;

  // Session
  currentSession: ActivitySession | null;

  // Actions — picker
  openPicker: () => void;
  closePicker: () => void;
  setCategory: (category: ActivityCategory) => void;
  setActivities: (activities: Activity[]) => void;
  setSearchQuery: (query: string) => void;

  // Actions — session lifecycle
  launchActivity: (session: ActivitySession) => void;
  setSessionState: (state: ActivitySessionState, error?: string) => void;
  addParticipant: (participant: ActivityParticipant) => void;
  removeParticipant: (userId: string) => void;
  setParticipants: (participants: ActivityParticipant[]) => void;
  endSession: () => void;
  reset: () => void;
}

export const useActivityStore = create<ActivityState>((set, get) => ({
  // Picker defaults
  pickerVisible: false,
  selectedCategory: 'games',
  activities: [],
  searchQuery: '',

  // Session defaults
  currentSession: null,

  // ── Picker actions ────────────────────────────────────────────────

  openPicker: () => set({ pickerVisible: true }),
  closePicker: () => set({ pickerVisible: false }),

  setCategory: (category) => set({ selectedCategory: category, searchQuery: '' }),
  setActivities: (activities) => set({ activities }),
  setSearchQuery: (query) => set({ searchQuery: query }),

  // ── Session lifecycle ─────────────────────────────────────────────

  launchActivity: (session) =>
    set({
      currentSession: { ...session, state: 'launching' },
      pickerVisible: false,
    }),

  setSessionState: (state, error) => {
    const { currentSession } = get();
    if (!currentSession) return;

    set({
      currentSession: {
        ...currentSession,
        state,
        errorMessage: error ?? currentSession.errorMessage,
        startedAt:
          state === 'active'
            ? new Date().toISOString()
            : currentSession.startedAt,
        endedAt:
          state === 'ended'
            ? new Date().toISOString()
            : currentSession.endedAt,
      },
    });
  },

  addParticipant: (participant) => {
    const { currentSession } = get();
    if (!currentSession) return;
    if (currentSession.participants.some((p) => p.userId === participant.userId))
      return;
    set({
      currentSession: {
        ...currentSession,
        participants: [...currentSession.participants, participant],
      },
    });
  },

  removeParticipant: (userId) => {
    const { currentSession } = get();
    if (!currentSession) return;
    set({
      currentSession: {
        ...currentSession,
        participants: currentSession.participants.filter(
          (p) => p.userId !== userId,
        ),
      },
    });
  },

  setParticipants: (participants) => {
    const { currentSession } = get();
    if (!currentSession) return;
    set({
      currentSession: { ...currentSession, participants },
    });
  },

  endSession: () => {
    const { currentSession } = get();
    if (!currentSession) return;
    set({
      currentSession: {
        ...currentSession,
        state: 'ended',
        endedAt: new Date().toISOString(),
      },
    });
  },

  reset: () =>
    set({
      pickerVisible: false,
      selectedCategory: 'games',
      activities: [],
      searchQuery: '',
      currentSession: null,
    }),
}));
