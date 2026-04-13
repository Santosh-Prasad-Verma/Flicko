/**
 * Soundboard Store (Zustand)
 *
 * Manages soundboard state: available sounds, favorites, volume,
 * playback state, and upload queue for voice channel soundboards.
 *
 * Requirements: Soundboard Feature
 */
import { create } from 'zustand';

// ── Types ─────────────────────────────────────────────────────────────────

export interface SoundboardSound {
  id: string;
  name: string;
  /** Emoji displayed on the sound button */
  emoji: string;
  /** Remote URL of the audio file */
  soundUrl: string;
  /** Duration in seconds */
  duration: number;
  /** Who uploaded it */
  uploadedBy: string;
  /** Server this sound belongs to (null = global/favorites) */
  serverId: string | null;
  /** Whether this sound is favorited by the current user */
  isFavorite: boolean;
  /** Play count for popularity sorting */
  playCount: number;
  /** Created timestamp */
  createdAt: string;
}

export type SoundboardTab = 'favorites' | 'server' | 'trending';

interface SoundboardState {
  // UI state
  visible: boolean;
  activeTab: SoundboardTab;
  searchQuery: string;

  // Sounds
  favorites: SoundboardSound[];
  serverSounds: SoundboardSound[];
  trendingSounds: SoundboardSound[];

  // Playback
  playingId: string | null;
  volume: number; // 0-1

  // Upload
  uploading: boolean;
  uploadProgress: number;

  // Actions
  open: () => void;
  close: () => void;
  setTab: (tab: SoundboardTab) => void;
  setSearchQuery: (query: string) => void;
  setFavorites: (sounds: SoundboardSound[]) => void;
  setServerSounds: (sounds: SoundboardSound[]) => void;
  setTrendingSounds: (sounds: SoundboardSound[]) => void;
  toggleFavorite: (soundId: string) => void;
  setPlaying: (soundId: string | null) => void;
  setVolume: (volume: number) => void;
  setUploading: (uploading: boolean, progress?: number) => void;
  reset: () => void;
}

// ── Store ─────────────────────────────────────────────────────────────────

export const useSoundboardStore = create<SoundboardState>((set, get) => ({
  visible: false,
  activeTab: 'favorites',
  searchQuery: '',

  favorites: [],
  serverSounds: [],
  trendingSounds: [],

  playingId: null,
  volume: 0.8,

  uploading: false,
  uploadProgress: 0,

  open: () => set({ visible: true }),
  close: () => set({ visible: false, playingId: null }),

  setTab: (tab) => set({ activeTab: tab, searchQuery: '' }),
  setSearchQuery: (query) => set({ searchQuery: query }),

  setFavorites: (sounds) => set({ favorites: sounds }),
  setServerSounds: (sounds) => set({ serverSounds: sounds }),
  setTrendingSounds: (sounds) => set({ trendingSounds: sounds }),

  toggleFavorite: (soundId) => {
    const { favorites, serverSounds, trendingSounds } = get();

    const toggleInList = (list: SoundboardSound[]) =>
      list.map((s) =>
        s.id === soundId ? { ...s, isFavorite: !s.isFavorite } : s,
      );

    set({
      favorites: toggleInList(favorites),
      serverSounds: toggleInList(serverSounds),
      trendingSounds: toggleInList(trendingSounds),
    });
  },

  setPlaying: (soundId) => set({ playingId: soundId }),
  setVolume: (volume) => set({ volume: Math.max(0, Math.min(1, volume)) }),

  setUploading: (uploading, progress = 0) =>
    set({ uploading, uploadProgress: progress }),

  reset: () =>
    set({
      visible: false,
      activeTab: 'favorites',
      searchQuery: '',
      favorites: [],
      serverSounds: [],
      trendingSounds: [],
      playingId: null,
      volume: 0.8,
      uploading: false,
      uploadProgress: 0,
    }),
}));
