/**
 * Music API Service
 *
 * Music search using iTunes Search API (free, no auth required).
 * Provides 30-second previews and links to Apple Music.
 *
 * API: https://itunes.apple.com/search
 */
import { useQuery } from '@tanstack/react-query';

// ── Types ────────────────────────────────────────────────────────────────────

export type MusicSource = 'appleMusic';

export type MusicSearchType = 'track' | 'album' | 'artist';

export interface MusicTrack {
  id: string;
  type: 'track';
  name: string;
  artistName: string;
  albumName?: string;
  durationMs?: number;
  imageUrl?: string;
  previewUrl?: string;
  externalUrl?: string;
  source: MusicSource;
}

export interface MusicAlbum {
  id: string;
  type: 'album';
  name: string;
  artistName: string;
  releaseYear?: number;
  trackCount?: number;
  imageUrl?: string;
  externalUrl?: string;
  source: MusicSource;
}

export interface MusicArtist {
  id: string;
  type: 'artist';
  name: string;
  imageUrl?: string;
  genres?: string[];
  followerCount?: number;
  externalUrl?: string;
  source: MusicSource;
}

export type MusicSearchResult = MusicTrack | MusicAlbum | MusicArtist;

export interface MusicSearchParams {
  query: string;
  type?: MusicSearchType;
  sources?: MusicSource[];
  limit?: number;
}

// iTunes API entity mapping
const ITUNES_ENTITY: Record<MusicSearchType, string> = {
  track: 'song',
  album: 'album',
  artist: 'musicArtist',
};

// ── API Functions ────────────────────────────────────────────────────────────

/**
 * Search for music using iTunes Search API.
 */
export async function searchMusic(
  params: MusicSearchParams
): Promise<MusicSearchResult[]> {
  const { query, type = 'track', limit = 20 } = params;

  if (!query.trim()) return [];

  const url = new URL('https://itunes.apple.com/search');
  url.searchParams.set('term', query.trim());
  url.searchParams.set('media', 'music');
  url.searchParams.set('entity', ITUNES_ENTITY[type]);
  url.searchParams.set('limit', String(limit));

  const response = await fetch(url.toString());

  if (!response.ok) {
    throw new Error(`iTunes API error: ${response.status}`);
  }

  const data = await response.json();

  if (!data.results || !Array.isArray(data.results)) {
    return [];
  }

  return data.results.map((item: any) => normalizeItem(item, type));
}

/**
 * Normalize iTunes API response to our internal types.
 */
function normalizeItem(item: any, type: MusicSearchType): MusicSearchResult {
  const source: MusicSource = 'appleMusic';

  switch (type) {
    case 'track':
      return {
        id: String(item.trackId),
        type: 'track',
        name: item.trackName || 'Unknown Track',
        artistName: item.artistName || 'Unknown Artist',
        albumName: item.collectionName,
        durationMs: item.trackTimeMillis,
        imageUrl: item.artworkUrl100?.replace('100x100', '300x300'),
        previewUrl: item.previewUrl,
        externalUrl: item.trackViewUrl,
        source,
      } as MusicTrack;

    case 'album':
      return {
        id: String(item.collectionId),
        type: 'album',
        name: item.collectionName || 'Unknown Album',
        artistName: item.artistName || 'Unknown Artist',
        releaseYear: item.releaseDate ? new Date(item.releaseDate).getFullYear() : undefined,
        trackCount: item.trackCount,
        imageUrl: item.artworkUrl100?.replace('100x100', '300x300'),
        externalUrl: item.collectionViewUrl,
        source,
      } as MusicAlbum;

    case 'artist':
      return {
        id: String(item.artistId),
        type: 'artist',
        name: item.artistName || 'Unknown Artist',
        imageUrl: undefined, // iTunes doesn't provide artist images in search
        genres: item.primaryGenreName ? [item.primaryGenreName] : undefined,
        externalUrl: item.artistViewUrl,
        source,
      } as MusicArtist;
  }
}

// ── React Query Hooks ────────────────────────────────────────────────────────

/**
 * Hook for searching music with React Query caching.
 */
export function useMusicSearch(params: MusicSearchParams & { enabled?: boolean }) {
  const { query, type = 'track', limit = 20, enabled = true } = params;

  return useQuery({
    queryKey: ['music-search', query, type, limit],
    queryFn: () => searchMusic({ query, type, limit }),
    enabled: enabled && query.trim().length >= 2,
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes
  });
}

// ── Utilities ────────────────────────────────────────────────────────────────

/**
 * Format duration from milliseconds to mm:ss.
 */
export function formatDuration(ms?: number): string {
  if (!ms) return '';
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

/**
 * Get display name for a music source.
 */
export function getSourceDisplayName(source: MusicSource): string {
  return 'Apple Music';
}

/**
 * Get icon name for a music source (Ionicons).
 */
export function getSourceIcon(source: MusicSource): string {
  return 'logo-apple';
}

/** Available sources (iTunes only) */
export const POPULAR_SOURCES: MusicSource[] = ['appleMusic'];
