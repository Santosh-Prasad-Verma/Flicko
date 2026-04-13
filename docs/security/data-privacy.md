# Data Privacy & Retention

> **Reading time:** ~5 minutes · **Audience:** Everyone · **Last Updated:** 2026-04-11

Handling user-generated communication requires strict adherence to privacy principles and legal compliance (GDPR, CCPA). This document outlines Flicko's programmatic approach to anonymization and retention.

---

## Soft vs Hard Deletion

Flicko heavily relies on "Soft Deletes". The majority of tables in PostgreSQL (`messages`, `users`, `servers`) possess a `deleted_at` timestamp column.

When a user deletes a message via the UI:
1. `UPDATE messages SET deleted_at = NOW() WHERE id = $1`
2. The UI instantly hides the message.
3. The API specifically filters: `SELECT * FROM messages WHERE deleted_at IS NULL`.

**Why?** Trust & Safety. If a user posts illicit content and immediately deletes it to hide the evidence, moderators or T&S Admins still require access to the database logs to verify reports and take legal action if necessary.

---

## Archival Data Pipeline (The 30-Day Rule)

While soft deletes are necessary for safety, permanently retaining deleted data is a privacy violation.

The database runs a `pg_cron` automated job at 03:00 UTC every day.

```sql
-- Hard delete old messages
DELETE FROM public.messages 
WHERE deleted_at IS NOT NULL 
  AND deleted_at < NOW() - INTERVAL '30 days';

-- Purge associated Cloudinary binaries asynchronously via PgBouncer
-- ...
```
This guarantees that any content deleted by the user is physically wiped from the servers (and our CDN provider) within 30 days.

---

## GDPR: Right to Erasure (Account Deletion)

If a user navigates to Settings -> Privacy -> "Delete My Account", a strict cascade executes within a single database transaction.

**The Deletion Cascade:**
1. Revoke Supabase Auth identity (prevents immediate re-login).
2. Delete User Profile (`UPDATE users SET username = 'Deleted_User', display_name = 'Deleted User', avatar_url = null, bio = null`).
3. Wipe `friends` associations.
4. Hard-delete all `dm_messages` sent by the user (unlike public channels, private messages are purged immediately to protect the recipient's privacy pane).
5. Scramble email associations to prevent Supabase identity leakage.

*Public Messages:* Under standard Discord/Flicko paradigms, a user's public server messages are NOT deleted when their account is deleted to preserve context in community channels. However, the author will simply show up as "Deleted_User" with an empty avatar.

---

## Log Anonymization

Logs emitted by NGINX and the Go API (`stdout`, scraped by Promtail into Loki) never contain Personally Identifiable Information (PII) like Email Addresses or Usernames in plain text.

The Go `middleware.Logger` is strictly configured to log generic identifiers:
```json
{"level":"info","msg":"request completed","method":"POST","path":"/api/v1/messages","status":201,"duration":"15ms","request_id":"c-19x","user_uuid":"db3a2..."}
```

The `user_uuid` is meaningless to an attacker reading the log streams without direct read-access to the hardened PostgreSQL instance required to map it to an email address.
