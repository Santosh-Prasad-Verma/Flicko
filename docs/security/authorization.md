# Authorization (RBAC)

> **Reading time:** ~10 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

This document explains exactly how the Go backend determines if user **A** is allowed to perform action **X** on resource **Y**, utilizing a highly efficient bitwise Role-Based Access Control (RBAC) system.

---

## 1. Identity vs. Authorization

**Identity (Authentication)**: "Who are you?" -> Answered by Supabase Auth JWT checking.
**Authorization**: "What are you allowed to do?" -> Answered by the Go Monolith logic.

---

## 2. The 26 Permissions bitfield

Flicko represents a user's permissions as a single `uint64` (unsigned 64-bit integer tracker).

```go
const (
    ViewChannel        uint64 = 1 << 0  // 1
    SendMessages       uint64 = 1 << 1  // 2
    AddReactions       uint64 = 1 << 2  // 4
    ManageMessages     uint64 = 1 << 6  // 64
    KickMembers        uint64 = 1 << 14 // 16384
    BanMembers         uint64 = 1 << 15 // 32768
    ManageRoles        uint64 = 1 << 18 // 262144
    Administrator      uint64 = 1 << 25 // 33554432
)
```

By storing permissions as bits within an integer, we can calculate complex hierarchies instantly using bitwise operators (`&`, `|`, `~`), requiring just a few CPU cycles rather than looping through string arrays.

---

## 3. Resolving Contextual Permissions

A user's permission set changes drastically contextually. They could be an `ADMINISTRATOR` in Server A, but only have `SEND_MESSAGES` in Server B, and be completely blocked from `#announcements` in Server B.

The `backend/internal/services/permissions.go` file acts as the universal calculator.

### The Resolution Algorithm

```go
func (s *PermissionService) ComputePermissions(ctx context.Context, userID, serverID, channelID uuid.UUID) (uint64, error) {
    // 1. Fetch user's server roles
    roles := s.GetRolesForUser(serverID, userID)
    
    // 2. Fetch server owner
    server := s.GetServer(serverID)
    if server.OwnerID == userID {
        return permissions.All, nil // Owners bypass everything
    }

    // 3. Calculate Base Permissions (Bitwise OR across all roles)
    var basePerms uint64 = 0
    for _, r := range roles {
        basePerms |= r.Permissions
    }

    // 4. Admin shortcut
    if (basePerms & permissions.Administrator) == permissions.Administrator {
        return permissions.All, nil
    }

    // 5. Apply Channel Overwrites (if channel is specified)
    if channelID != uuid.Nil {
        overwrites := s.GetOverwritesForChannel(channelID)
        
        // Remove explicitly denied bits first
        for _, ow := range overwrites {
            if isTarget(ow, userID, roles) {
                basePerms &= ^ow.DenyBits
            }
        }
        
        // Add explicitly allowed bits securely
        for _, ow := range overwrites {
            if isTarget(ow, userID, roles) {
                basePerms |= ow.AllowBits
            }
        }
    }

    return basePerms, nil
}
```

---

## 4. Enforcement in the Controllers

When a user triggers an API, the Handler checks this computed integer algebraically.

Example: **Kicking a user**

```go
func (h *ModHandler) HandleKick(w http.ResponseWriter, r *http.Request) {
    // ... extract IDs ...
    
    // Calculate what the caller is allowed to do in this server
    perms, err := h.permSvc.ComputePermissions(r.Context(), callerID, serverID, uuid.Nil)
    
    // Evaluate if the resulting bitmask contains the Kick bit
    if (perms & permissions.KickMembers) != permissions.KickMembers {
        util.RespondError(w, http.StatusForbidden, "You lack Kick permissions")
        return
    }

    // Proceed with Kick business logic
}
```

---

## 5. Security Edge-cases

1. **Role Hierarchy Prevention:** If User A has `MANAGE_ROLES`, they cannot grant themselves `ADMINISTRATOR`. The Go backend enforces that you can only manage roles whose bit-weight and position rank are *lower* than your own top role.
2. **Channel Lockout:** The UI prevents you from accidentally setting `VIEW_CHANNEL=deny` for the `@everyone` role on the *only* channel in your server, permanently locking yourself out if you aren't the owner.
