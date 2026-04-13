import { supabase } from '../lib/supabase';
import { notifyMemberJoin } from './botService';
import type { Invite, Server } from '@shared/types/models';

/**
 * Invite Service
 * 
 * Handles all invite-related API operations including creating invites,
 * fetching invites, joining via invite, and managing invite expiration.
 * 
 * Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6, 18.7, 18.8
 */

export interface CreateInviteInput {
  serverId: string;
  expiresAt?: string | null;
  maxUses?: number | null;
}

export interface InviteWithServer extends Invite {
  server?: Server;
}

/**
 * Generate a unique invite code
 * 
 * Creates a random alphanumeric code for invite links.
 * 
 * @returns A unique 8-character invite code
 */
function generateInviteCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

/**
 * Check if an invite is expired
 * 
 * An invite is expired if:
 * - It has reached its max uses limit
 * - Its expiration time has passed
 * 
 * @param invite - The invite to check
 * @returns True if the invite is expired, false otherwise
 */
function isInviteExpired(invite: Invite): boolean {
  // Check if max uses reached
  if (invite.max_uses !== null && invite.uses >= invite.max_uses) {
    return true;
  }
  
  // Check if expiration time passed
  if (invite.expires_at !== null) {
    const expiresAt = new Date(invite.expires_at);
    const now = new Date();
    if (now > expiresAt) {
      return true;
    }
  }
  
  return false;
}

/**
 * Create a new invite for a server
 * 
 * Generates an invite link with optional expiration time and usage limit.
 * Only server owners or users with appropriate permissions can create invites.
 * 
 * Requirements: 18.1, 18.2, 18.3
 * 
 * @param input - Invite creation data
 * @returns The created invite
 * @throws Error if creation fails or user doesn't have permission
 */
export async function createInvite(input: CreateInviteInput): Promise<Invite> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
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

  // Validate input
  if (input.maxUses !== undefined && input.maxUses !== null) {
    if (input.maxUses < 1) {
      throw new Error('Max uses must be at least 1');
    }
  }

  if (input.expiresAt !== undefined && input.expiresAt !== null) {
    const expiresAt = new Date(input.expiresAt);
    const now = new Date();
    if (expiresAt <= now) {
      throw new Error('Expiration time must be in the future');
    }
  }

  // Generate unique invite code
  let code = generateInviteCode();
  let attempts = 0;
  const maxAttempts = 10;

  // Ensure code is unique
  while (attempts < maxAttempts) {
    const { data: existing } = await supabase
      .from('invites')
      .select('id')
      .eq('code', code)
      .single();

    if (!existing) {
      break;
    }

    code = generateInviteCode();
    attempts++;
  }

  if (attempts >= maxAttempts) {
    throw new Error('Failed to generate unique invite code');
  }

  // Create the invite
  const { data: invite, error } = await supabase
    .from('invites')
    .insert({
      server_id: input.serverId,
      code: code,
      created_by: user.id,
      expires_at: input.expiresAt || null,
      max_uses: input.maxUses || null,
      uses: 0,
    })
    .select()
    .single();

  if (error) {
    throw new Error(`Failed to create invite: ${error.message}`);
  }

  if (!invite) {
    throw new Error('Invite creation failed: No data returned');
  }

  return invite;
}

/**
 * Get all invites for a server
 * 
 * Returns all active invites with usage statistics.
 * Only server members can view invites.
 * 
 * Requirement: 18.8
 * 
 * @param serverId - The ID of the server
 * @returns Array of invites for the server
 * @throws Error if user is not authenticated or doesn't have access
 */
export async function getInvites(serverId: string): Promise<Invite[]> {
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

  // Fetch all invites for the server
  const { data, error } = await supabase
    .from('invites')
    .select('*')
    .eq('server_id', serverId)
    .order('created_at', { ascending: false });

  if (error) {
    throw new Error(`Failed to fetch invites: ${error.message}`);
  }

  return data || [];
}

