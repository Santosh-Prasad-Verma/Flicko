/**
 * Flicko Permission System — Discord-compatible Bitfield
 *
 * Each permission is a single bit in a 64-bit integer (BigInt).
 * This mirrors Discord's permission system exactly, allowing:
 * - 40+ granular permissions organized by category
 * - Role stacking via bitwise OR
 * - Channel overrides via allow/deny bit pairs
 * - Administrator bypass
 *
 * Reference: Discord Developer Portal — Permissions
 */

// ─── Bitfield Constants ────────────────────────────────────────────────────────

export const Permissions = {
  // General
  CREATE_INSTANT_INVITE: 1n << 0n,
  KICK_MEMBERS:          1n << 1n,
  BAN_MEMBERS:           1n << 2n,
  ADMINISTRATOR:         1n << 3n,
  MANAGE_CHANNELS:       1n << 4n,
  MANAGE_GUILD:          1n << 5n,
  ADD_REACTIONS:         1n << 6n,
  VIEW_AUDIT_LOG:        1n << 7n,
  PRIORITY_SPEAKER:      1n << 8n,
  STREAM:                1n << 9n,
  VIEW_CHANNEL:          1n << 10n,

  // Text
  SEND_MESSAGES:             1n << 11n,
  SEND_TTS_MESSAGES:         1n << 12n,
  MANAGE_MESSAGES:           1n << 13n,
  EMBED_LINKS:               1n << 14n,
  ATTACH_FILES:              1n << 15n,
  READ_MESSAGE_HISTORY:      1n << 16n,
  MENTION_EVERYONE:          1n << 17n,
  USE_EXTERNAL_EMOJIS:       1n << 18n,
  VIEW_GUILD_INSIGHTS:       1n << 19n,

  // Voice
  CONNECT:           1n << 20n,
  SPEAK:             1n << 21n,
  MUTE_MEMBERS:      1n << 22n,
  DEAFEN_MEMBERS:    1n << 23n,
  MOVE_MEMBERS:      1n << 24n,
  USE_VAD:           1n << 25n,

  // Membership
  CHANGE_NICKNAME:   1n << 26n,
  MANAGE_NICKNAMES:  1n << 27n,
  MANAGE_ROLES:      1n << 28n,
  MANAGE_WEBHOOKS:   1n << 29n,
  MANAGE_EMOJIS_AND_STICKERS: 1n << 30n,

  // Advanced
  USE_APPLICATION_COMMANDS:   1n << 31n,
  REQUEST_TO_SPEAK:           1n << 32n,
  MANAGE_EVENTS:              1n << 33n,
  MANAGE_THREADS:             1n << 34n,
  CREATE_PUBLIC_THREADS:      1n << 35n,
  CREATE_PRIVATE_THREADS:     1n << 36n,
  USE_EXTERNAL_STICKERS:      1n << 37n,
  SEND_MESSAGES_IN_THREADS:   1n << 38n,
  USE_EMBEDDED_ACTIVITIES:    1n << 39n,
  MODERATE_MEMBERS:           1n << 40n,

  // Flicko-specific
  BYPASS_SLOWMODE:            1n << 41n,
  USE_SOUNDBOARD:             1n << 42n,
  VIEW_CREATOR_MONETIZATION:  1n << 43n,

  // Video & Streaming (Flicko Session 6)
  VIDEO:                      1n << 44n,  // Can use camera in voice channels
  USE_ACTIVITIES:             1n << 45n,  // Can use Activities in voice channels
} as const;

export type PermissionName = keyof typeof Permissions;

// ─── Preset Bundles ────────────────────────────────────────────────────────────

/** All bits set */
export const ALL_PERMISSIONS = Object.values(Permissions).reduce((a, b) => a | b, 0n);

/** Reasonable defaults for @everyone role */
export const DEFAULT_EVERYONE_PERMISSIONS =
  Permissions.CREATE_INSTANT_INVITE |
  Permissions.ADD_REACTIONS |
  Permissions.STREAM |
  Permissions.VIEW_CHANNEL |
  Permissions.SEND_MESSAGES |
  Permissions.EMBED_LINKS |
  Permissions.ATTACH_FILES |
  Permissions.READ_MESSAGE_HISTORY |
  Permissions.USE_EXTERNAL_EMOJIS |
  Permissions.CONNECT |
  Permissions.SPEAK |
  Permissions.USE_VAD |
  Permissions.CHANGE_NICKNAME |
  Permissions.USE_APPLICATION_COMMANDS |
  Permissions.CREATE_PUBLIC_THREADS |
  Permissions.SEND_MESSAGES_IN_THREADS |
  Permissions.VIDEO;

