import { supabase } from '../lib/supabase';
import type { Server } from '@shared/types/models';

/**
 * Server Service
 * 
 * Handles all server-related API operations including CRUD operations
 * for servers in the Flicko application.
 * 
 * Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8
 */

export interface CreateServerInput {
  name: string;
  description?: string | null;
  icon?: string | null;
}

export interface UpdateServerInput {
  name?: string;
  description?: string | null;
  icon?: string | null;
}

export interface ServerServiceError {
  message: string;
  code?: string;
  details?: unknown;
}

/**
 * Get all servers for the authenticated user
 * 
 * MED-024: Uses a single joined query instead of two-query waterfall.
 * 
 * @returns Array of servers the user is a member of
 * @throws Error if user is not authenticated or query fails
 */
export async function getServers(): Promise<Server[]> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // MED-024: Single query with join — replaces two-step member→server fetch
  const { data, error } = await supabase
    .from('server_members')
    .select('server:servers(*)')
    .eq('user_id', user.id)
    .order('created_at', { ascending: true });

  if (error) {
    throw new Error(`Failed to fetch servers: ${error.message}`);
  }

  if (!data || data.length === 0) {
    return [];
  }

  return data
    .map((row: any) => row.server)
    .filter((server: Server | null): server is Server => Boolean(server));
}

/**
 * Get a single server by ID
 * 
 * @param serverId - The ID of the server to fetch
 * @returns The server object
 * @throws Error if server not found or user doesn't have access
 */
export async function getServer(serverId: string): Promise<Server> {
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

  const { data, error } = await supabase
    .from('servers')
    .select('*')
    .eq('id', serverId)
    .single();

  if (error) {
    throw new Error(`Failed to fetch server: ${error.message}`);
  }

  if (!data) {
    throw new Error('Server not found');
  }

  return data;
}

/**
 * Create a new server
 * 
 * Creates a server and automatically adds the creator as owner and member.
 * Also creates a default "general" text channel.
 * 
 * @param input - Server creation data
 * @returns The created server
 * @throws Error if creation fails or user is not authenticated
 */
export async function createServer(input: CreateServerInput): Promise<Server> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Validate server name
  if (!input.name || input.name.trim().length === 0) {
    throw new Error('Server name is required');
  }

  if (input.name.length > 100) {
    throw new Error('Server name must be 100 characters or less');
  }

  // Create the server
  const { data: server, error: serverError } = await supabase
    .from('servers')
    .insert({
      name: input.name.trim(),
      description: input.description || null,
      icon: input.icon || null,
      owner_id: user.id,
    })
    .select()
    .single();

  if (serverError) {
    throw new Error(`Failed to create server: ${serverError.message}`);
  }

  if (!server) {
    throw new Error('Server creation failed: No data returned');
  }

  // Add creator as a member
  const { error: memberError } = await supabase
    .from('server_members')
    .insert({
      server_id: server.id,
      user_id: user.id,
    });

  if (memberError) {
    // Rollback: delete the server if member creation fails
    await supabase.from('servers').delete().eq('id', server.id);
    throw new Error(`Failed to add user as member: ${memberError.message}`);
  }

  // Create default "general" channel
  const { error: channelError } = await supabase
    .from('channels')
    .insert({
      server_id: server.id,
      name: 'general',
      type: 'text',
      position: 0,
    });

  if (channelError) {
    // Rollback: delete the server if channel creation fails
    await supabase.from('servers').delete().eq('id', server.id);
    throw new Error(`Failed to create default channel: ${channelError.message}`);
  }

  return server;
}

/**
 * Update a server
 * 
 * Only the server owner can update server details.
 * 
 * @param serverId - The ID of the server to update
 * @param input - Server update data
 * @returns The updated server
 * @throws Error if update fails or user is not the owner
 */
export async function updateServer(
  serverId: string,
  input: UpdateServerInput
): Promise<Server> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Check if user is the owner
  const { data: server } = await supabase
    .from('servers')
    .select('owner_id')
    .eq('id', serverId)
    .single();

  if (!server) {
    throw new Error('Server not found');
  }

  if (server.owner_id !== user.id) {
    throw new Error('Access denied: Only the server owner can update the server');
  }

  // Validate input
  if (input.name !== undefined) {
    if (!input.name || input.name.trim().length === 0) {
      throw new Error('Server name cannot be empty');
    }
    if (input.name.length > 100) {
      throw new Error('Server name must be 100 characters or less');
    }
  }

  // Build update object
  const updateData: Partial<Server> = {};
  if (input.name !== undefined) updateData.name = input.name.trim();
  if (input.description !== undefined) updateData.description = input.description;
  if (input.icon !== undefined) updateData.icon = input.icon;

  // Update the server
  const { data, error } = await supabase
    .from('servers')
    .update(updateData)
    .eq('id', serverId)
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to update server: ${error.message}`);
  }

  if (!data) {
    throw new Error('Server update failed: No data returned');
  }

  return data;
}

/**
 * Delete a server
 * 
 * Only the server owner can delete a server.
 * This will cascade delete all channels, messages, and memberships.
 * 
 * @param serverId - The ID of the server to delete
 * @throws Error if deletion fails or user is not the owner
 */
export async function deleteServer(serverId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Check if user is the owner
  const { data: server } = await supabase
    .from('servers')
    .select('owner_id')
    .eq('id', serverId)
    .single();

  if (!server) {
    throw new Error('Server not found');
  }

  if (server.owner_id !== user.id) {
    throw new Error('Access denied: Only the server owner can delete the server');
  }

  // Delete the server (cascade will handle channels, messages, and memberships)
  const { error } = await supabase
    .from('servers')
    .delete()
    .eq('id', serverId);

  if (error) {
    throw new Error(`Failed to delete server: ${error.message}`);
  }
}
