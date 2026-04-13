/**
 * Permission & Role Hooks
 *
 * React Query hooks for role management + a convenience hook
 * that loads permissions for the current user in a server/channel.
 */
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect } from 'react';
import * as roleService from '../services/roleService';
import { usePermissionStore } from '../stores/permissionStore';
import { useAuthStore } from '../stores/authStore';
import {
  Permissions,
  parsePermissions,
  type PermissionName,
} from '../constants/permissions';

// ─── Role Queries ──────────────────────────────────────────────────────────────

export function useServerRoles(serverId: string) {
  return useQuery({
    queryKey: ['roles', serverId],
    queryFn: () => roleService.getServerRoles(serverId),
    enabled: !!serverId,
  });
}

export function useRole(roleId: string) {
  return useQuery({
    queryKey: ['role', roleId],
    queryFn: () => roleService.getRole(roleId),
    enabled: !!roleId,
  });
}

export function useMemberRoles(serverId: string, userId: string) {
  return useQuery({
    queryKey: ['member-roles', serverId, userId],
    queryFn: () => roleService.getMemberRoles(serverId, userId),
    enabled: !!serverId && !!userId,
  });
}

export function useRoleMembers(serverId: string, roleId: string) {
  return useQuery({
    queryKey: ['role-members', serverId, roleId],
    queryFn: () => roleService.getRoleMembers(serverId, roleId),
    enabled: !!serverId && !!roleId,
  });
}

export function useChannelOverrides(channelId: string) {
  return useQuery({
    queryKey: ['channel-overrides', channelId],
    queryFn: () => roleService.getChannelOverrides(channelId),
    enabled: !!channelId,
  });
}

// ─── Role Mutations ────────────────────────────────────────────────────────────

export function useCreateRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: roleService.createRole,
    onSuccess: (_, vars) => {
      qc.invalidateQueries({ queryKey: ['roles', vars.serverId] });
    },
  });
}

export function useUpdateRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ roleId, input }: { roleId: string; input: roleService.UpdateRoleInput }) =>
      roleService.updateRole(roleId, input),
    onSuccess: (role) => {
      qc.invalidateQueries({ queryKey: ['roles', role.server_id] });
      qc.invalidateQueries({ queryKey: ['role', role.id] });
    },
  });
}

export function useDeleteRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ serverId, roleId }: { serverId: string; roleId: string }) =>
      roleService.deleteRole(roleId),
    onSuccess: (_, { serverId }) => {
      qc.invalidateQueries({ queryKey: ['roles', serverId] });
    },
  });
}

export function useAssignRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ serverId, userId, roleId }: { serverId: string; userId: string; roleId: string }) =>
      roleService.assignRole(serverId, userId, roleId),
    onSuccess: (_, { serverId, userId }) => {
      qc.invalidateQueries({ queryKey: ['member-roles', serverId, userId] });
    },
  });
}

export function useRemoveRole() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ serverId, userId, roleId }: { serverId: string; userId: string; roleId: string }) =>
      roleService.removeRoleFromMember(serverId, userId, roleId),
    onSuccess: (_, { serverId, userId }) => {
      qc.invalidateQueries({ queryKey: ['member-roles', serverId, userId] });
    },
  });
}

export function useSetChannelOverride() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      channelId,
      targetId,
      targetType,
      allow,
      deny,
    }: {
      channelId: string;
      targetId: string;
      targetType: 'role' | 'user';
      allow: bigint;
      deny: bigint;
    }) => roleService.setChannelOverride(channelId, targetId, targetType, allow, deny),
    onSuccess: (_, { channelId }) => {
      qc.invalidateQueries({ queryKey: ['channel-overrides', channelId] });
    },
  });
}

// ─── Permission Loader Hook ────────────────────────────────────────────────────

/**
 * Loads and caches the current user's permissions for a server.
 * Call this in server-level layouts to pre-compute permissions.
 *
 * Returns convenience methods: can(perm), canChannel(channelId, perm)
 */
export function usePermissions(serverId: string) {
  const user = useAuthStore((s) => s.user);
  const store = usePermissionStore();

  // Fetch roles & server info
  const { data: roles } = useServerRoles(serverId);
  const { data: memberRoles } = useMemberRoles(serverId, user?.id ?? '');

  // Fetch server owner
  const { data: server } = useQuery({
    queryKey: ['server', serverId],
    queryFn: async () => {
      const { supabase } = await import('../lib/supabase');
      const { data } = await supabase.from('servers').select('owner_id').eq('id', serverId).single();
      return data;
    },
    enabled: !!serverId,
  });

  // Compute permissions when data arrives
  useEffect(() => {
    if (!roles || !memberRoles || !server || !user) return;

    const isOwner = server.owner_id === user.id;
    const everyoneRole = roles.find((r) => r.position === 0 || r.name === '@everyone');
    const everyoneRoleId = everyoneRole?.id ?? '';
    const everyonePerms = parsePermissions(everyoneRole?.permissions);

    const userRoleIds = memberRoles.map((mr) => mr.role_id);
    const userRolePerms = memberRoles
      .map((mr) => parsePermissions(mr.role?.permissions))
      .filter((p) => p !== 0n);

    store.setServerPermissions(
      serverId,
      isOwner,
      everyoneRoleId,
      everyonePerms,
      userRoleIds,
      userRolePerms,
    );
  }, [roles, memberRoles, server, user, serverId]);

  const can = useCallback(
    (permission: bigint) => store.hasServerPermission(serverId, permission),
    [serverId, store.serverPermissions[serverId]],
  );

  const canChannel = useCallback(
    (channelId: string, permission: bigint) =>
      store.hasChannelPermission(serverId, channelId, permission),
    [serverId, store.serverPermissions[serverId], store.channelPermissions],
  );

  return {
    can,
    canChannel,
    isOwner: store.isOwner[serverId] ?? false,
    permissions: store.getServerPermissions(serverId),
    loading: !roles || !memberRoles,
  };
}