/** Moderator preset */
export const MODERATOR_PRESET =
  DEFAULT_EVERYONE_PERMISSIONS |
  Permissions.KICK_MEMBERS |
  Permissions.BAN_MEMBERS |
  Permissions.MANAGE_MESSAGES |
  Permissions.MANAGE_THREADS |
  Permissions.MENTION_EVERYONE |
  Permissions.MUTE_MEMBERS |
  Permissions.DEAFEN_MEMBERS |
  Permissions.MOVE_MEMBERS |
  Permissions.MANAGE_NICKNAMES |
  Permissions.MODERATE_MEMBERS |
  Permissions.VIEW_AUDIT_LOG |
  Permissions.BYPASS_SLOWMODE;

/** Admin preset (almost everything, minus destructive) */
export const ADMIN_PRESET =
  ALL_PERMISSIONS & ~Permissions.ADMINISTRATOR;

// ─── Permission Categories (for UI grouping) ──────────────────────────────────

export interface PermissionMeta {
  name: PermissionName;
  label: string;
  description: string;
  category: 'general' | 'membership' | 'text' | 'voice' | 'advanced';
  dangerous?: boolean;
}

export const PERMISSION_DEFINITIONS: PermissionMeta[] = [
  // General
  { name: 'VIEW_CHANNEL', label: 'View Channels', description: 'Allows members to view channels by default', category: 'general' },
  { name: 'MANAGE_CHANNELS', label: 'Manage Channels', description: 'Create, edit, or delete channels', category: 'general', dangerous: true },
  { name: 'MANAGE_ROLES', label: 'Manage Roles', description: 'Create, edit, or delete roles lower than their highest role', category: 'general', dangerous: true },
  { name: 'MANAGE_EMOJIS_AND_STICKERS', label: 'Manage Expressions', description: 'Manage emojis, stickers, and soundboard sounds', category: 'general' },
  { name: 'VIEW_AUDIT_LOG', label: 'View Audit Log', description: 'View the server audit log', category: 'general' },
  { name: 'MANAGE_WEBHOOKS', label: 'Manage Webhooks', description: 'Create, edit, or delete webhooks', category: 'general' },
  { name: 'MANAGE_GUILD', label: 'Manage Server', description: 'Edit server name, icon, and other settings', category: 'general', dangerous: true },
  { name: 'MANAGE_EVENTS', label: 'Manage Events', description: 'Create, edit, or delete scheduled events', category: 'general' },
  { name: 'VIEW_GUILD_INSIGHTS', label: 'View Server Insights', description: 'View server analytics', category: 'general' },
  { name: 'ADMINISTRATOR', label: 'Administrator', description: 'Members with this permission have every permission and bypass channel-specific permissions', category: 'general', dangerous: true },

  // Membership
  { name: 'CREATE_INSTANT_INVITE', label: 'Create Invite', description: 'Create invites to this server', category: 'membership' },
  { name: 'CHANGE_NICKNAME', label: 'Change Nickname', description: 'Change their own nickname', category: 'membership' },
  { name: 'MANAGE_NICKNAMES', label: 'Manage Nicknames', description: 'Change nicknames of other members', category: 'membership' },
  { name: 'KICK_MEMBERS', label: 'Kick Members', description: 'Remove members from this server', category: 'membership', dangerous: true },
  { name: 'BAN_MEMBERS', label: 'Ban Members', description: 'Permanently ban members from this server', category: 'membership', dangerous: true },
  { name: 'MODERATE_MEMBERS', label: 'Timeout Members', description: 'Timeout members, preventing them from sending messages or joining voice', category: 'membership', dangerous: true },

  // Text
  { name: 'SEND_MESSAGES', label: 'Send Messages', description: 'Send messages in text channels', category: 'text' },
  { name: 'SEND_MESSAGES_IN_THREADS', label: 'Send Messages in Threads', description: 'Send messages in threads', category: 'text' },
  { name: 'CREATE_PUBLIC_THREADS', label: 'Create Public Threads', description: 'Create public threads', category: 'text' },
  { name: 'CREATE_PRIVATE_THREADS', label: 'Create Private Threads', description: 'Create private threads', category: 'text' },
  { name: 'EMBED_LINKS', label: 'Embed Links', description: 'Links will auto-embed when sent', category: 'text' },
  { name: 'ATTACH_FILES', label: 'Attach Files', description: 'Upload files and images', category: 'text' },
  { name: 'ADD_REACTIONS', label: 'Add Reactions', description: 'Add reactions to messages', category: 'text' },
  { name: 'USE_EXTERNAL_EMOJIS', label: 'Use External Emojis', description: 'Use emojis from other servers', category: 'text' },
  { name: 'USE_EXTERNAL_STICKERS', label: 'Use External Stickers', description: 'Use stickers from other servers', category: 'text' },
  { name: 'MENTION_EVERYONE', label: 'Mention @everyone', description: 'Send @everyone and @here mentions', category: 'text', dangerous: true },
  { name: 'MANAGE_MESSAGES', label: 'Manage Messages', description: 'Delete or pin messages from other members', category: 'text', dangerous: true },
  { name: 'MANAGE_THREADS', label: 'Manage Threads', description: 'Rename, delete, close, and manage threads', category: 'text' },
  { name: 'READ_MESSAGE_HISTORY', label: 'Read Message History', description: 'Read previous messages sent in channels', category: 'text' },
  { name: 'SEND_TTS_MESSAGES', label: 'Send TTS Messages', description: 'Send text-to-speech messages', category: 'text' },
  { name: 'USE_APPLICATION_COMMANDS', label: 'Use Application Commands', description: 'Use slash commands and context menu commands', category: 'text' },
  { name: 'BYPASS_SLOWMODE', label: 'Bypass Slowmode', description: 'Bypass channel slowmode restrictions', category: 'text' },

  // Voice
  { name: 'CONNECT', label: 'Connect', description: 'Connect to voice channels', category: 'voice' },
  { name: 'SPEAK', label: 'Speak', description: 'Speak in voice channels', category: 'voice' },
  { name: 'STREAM', label: 'Video', description: 'Share video or screen in voice channels', category: 'voice' },
  { name: 'USE_VAD', label: 'Use Voice Activity', description: 'Use voice-activity-detection instead of push-to-talk', category: 'voice' },
  { name: 'PRIORITY_SPEAKER', label: 'Priority Speaker', description: 'Be heard more easily when speaking with others', category: 'voice' },
  { name: 'MUTE_MEMBERS', label: 'Mute Members', description: 'Mute other members in voice channels', category: 'voice', dangerous: true },
  { name: 'DEAFEN_MEMBERS', label: 'Deafen Members', description: 'Deafen other members in voice channels', category: 'voice', dangerous: true },
  { name: 'MOVE_MEMBERS', label: 'Move Members', description: 'Move members between voice channels', category: 'voice', dangerous: true },
  { name: 'USE_SOUNDBOARD', label: 'Use Soundboard', description: 'Use soundboard in voice channels', category: 'voice' },
  { name: 'REQUEST_TO_SPEAK', label: 'Request to Speak', description: 'Request to speak in stage channels', category: 'voice' },

  // Advanced
  { name: 'USE_EMBEDDED_ACTIVITIES', label: 'Use Activities', description: 'Use Activities in voice channels', category: 'advanced' },
  { name: 'VIEW_CREATOR_MONETIZATION', label: 'View Monetization', description: 'View creator monetization analytics', category: 'advanced' },

  // Video & Streaming (Session 6)
  { name: 'VIDEO', label: 'Use Camera', description: 'Turn on camera in voice channels', category: 'voice' },
  { name: 'USE_ACTIVITIES', label: 'Use Voice Activities', description: 'Use Activities in voice channels', category: 'voice' },
];

