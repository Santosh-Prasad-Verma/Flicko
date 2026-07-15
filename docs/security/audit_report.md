# Security Audit Report: Flicko Platform

> **Date:** July 14, 2026  
> **Status:** Draft Report  
> **Target Base:** Supabase Migrations, Go API Backend, Flutter Client  

---

## Executive Summary

Flicko adopts a "Defense in Depth" strategy across its architecture. However, a comprehensive security code audit has revealed several critical structural vulnerabilities. 

The most pressing issues include **disabled/missing Row-Level Security (RLS)** on core database tables, **broken object-level access controls (BOLA)** on Supabase Storage buckets, and a **lack of server/channel membership verification** in the Go API handlers. If exploited, these vulnerabilities could allow unauthorized users to read private communications, delete media assets, impersonate moderators, or execute actions on arbitrary servers.

This report documents these findings, details their impact, and provides actionable code-level remediation steps.

---

## Summary of Findings

| ID | Component | Vulnerability Title | Severity | Status |
|---|---|---|---|---|
| **SEC-001** | Supabase DB | Core Database Tables Missing Row Level Security (RLS) | **Critical** | Open |
| **SEC-002** | Go Backend | Missing Server/Channel Membership Checks in API Handlers | **Critical** | Open |
| **SEC-003** | Supabase Storage | Broken Object-Level Authorization (BOLA) on Storage Buckets | **High** | Open |
| **SEC-004** | Supabase DB | `SECURITY DEFINER` Functions Vulnerable to Search Path Hijacking | **High** | Open |
| **SEC-005** | Flutter Client | Insecure Local JWT Session Persistence (Unencrypted) | **Medium** | Open |
| **SEC-006** | Flutter Client | Unrestricted Client Navigation via Custom Scheme Deep Links | **Low** | Open |
| **SEC-007** | Flutter Client | Missing SSL Certificate Pinning | **Low** | Open |

---

## Detailed Audit Findings

### SEC-001: Core Database Tables Missing Row Level Security (RLS)
- **Severity:** **Critical**
- **Component:** Supabase PostgreSQL Database (Migrations)
- **Description:** 
  Row-Level Security (RLS) is not enabled on several core tables. While the application layer has some access controls, Supabase exposes all tables directly via its public PostgREST API (e.g., `https://zliclxzqkopxgnlwlqsu.supabase.co/rest/v1/...`). Anyone with the public `anon` key can directly query, insert, update, or delete records in these tables.
- **Affected Tables:** `channels`, `roles`, `server_members`, `reactions`, `server_bans`, `custom_emojis`, `server_emojis`, `music_queues`, `notifications`, `creator_media_uploads`, `external_bot_events`.
- **Impact:** 
  - **Information Disclosure:** Any user can read the names, settings, and topics of all channels across private servers. They can extract the entire server member database and roles list.
  - **Authorization Bypass:** Any user can directly insert themselves into `server_members` to join any server, assign themselves administrative roles via `member_roles`, or bypass bans by deleting entries in `server_bans`.
- **Remediation:**
  1. Add migration statement to enable RLS:
     ```sql
     ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
     ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
     ALTER TABLE public.server_members ENABLE ROW LEVEL SECURITY;
     ```
  2. Implement strict select/write policies. For example, for `channels`:
     ```sql
     CREATE POLICY "Users can select channels they have access to"
     ON public.channels FOR SELECT
     TO authenticated
     USING (
       EXISTS (
         SELECT 1 FROM public.server_members 
         WHERE server_members.server_id = channels.server_id 
           AND server_members.user_id = auth.uid()
       )
     );
     ```

---

### SEC-002: Missing Server/Channel Membership Checks in API Handlers
- **Severity:** **Critical**
- **Component:** Go Backend (API Handlers)
- **Description:** 
  Several Go API endpoints extract the authenticated user ID from context but fail to verify whether the user belongs to the target server or has write access to the target channel. 
