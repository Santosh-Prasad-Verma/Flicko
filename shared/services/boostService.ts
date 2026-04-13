/**
 * Server Boost Service
 *
 * Manage server boosts and boost tiers.
 * Requirements: Feature 26 (Server Boosts)
 */
import { supabase } from '../lib/supabase';

export interface BoostTier {
  level: number;
  name: string;
  requiredBoosts: number;
  perks: string[];
}

export const BOOST_TIERS: BoostTier[] = [
  {
    level: 0,
    name: 'No Level',
    requiredBoosts: 0,
    perks: [],
  },
  {
    level: 1,
    name: 'Level 1',
    requiredBoosts: 2,
    perks: ['Custom emoji slots +50', '128 kbps audio', 'Custom invite background', 'Animated server icon'],
  },
  {
    level: 2,
    name: 'Level 2',
    requiredBoosts: 7,
    perks: ['Custom emoji slots +100', '256 kbps audio', 'Server banner', '50 MB upload limit'],
  },
  {
    level: 3,
    name: 'Level 3',
    requiredBoosts: 14,
    perks: ['Custom emoji slots +200', '384 kbps audio', 'Vanity URL', '100 MB upload limit', 'Animated banner'],
  },
];

export interface ServerBoost {
  id: string;
  server_id: string;
  user_id: string;
  started_at: string;
  user?: { id: string; username: string; avatar_url: string | null };
}

export interface BoostStatus {
  boost_count: number;
  tier: BoostTier;
  boosters: ServerBoost[];
}

export async function getBoostStatus(serverId: string): Promise<BoostStatus> {
  const { data, error } = await supabase
    .from('server_boosts')
    .select('*, user:profiles!user_id(id, username, avatar_url)')
    .eq('server_id', serverId)
    .order('started_at', { ascending: true });
  if (error) throw error;

  const boosters = data ?? [];
  const count = boosters.length;
  const tier = [...BOOST_TIERS].reverse().find((t) => count >= t.requiredBoosts) ?? BOOST_TIERS[0];

  return { boost_count: count, tier, boosters };
}

export async function boostServer(serverId: string, userId: string): Promise<ServerBoost> {
  const { data, error } = await supabase
    .from('server_boosts')
    .insert({ server_id: serverId, user_id: userId })
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function removeBoost(boostId: string) {
  const { error } = await supabase
    .from('server_boosts')
    .delete()
    .eq('id', boostId);
  if (error) throw error;
}

export function getNextTier(currentTier: BoostTier): BoostTier | null {
  const idx = BOOST_TIERS.findIndex((t) => t.level === currentTier.level);
  return idx < BOOST_TIERS.length - 1 ? BOOST_TIERS[idx + 1] : null;
}