// ─── Utility Functions ─────────────────────────────────────────────────────────

/**
 * Check if a permission set contains a specific permission.
 * Administrator always returns true.
 */
export function hasPermission(permissionBits: bigint, permission: bigint): boolean {
  if ((permissionBits & Permissions.ADMINISTRATOR) === Permissions.ADMINISTRATOR) return true;
  return (permissionBits & permission) === permission;
}

/**
 * Check multiple permissions (AND — all must be present).
 */
export function hasAllPermissions(permissionBits: bigint, ...perms: bigint[]): boolean {
  if ((permissionBits & Permissions.ADMINISTRATOR) === Permissions.ADMINISTRATOR) return true;
  return perms.every((p) => (permissionBits & p) === p);
}

/**
 * Check any of the permissions (OR — at least one present).
 */
export function hasAnyPermission(permissionBits: bigint, ...perms: bigint[]): boolean {
  if ((permissionBits & Permissions.ADMINISTRATOR) === Permissions.ADMINISTRATOR) return true;
  return perms.some((p) => (permissionBits & p) === p);
}

/**
 * Add a permission to a bitfield.
 */
export function addPermission(permissionBits: bigint, permission: bigint): bigint {
  return permissionBits | permission;
}

/**
 * Remove a permission from a bitfield.
 */