/**
 * Get an invite by its code
 * 
 * Returns invite information including server details.
 * This is used when a user visits an invite link.
 * 
 * Requirement: 18.4
 * 
 * @param code - The invite code
 * @returns The invite with server information
 * @throws Error if invite not found or expired
 */
export async function getInviteByCode(code: string): Promise<InviteWithServer> {
  // Fetch the invite
  const { data: invite, error } = await supabase
    .from('invites')
    .select('*, server:servers(*)')
    .eq('code', code)
    .single();

  if (error) {
    throw new Error(`Failed to fetch invite: ${error.message}`);
  }

  if (!invite) {
    throw new Error('Invite not found');
  }

  // Check if invite is expired
  if (isInviteExpired(invite)) {
    throw new Error('This invite has expired');
  }

  return invite;
}

/**
 * Join a server via invite code
 * 
 * Adds the user as a member of the server and increments the invite usage count.
 * Marks the invite as expired if it reaches the max uses limit.
 * 
 * Requirements: 18.5, 18.6, 18.7
 * 
 * @param code - The invite code
 * @returns The server that was joined
 * @throws Error if invite is invalid, expired, or join fails
 */
export async function joinViaInvite(code: string): Promise<Server> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Fetch the invite
  const { data: invite, error: inviteError } = await supabase
    .from('invites')
    .select('*, server:servers(*)')
    .eq('code', code)
    .single();

  if (inviteError) {
    throw new Error(`Failed to fetch invite: ${inviteError.message}`);
  }

  if (!invite) {
    throw new Error('Invite not found');
  }

  // Check if invite is expired
  if (isInviteExpired(invite)) {
    throw new Error('This invite has expired');
  }

  // Check if user is already a member
  const { data: existingMember } = await supabase
    .from('server_members')
    .select('id')
    .eq('server_id', invite.server_id)
    .eq('user_id', user.id)
    .single();

  if (existingMember) {
    // User is already a member, just return the server
    return invite.server;
  }

  // Add user as a member
  const { error: memberError } = await supabase
    .from('server_members')
    .insert({
      server_id: invite.server_id,
      user_id: user.id,
    });

  if (memberError) {
    throw new Error(`Failed to join server: ${memberError.message}`);
  }

  // Notify the Go backend so bots (e.g. WelcomeBot) can react
  await notifyMemberJoin(invite.server_id);

  // Increment invite usage count
  const newUses = invite.uses + 1;
  const { error: updateError } = await supabase
    .from('invites')
    .update({ uses: newUses })
    .eq('id', invite.id);

  if (updateError) {
    // Log error but don't fail the join operation
    console.error('Failed to update invite usage count:', updateError);
  }

  return invite.server;
}

/**
 * Delete an invite
 * 
 * Removes an invite and invalidates it immediately.
 * Only server owners or users with appropriate permissions can delete invites.
 * 
 * Requirement: 18.8 (implied)
 * 
 * @param inviteId - The ID of the invite to delete
 * @throws Error if deletion fails or user doesn't have permission
 */
export async function deleteInvite(inviteId: string): Promise<void> {
  const { data: { user } } = await supabase.auth.getUser();
  
  if (!user) {
    throw new Error('User not authenticated');
  }

  // Fetch the invite to get server_id
  const { data: invite } = await supabase
    .from('invites')
    .select('server_id')
    .eq('id', inviteId)
    .single();

  if (!invite) {
    throw new Error('Invite not found');
  }

  // Check if user is the server owner
  const { data: server } = await supabase
    .from('servers')
    .select('owner_id')
    .eq('id', invite.server_id)
    .single();

  if (!server) {
    throw new Error('Server not found');
  }

  if (server.owner_id !== user.id) {
    throw new Error('Access denied: Only the server owner can delete invites');
  }

  // Delete the invite
  const { error } = await supabase
    .from('invites')
    .delete()
    .eq('id', inviteId);

  if (error) {
    throw new Error(`Failed to delete invite: ${error.message}`);
  }
}
