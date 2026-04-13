import { supabase } from '../lib/supabase';
import type { Channel } from '@shared/types/models';

/**
 * Channel Service
 * 
 * Handles all channel-related API operations including CRUD operations
 * for channels in the Flicko application.
 * 
 * Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7
 */

export interface CreateChannelInput {
  serverId: string;
  name: string;
  type?: 'text' | 'voice' | 'announcement' | 'forum' | 'category' | 'stage';
  topic?: string | null;
  nsfw?: boolean;
  parentId?: string | null; // category ID
  slowmodeSeconds?: number;
}

export interface UpdateChannelInput {
  name?: string;
  topic?: string | null;
  nsfw?: boolean;
  position?: number;
  parentId?: string | null;
  slowmodeSeconds?: number;
}

/**
 * Get all channels for a specific server
 * 
 * @param serverId - The ID of the server
 * @returns Array of channels ordered by position
 * @throws Error if user is not authenticated or doesn't have access
 */
export async function getChannels(serverId: string): Promise<Channel[]> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Check if user is a member of the server
  const { data: membership } = await supabase
    .from('server_members')
    .select('id')
    .eq('server_id', serverId)
    .eq('user_id', user.id)
    .single();

  if (!membership) {
    throw new Error('Access denied: User is not a member of this server');
  }

  // Fetch channels ordered by position
  const { data, error } = await supabase
    .from('channels')
    .select('*')
    .eq('server_id', serverId)
    .order('position', { ascending: true });

  if (error) {
    throw new Error(`Failed to fetch channels: ${error.message}`);
  }

  return data || [];
}

/**
 * Get a single channel by ID
 * 
 * @param channelId - The ID of the channel to fetch
 * @returns The channel object
 * @throws Error if channel not found or user doesn't have access
 */
export async function getChannel(channelId: string): Promise<Channel> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Fetch the channel
  const { data: channel, error: channelError } = await supabase
    .from('channels')
    .select('*')
    .eq('id', channelId)
    .single();

  if (channelError) {
    throw new Error(`Failed to fetch channel: ${channelError.message}`);
  }

  if (!channel) {
    throw new Error('Channel not found');
  }

  // Check if user is a member of the server
  const { data: membership } = await supabase
    .from('server_members')
    .select('id')
    .eq('server_id', channel.server_id)
    .eq('user_id', user.id)
    .single();

  if (!membership) {
    throw new Error('Access denied: User is not a member of this server');
  }

  return channel;
}

/**
 * Create a new channel in a server
 * 
 * Automatically assigns the next available position value.
 * 
 * @param input - Channel creation data
 * @returns The created channel
 * @throws Error if creation fails or user doesn't have permission
 */
export async function createChannel(input: CreateChannelInput): Promise<Channel> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Validate channel name
  if (!input.name || input.name.trim().length === 0) {
    throw new Error('Channel name is required');
  }

  if (input.name.length > 100) {
    throw new Error('Channel name must be 100 characters or less');
  }

  // Check if user is a member of the server
  const { data: membership } = await supabase
    .from('server_members')
    .select('id')
    .eq('server_id', input.serverId)
    .eq('user_id', user.id)
    .single();

  if (!membership) {
    throw new Error('Access denied: User is not a member of this server');
  }

  // Get the highest position value for channels in this server
  const { data: existingChannels } = await supabase
    .from('channels')
    .select('position')
    .eq('server_id', input.serverId)
    .order('position', { ascending: false })
    .limit(1);

  const nextPosition = existingChannels && existingChannels.length > 0
    ? existingChannels[0].position + 1
    : 0;

  // Create the channel
  const { data: channel, error } = await supabase
    .from('channels')
    .insert({
      server_id: input.serverId,
      name: input.name.trim(),
      type: input.type || 'text',
      topic: input.topic || null,
      nsfw: input.nsfw || false,
      position: nextPosition,
      parent_id: input.parentId || null,
      slowmode_seconds: input.slowmodeSeconds || 0,
    })
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to create channel: ${error.message}`);
  }

  if (!channel) {
    throw new Error('Channel creation failed: No data returned');
  }

  return channel;
}

/**
 * Update a channel
 * 
 * Users with appropriate permissions can update channel details.
 * 
 * @param channelId - The ID of the channel to update
 * @param input - Channel update data
 * @returns The updated channel
 * @throws Error if update fails or user doesn't have permission
 */
export async function updateChannel(
  channelId: string,
  input: UpdateChannelInput
): Promise<Channel> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Fetch the channel to get server_id
  const { data: channel } = await supabase
    .from('channels')
    .select('server_id')
    .eq('id', channelId)
    .single();

  if (!channel) {
    throw new Error('Channel not found');
  }

  // Check if user is a member of the server
  const { data: membership } = await supabase
    .from('server_members')
    .select('id')
    .eq('server_id', channel.server_id)
    .eq('user_id', user.id)
    .single();

  if (!membership) {
    throw new Error('Access denied: User is not a member of this server');
  }

  // Validate input
  if (input.name !== undefined) {
    if (!input.name || input.name.trim().length === 0) {
      throw new Error('Channel name cannot be empty');
    }
    if (input.name.length > 100) {
      throw new Error('Channel name must be 100 characters or less');
    }
  }

  // Build update object
  const updateData: Partial<Channel> = {};
  if (input.name !== undefined) updateData.name = input.name.trim();
  if (input.topic !== undefined) updateData.topic = input.topic;
  if (input.nsfw !== undefined) updateData.nsfw = input.nsfw;
  if (input.position !== undefined) updateData.position = input.position;

  // Update the channel
  const { data, error } = await supabase
    .from('channels')
    .update(updateData)
    .eq('id', channelId)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to update channel: ${error.message}`);
  }

  if (!data) {
    throw new Error('Channel update failed: No data returned');
  }

  return data;
}

/**
 * Delete a channel
 * 
 * Users with appropriate permissions can delete channels.
 * This will cascade delete all messages in the channel.
 * 
 * @param channelId - The ID of the channel to delete
 * @throws Error if deletion fails or user doesn't have permission
 */
export async function deleteChannel(channelId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Fetch the channel to get server_id
  const { data: channel } = await supabase
    .from('channels')
    .select('server_id')
    .eq('id', channelId)
    .single();

  if (!channel) {
    throw new Error('Channel not found');
  }

  // Check if user is a member of the server
  const { data: membership } = await supabase
    .from('server_members')
    .select('id')
    .eq('server_id', channel.server_id)
    .eq('user_id', user.id)
    .single();

  if (!membership) {
    throw new Error('Access denied: User is not a member of this server');
  }

  // Delete the channel (cascade will handle messages)
  const { error } = await supabase
    .from('channels')
    .delete()
    .eq('id', channelId);

  if (error) {
    throw new Error(`Failed to delete channel: ${error.message}`);
  }
}