export function removePermission(permissionBits: bigint, permission: bigint): bigint {
  return permissionBits & ~permission;
}

/**
 * Toggle a permission in a bitfield.
 */
export function togglePermission(permissionBits: bigint, permission: bigint): bigint {
  return permissionBits ^ permission;
}

/**
 * Convert a BigInt permissions value to a JSON-safe numeric string.
 * Supabase stores BIGINT as string in JSON responses.
 */
export function permissionsToString(perms: bigint): string {
  return perms.toString();
}

/**
 * Parse a permissions value from a DB string/number to BigInt.
 */
export function parsePermissions(value: string | number | bigint | null | undefined): bigint {
  if (value === null || value === undefined) return 0n;
  if (typeof value === 'bigint') return value;
  try {
    return BigInt(value);
  } catch {
    return 0n;
  }
}

// ─── Permission Calculation ────────────────────────────────────────────────────

export interface RoleData {
  id: string;
  permissions: string | number | bigint;
  position: number;
}

export interface PermissionOverride {
  target_id: string;
  target_type: 'role' | 'user';
  allow: string | number | bigint;
  deny: string | number | bigint;
}

/**
 * Compute the effective permissions for a member in a server.
 *
 * Algorithm (matches Discord):
 * 1. Start with @everyone role permissions
 * 2. OR in all the user's role permissions
 * 3. If ADMINISTRATOR, return ALL
 */
export function computeBasePermissions(
  isOwner: boolean,
  everyonePermissions: bigint,
  memberRolePermissions: bigint[],
): bigint {
  // Server owner has everything
  if (isOwner) return ALL_PERMISSIONS;

  let perms = everyonePermissions;
  for (const rolePerm of memberRolePermissions) {
    perms |= rolePerm;
  }

  // Admin bypass
  if ((perms & Permissions.ADMINISTRATOR) === Permissions.ADMINISTRATOR) {
    return ALL_PERMISSIONS;
  }

  return perms;
}

/**
 * Apply channel-specific overrides to base permissions.
 *
 * Algorithm:
 * 1. Apply @everyone channel overrides
 * 2. Apply role overrides (OR all allows, OR all denies)
 * 3. Apply user-specific override
 * 4. Result = (base & ~deny) | allow
 */
export function computeChannelPermissions(
  basePermissions: bigint,
  memberRoleIds: string[],
  userId: string,
  everyoneRoleId: string,
  overrides: PermissionOverride[],
): bigint {
  // Admin bypass — channel overrides don't apply
  if ((basePermissions & Permissions.ADMINISTRATOR) === Permissions.ADMINISTRATOR) {
    return ALL_PERMISSIONS;
  }

  let perms = basePermissions;

  // 1. @everyone channel override
  const everyoneOverride = overrides.find(
    (o) => o.target_type === 'role' && o.target_id === everyoneRoleId,
  );
  if (everyoneOverride) {
    const allow = parsePermissions(everyoneOverride.allow);
    const deny = parsePermissions(everyoneOverride.deny);
    perms = (perms & ~deny) | allow;
  }

  // 2. Role overrides
  let roleAllow = 0n;
  let roleDeny = 0n;
  for (const override of overrides) {
    if (override.target_type === 'role' && override.target_id !== everyoneRoleId) {
      if (memberRoleIds.includes(override.target_id)) {
        roleAllow |= parsePermissions(override.allow);
        roleDeny |= parsePermissions(override.deny);
      }
    }
  }
  perms = (perms & ~roleDeny) | roleAllow;

  // 3. User-specific override (highest priority)
  const userOverride = overrides.find(
    (o) => o.target_type === 'user' && o.target_id === userId,
  );
  if (userOverride) {
    const allow = parsePermissions(userOverride.allow);
    const deny = parsePermissions(userOverride.deny);
    perms = (perms & ~deny) | allow;
  }

  return perms;
}

/**
 * List all permission names that are set in a bitfield.
 */
export function listPermissions(permissionBits: bigint): PermissionName[] {
  const result: PermissionName[] = [];
  for (const [name, bit] of Object.entries(Permissions)) {
    if ((permissionBits & (bit as bigint)) === (bit as bigint)) {
      result.push(name as PermissionName);
    }
  }
  return result;
}
