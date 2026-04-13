/**
 * Permission Store
 *
 * Caches computed permissions per server and per channel for the current user.
 * Avoids re-computing bitfields on every render.
 *
 * Usage:
 *   const can = usePermissionStore(s => s.hasServerPermission(serverId, Permissions.MANAGE_CHANNELS))
 */
import { create } from 'zustand';
import {
  Permissions,
  computeBasePermissions,
  computeChannelPermissions,
  parsePermissions,
  hasPermission,
  ALL_PERMISSIONS,
  type RoleData,
  type PermissionOverride,
} from '../constants/permissions';

interface PermissionState {
  /**
   * Cached base permissions per server: { [serverId]: bigint }
   */
  serverPermissions: Record<string, bigint>;

  /**
   * Cached channel permissions: { [channelId]: bigint }
   */
  channelPermissions: Record<string, bigint>;

  /**
   * Member role IDs per server: { [serverId]: string[] }
   */
  memberRoles: Record<string, string[]>;

  /**
   * @everyone role ID per server
   */
  everyoneRoleIds: Record<string, string>;

  /**
   * Whether the user is the server owner
   */
  isOwner: Record<string, boolean>;

  // ── Actions ──────────────────────────────────────────────────────────────

  /**
   * Set the base permissions for a server (compute from roles).
   * Called after fetching member roles.
   */
  setServerPermissions: (
    serverId: string,
    isOwner: boolean,
    everyoneRoleId: string,
    everyonePermissions: bigint,
    memberRoleIds: string[],
    memberRolePermissions: bigint[],
  ) => void;

  /**
   * Set channel-specific permissions (apply overrides).
   */
  setChannelPermissions: (
    serverId: string,
    channelId: string,
    userId: string,
    overrides: PermissionOverride[],
  ) => void;

  /**
   * Check if the user has a specific permission at server level.
   */
  hasServerPermission: (serverId: string, permission: bigint) => boolean;

  /**
   * Check if the user has a specific permission in a channel.
   * Falls back to server-level if no channel override is cached.
   */
  hasChannelPermission: (serverId: string, channelId: string, permission: bigint) => boolean;

  /**
   * Get the raw computed bitfield for a server.
   */
  getServerPermissions: (serverId: string) => bigint;

  /**
   * Get the raw computed bitfield for a channel.
   */
  getChannelPermissions: (serverId: string, channelId: string) => bigint;

  /**
   * Clear all permissions (e.g. on logout).
   */
  clear: () => void;

  /**
   * Clear permissions for a specific server.
   */
  clearServer: (serverId: string) => void;
}

export const usePermissionStore = create<PermissionState>((set, get) => ({
  serverPermissions: {},
  channelPermissions: {},
  memberRoles: {},
  everyoneRoleIds: {},
  isOwner: {},

  setServerPermissions: (
    serverId,
    isOwner,
    everyoneRoleId,
    everyonePermissions,
    memberRoleIds,
    memberRolePermissions,
  ) => {
    const base = computeBasePermissions(isOwner, everyonePermissions, memberRolePermissions);
    set((s) => ({
      serverPermissions: { ...s.serverPermissions, [serverId]: base },
      memberRoles: { ...s.memberRoles, [serverId]: memberRoleIds },
      everyoneRoleIds: { ...s.everyoneRoleIds, [serverId]: everyoneRoleId },
      isOwner: { ...s.isOwner, [serverId]: isOwner },
    }));
  },

  setChannelPermissions: (serverId, channelId, userId, overrides) => {
    const state = get();
    const base = state.serverPermissions[serverId] ?? 0n;
    const roleIds = state.memberRoles[serverId] ?? [];
    const everyoneRoleId = state.everyoneRoleIds[serverId] ?? '';

    const channelPerms = computeChannelPermissions(
      base,
      roleIds,
      userId,
      everyoneRoleId,
      overrides,
    );

    set((s) => ({
      channelPermissions: { ...s.channelPermissions, [channelId]: channelPerms },
    }));
  },

  hasServerPermission: (serverId, permission) => {
    const perms = get().serverPermissions[serverId] ?? 0n;
    return hasPermission(perms, permission);
  },

  hasChannelPermission: (serverId, channelId, permission) => {
    const channelPerms = get().channelPermissions[channelId];
    if (channelPerms !== undefined) {
      return hasPermission(channelPerms, permission);
    }
    // Fall back to server-level perms
    const serverPerms = get().serverPermissions[serverId] ?? 0n;
    return hasPermission(serverPerms, permission);
  },

  getServerPermissions: (serverId) => {
    return get().serverPermissions[serverId] ?? 0n;
  },

  getChannelPermissions: (serverId, channelId) => {
    return get().channelPermissions[channelId] ?? get().serverPermissions[serverId] ?? 0n;
  },

  clear: () => {
    set({
      serverPermissions: {},
      channelPermissions: {},
      memberRoles: {},
      everyoneRoleIds: {},
      isOwner: {},
    });
  },

  clearServer: (serverId) => {
    set((s) => {
      const { [serverId]: _, ...restServer } = s.serverPermissions;
      const { [serverId]: __, ...restRoles } = s.memberRoles;
      const { [serverId]: ___, ...restEveryone } = s.everyoneRoleIds;
      const { [serverId]: ____, ...restOwner } = s.isOwner;
      // Remove all channel perms for this server (we'd need to track which channels belong to which server)
      return {
        serverPermissions: restServer,
        memberRoles: restRoles,
        everyoneRoleIds: restEveryone,
        isOwner: restOwner,
      };
    });
  },
}));