- **Affected Files:**
  - [message_handler.go](file:///home/tarun/Pictures/Flicko/backend/internal/handlers/message_handler.go#L70) (in `CreateMessage`)
  - [video_handler.go](file:///home/tarun/Pictures/Flicko/backend/internal/handlers/video_handler.go#L60) (in `CreateStream`)
  - [video_handler.go](file:///home/tarun/Pictures/Flicko/backend/internal/handlers/video_handler.go#L277) (in `GenerateLiveKitToken`)
- **Impact:** 
  - **Spam / Message Injection:** An authenticated user can POST messages to any channel ID, including announcements or private channels they do not belong to.
  - **Eavesdropping:** An attacker can generate a LiveKit token for any voice channel ID and connect to eavesdrop on active voice/video calls.
- **Remediation:**
  1. Register and apply the existing `RequireChannelPermission` middleware on these routes inside `cmd/server/main.go`.
  2. For `CreateMessage`, verify channel write permissions inside the handler or middleware:
     ```go
     // In MessageHandler.CreateMessage:
     var hasAccess bool
     err = h.db.QueryRow(ctx, `
         SELECT EXISTS(
             SELECT 1 FROM server_members sm
             JOIN channels c ON sm.server_id = c.server_id
             WHERE c.id = $1 AND sm.user_id = $2
         )
     `, channelID, userID).Scan(&hasAccess)
     if err != nil || !hasAccess {
         http.Error(w, "forbidden: not a member of the server", http.StatusForbidden)
         return
     }
     ```

---

### SEC-003: Broken Object-Level Authorization (BOLA) on Storage Buckets
- **Severity:** **High**
- **Component:** Supabase Storage (Objects RLS Policies)
- **Description:** 
  The storage policies configured for the `avatars`, `server-icons`, `attachments`, `emojis`, and `banners` buckets only check if the bucket ID matches and if the user is authenticated. There is no validation checking if the object's path matches the user's ID or if they own the related resource.
- **Affected Files:**
  - [023_create_remaining_storage_buckets.sql](file:///home/tarun/Pictures/Flicko/supabase/migrations/023_create_remaining_storage_buckets.sql)
  - [039_fix_storage_policies.sql](file:///home/tarun/Pictures/Flicko/supabase/migrations/039_fix_storage_policies.sql)
- **Impact:** 
  - **Asset Modification/Deletion:** Any authenticated user can issue `UPDATE` or `DELETE` requests to delete or overwrite another user's avatar, server icons, custom server emojis, or message attachments.
  - **Spoofing:** Attackers can upload files under paths belonging to other users.
- **Remediation:**
  Restrict uploads and updates to paths matching the user's UUID. For example, for the `avatars` bucket:
  ```sql
  -- Restrict UPDATE and DELETE using the storage.foldername helper
  CREATE POLICY "Users can update their own avatar"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
  ```

---

### SEC-004: `SECURITY DEFINER` Functions Vulnerable to Search Path Hijacking
- **Severity:** **High**
- **Component:** Supabase PostgreSQL Database (Trigger & Helper Functions)
- **Description:** 
  Many database functions are defined with `SECURITY DEFINER` (meaning they run with the elevated privileges of the creator/database owner) but do not explicitly specify a secure `search_path`. This allows a low-privileged caller to hijack execution behavior by creating objects (operators, functions) with identical names inside a custom schema and setting their session `search_path` to point to it.
- **Affected Files:** Trigger and utility functions in `017_user_profile_auto_creation_trigger.sql`, `018_server_initialization_trigger.sql`, `020_mention_notification_trigger.sql`, `035_permission_calculation_functions.sql`, `036_automation_triggers.sql`, `046_utility_functions.sql`, `065_friend_request_notification_trigger.sql`, `128_add_server_permission_function.sql`, `142_fix_slowmode_moderator_bypass.sql`, etc.
- **Impact:** 
  - **Privilege Escalation:** An attacker can execute arbitrary SQL code with superuser/database owner privileges, leading to complete database compromise.
- **Remediation:**
  Always declare `SET search_path = pg_catalog, public` (or whichever schemas are strictly needed) on all `SECURITY DEFINER` functions:
  ```sql
  CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER AS $$
  BEGIN
    ...
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public;
  ```

---

### SEC-005: Insecure Local JWT Session Persistence (Unencrypted)
- **Severity:** **Medium**
- **Component:** Flutter Client (Local Session Storage)
- **Description:** 
  The Flutter client initializes Supabase without specifying a secure local storage handler. As a result, the Supabase SDK defaults to storing the user's session tokens (including access token and refresh token) in unencrypted plain text inside `shared_preferences`.
- **Affected Files:**
  - [main.dart](file:///home/tarun/Pictures/Flicko/mobile/lib/main.dart#L70)
- **Impact:** 
  - **Session Hijacking:** On rooted devices, or if the device's filesystem backup is compromised, an attacker can extract the plain text refresh/access tokens and permanently compromise the user's account.
- **Remediation:**
  Define a secure storage helper wrapping the `flutter_secure_storage` package and pass it to `Supabase.initialize`:
  ```dart
  class SecureSupabaseStorage extends LocalStorage {
    final _secureStorage = const FlutterSecureStorage();
    
    @override
    Future<void> initialize() async {}
    
    @override
    Future<String?> accessToken() async => _secureStorage.read(key: 'supabase_session');
    
    @override
    Future<void> persistSession(String persistSessionString) async {
      await _secureStorage.write(key: 'supabase_session', value: persistSessionString);
    }
    
    @override
    Future<void> removeSession() async {
      await _secureStorage.delete(key: 'supabase_session');
    }
  }

  // Pass it inside main.dart:
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authLocalStorage: SecureSupabaseStorage(),
  );
  ```

---

### SEC-006: Unrestricted Client Navigation via Custom Scheme Deep Links
- **Severity:** **Low**
- **Component:** Flutter Client (Deep Linking)
- **Description:** 
  The custom app scheme handler resolves deep links like `flicko://ludo/...`. However, it extracts the trailing path from the URI and pushes it directly to `GoRouter` without validating that the route belongs to the Ludo feature space.
- **Affected Files:**
  - [ludo_deep_links.dart](file:///home/tarun/Pictures/Flicko/mobile/lib/features/ludo/services/ludo_deep_links.dart#L50)
- **Impact:** 
  - **Open Redirection / UI Bypasses:** An attacker can use custom scheme links to force the client app to navigate to private pages, administrative settings screens, or debug views.
- **Remediation:**
  Ensure the path starts specifically with `/ludo` before routing:
  ```dart
  void _route(Uri uri) {
    if (!_isLudoLink(uri)) return;
    
    final path = uri.path.isEmpty ? '/ludo' : uri.path;
    if (!path.startsWith('/ludo')) {
      return; // Block arbitrary app navigation
    }
    
    final query = uri.queryParameters.isEmpty
        ? ''
        : '?${Uri(queryParameters: uri.queryParameters).query}';
    _router.push('$path$query');
  }
  ```

---

### SEC-007: Missing SSL Certificate Pinning
- **Severity:** **Low**
- **Component:** Flutter Client (Networking)
- **Description:** 
  The standard HTTP client (`Dio`) relies on the operating system's default trust store to validate HTTPS certificates. It does not implement SSL pinning to restrict connections only to the server's specific certificate.
- **Affected Files:**
  - [dio_client.dart](file:///home/tarun/Pictures/Flicko/mobile/lib/data/clients/dio_client.dart#L19)
- **Impact:** 
  - **Man-in-the-Middle (MitM):** If a user installs a malicious root CA certificate (e.g. through a compromised public Wi-Fi portal or corporate monitoring software), an attacker can decrypt, read, or modify API requests.
- **Remediation:**
  Implement SSL pinning in `dio_client.dart` using a library like `http_certificate_pinning` or by embedding the public certificate hash directly in the network handshake logic.
