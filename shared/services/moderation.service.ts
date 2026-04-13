import { supabase } from '../lib/supabase';

/**
 * Moderation Service
 * 
 * Handles server moderation operations including kicking users,
 * managing bans, and retrieving ban lists.
 * 
 * Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7
 */

export interface BanUserResult {
    userId: string;
    serverId: string;
    reason?: string;
    executorId: string;
}

export interface ServerBan {
    id: string;
    server_id: string;
    user_id: string;
    reason: string | null;
    executor_id: string;
    created_at: string;
    user?: {
        username: string;
        avatar: string;
        discriminator: string;
    };
    executor?: {
        username: string;
        avatar: string;
        discriminator: string;
    };
}

/**
 * Check if the current user has permission to moderate (kick/ban)
 * Basic implementation: checks if user is server owner.
 * In a full RBAC system, this would check specific role permissions.
 * 
 * @param serverId - The server ID
 * @param userId - The current user's ID
 * @returns boolean indicating if the user has permission
 */
async function canModerateUser(serverId: string, userId: string): Promise<boolean> {
    const { data: server } = await supabase
        .from('servers')
        .select('owner_id')
        .eq('id', serverId)
        .single();

    return server?.owner_id === userId;
}

/**
 * Kick a user from a server
 * 
 * Removes the user from the server_members table.
 * 
 * @param serverId - The ID of the server
 * @param userId - The ID of the user to kick
 * @throws Error if operation fails or user lacks permission
 */
export async function kickUser(serverId: string, userId: string): Promise<void> {
    const { data: { user: currentUser } } = await supabase.auth.getUser();

    if (!currentUser) {
        throw new Error('User not authenticated');
    }

    // Cannot kick yourself through this method (use leave server instead)
    if (currentUser.id === userId) {
        throw new Error('Cannot kick yourself');
    }

    // Check permissions
    const hasPermission = await canModerateUser(serverId, currentUser.id);
    if (!hasPermission) {
        throw new Error('Access denied: You do not have permission to kick users in this server');
    }

    // Check if target user is server owner (owners cannot be kicked)
    const { data: server } = await supabase
        .from('servers')
        .select('owner_id')
        .eq('id', serverId)
        .single();

    if (server?.owner_id === userId) {
        throw new Error('Cannot kick the server owner');
    }

    // Perform the kick
    const { error } = await supabase
        .from('server_members')
        .delete()
        .eq('server_id', serverId)
        .eq('user_id', userId);

    if (error) {
        throw new Error(`Failed to kick user: ${error.message}`);
    }
}

/**
 * Ban a user from a server
 * 
 * Adds the user to the server_bans table and removes them from server_members.
 * 
 * @param serverId - The ID of the server
 * @param userId - The ID of the user to ban
 * @param reason - Optional reason for the ban
 * @returns Ban information
 * @throws Error if operation fails or user lacks permission
 */
export async function banUser(serverId: string, userId: string, reason?: string): Promise<BanUserResult> {
    const { data: { user: currentUser } } = await supabase.auth.getUser();

    if (!currentUser) {
        throw new Error('User not authenticated');
    }

    if (currentUser.id === userId) {
        throw new Error('Cannot ban yourself');
    }

    // Check permissions
    const hasPermission = await canModerateUser(serverId, currentUser.id);
    if (!hasPermission) {
        throw new Error('Access denied: You do not have permission to ban users in this server');
    }

    // Check if target user is server owner
    const { data: server } = await supabase
        .from('servers')
        .select('owner_id')
        .eq('id', serverId)
        .single();

    if (server?.owner_id === userId) {
        throw new Error('Cannot ban the server owner');
    }

    // Add ban record
    const { error: banError } = await supabase
        .from('server_bans')
        .insert({
            server_id: serverId,
            user_id: userId,
            reason: reason || null,
            executor_id: currentUser.id,
        });

    if (banError && !banError.message.includes('duplicate key')) {
        throw new Error(`Failed to ban user: ${banError.message}`);
    }

    // Also remove from server members (kick)
    // We ignore errors here in case they were already not a member
    await supabase
        .from('server_members')
        .delete()
        .eq('server_id', serverId)
        .eq('user_id', userId);

    return {
        userId,
        serverId,
        reason,
        executorId: currentUser.id,
    };
}

/**
 * Unban a user from a server
 * 
 * Removes the user from the server_bans table.
 * 
 * @param serverId - The ID of the server
 * @param userId - The ID of the user to unban
 * @throws Error if operation fails or user lacks permission
 */
export async function unbanUser(serverId: string, userId: string): Promise<void> {
    const { data: { user: currentUser } } = await supabase.auth.getUser();

    if (!currentUser) {
        throw new Error('User not authenticated');
    }

    // Check permissions
    const hasPermission = await canModerateUser(serverId, currentUser.id);
    if (!hasPermission) {
        throw new Error('Access denied: You do not have permission to unban users in this server');
    }

    // Remove ban record
    const { error } = await supabase
        .from('server_bans')
        .delete()
        .eq('server_id', serverId)
        .eq('user_id', userId);

    if (error) {
        throw new Error(`Failed to unban user: ${error.message}`);
    }
}

/**
 * Get all bans for a server
 * 
 * @param serverId - The ID of the server
 * @returns Array of server bans with user info
 * @throws Error if operation fails or user lacks permission
 */
export async function getBans(serverId: string): Promise<ServerBan[]> {
    const { data: { user: currentUser } } = await supabase.auth.getUser();

    if (!currentUser) {
        throw new Error('User not authenticated');
    }

    // Check permissions
    const hasPermission = await canModerateUser(serverId, currentUser.id);
    if (!hasPermission) {
        throw new Error('Access denied: You do not have permission to view bans in this server');
    }

    // Fetch bans with user and executor profiles
    // Note: Depending on RLS policies and foreign key relations, this join might need adjustment
    const { data, error } = await supabase
        .from('server_bans')
        .select(`
      *,
      user:profiles!server_bans_user_id_fkey(username, avatar, discriminator),
      executor:profiles!server_bans_executor_id_fkey(username, avatar, discriminator)
    `)
        .eq('server_id', serverId)
        .order('created_at', { ascending: false });

    if (error) {
        throw new Error(`Failed to fetch bans: ${error.message}`);
    }

    return data as unknown as ServerBan[];
}
