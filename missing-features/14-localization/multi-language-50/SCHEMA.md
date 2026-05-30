# Multi-Language 50+ — Backend Schema

## 1. Tables

### `i18n_messages`

Lookup table for backend-generated text (errors, system events, push titles, email subjects). UI strings live in mobile ARBs; this table is the *server side* of i18n.

```sql
CREATE TABLE i18n_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code        TEXT NOT NULL,           -- e.g. 'err.not_found', 'notif.mention.title'
  lang        TEXT NOT NULL,           -- BCP-47 lower (e.g. 'en', 'pt-br', 'zh-hans')
  text        TEXT NOT NULL,           -- the localized message
  placeholders JSONB DEFAULT '[]'::jsonb,  -- ['{user}', '{channel}']
  approved_by UUID REFERENCES users(id),
  source      TEXT NOT NULL DEFAULT 'crowdin', -- 'crowdin' | 'weblate' | 'manual' | 'mt'
  reviewed    BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(code, lang)
);

CREATE INDEX idx_i18n_messages_code      ON i18n_messages(code);
CREATE INDEX idx_i18n_messages_lang      ON i18n_messages(lang);
CREATE INDEX idx_i18n_messages_reviewed  ON i18n_messages(reviewed) WHERE reviewed = false;
```

### `i18n_locales`

Catalog of supported locales — drives the picker UI and the per-locale feature flag.

```sql
CREATE TABLE i18n_locales (
  code         TEXT PRIMARY KEY,                 -- 'en', 'pt-br', 'zh-hans'
  english_name TEXT NOT NULL,                    -- 'English', 'Portuguese (Brazil)'
  native_name  TEXT NOT NULL,                    -- 'English', 'Português (Brasil)'
  rtl          BOOLEAN NOT NULL DEFAULT false,
  enabled      BOOLEAN NOT NULL DEFAULT false,   -- hide from picker until coverage ≥ threshold
  coverage_pct NUMERIC(5,2) NOT NULL DEFAULT 0,  -- updated nightly from Crowdin
  region_default TEXT,                            -- ISO-3166 alpha-2; default region for that locale
  flag_emoji   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `profiles` (column add)

```sql
ALTER TABLE profiles
  ADD COLUMN preferred_lang TEXT REFERENCES i18n_locales(code);

CREATE INDEX idx_profiles_preferred_lang ON profiles(preferred_lang);
```

### `i18n_translation_credits`

Read-only mirror of who translated what — surfaced in the About screen.

```sql
CREATE TABLE i18n_translation_credits (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lang        TEXT NOT NULL REFERENCES i18n_locales(code),
  username    TEXT NOT NULL,
  display     TEXT NOT NULL,
  string_count INT NOT NULL DEFAULT 0,
  source      TEXT NOT NULL DEFAULT 'crowdin',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_i18n_credits_lang ON i18n_translation_credits(lang);
```

## 2. RLS Policies

```sql
ALTER TABLE i18n_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE i18n_locales ENABLE ROW LEVEL SECURITY;
ALTER TABLE i18n_translation_credits ENABLE ROW LEVEL SECURITY;

-- Read is public for i18n_messages (any signed-in user; even anon for marketing pages)
CREATE POLICY "Anyone can read i18n_messages"
  ON i18n_messages FOR SELECT
  USING (true);

-- Only service role / admins can write
CREATE POLICY "Admins write i18n_messages"
  ON i18n_messages FOR INSERT
  WITH CHECK (auth.role() = 'service_role'
              OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Admins update i18n_messages"
  ON i18n_messages FOR UPDATE
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Locales: read public, write admin
CREATE POLICY "Anyone can read locales" ON i18n_locales FOR SELECT USING (true);
CREATE POLICY "Admins manage locales" ON i18n_locales FOR ALL
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Credits: read public, write service-role only (sync job)
CREATE POLICY "Anyone can read credits" ON i18n_translation_credits FOR SELECT USING (true);
CREATE POLICY "Service role writes credits" ON i18n_translation_credits FOR ALL
  USING (auth.role() = 'service_role');
```

## 3. Triggers

```sql
CREATE TRIGGER i18n_messages_set_updated_at
  BEFORE UPDATE ON i18n_messages
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER i18n_locales_set_updated_at
  BEFORE UPDATE ON i18n_locales
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Bust cache (LISTEN/NOTIFY) when a translation changes so backend LRU refreshes early
CREATE OR REPLACE FUNCTION i18n_notify_change() RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('i18n_messages_changed', NEW.code || ':' || NEW.lang);
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER i18n_messages_notify
  AFTER INSERT OR UPDATE ON i18n_messages
  FOR EACH ROW EXECUTE FUNCTION i18n_notify_change();
```

## 4. Migration File

Path: `supabase/migrations/258_i18n_messages.up.sql`
Down: `supabase/migrations/258_i18n_messages.down.sql`

```sql
-- up
BEGIN;

CREATE TABLE i18n_messages (...);
CREATE TABLE i18n_locales (...);
CREATE TABLE i18n_translation_credits (...);

ALTER TABLE profiles ADD COLUMN preferred_lang TEXT REFERENCES i18n_locales(code);

-- seed locales
INSERT INTO i18n_locales(code, english_name, native_name, rtl, enabled, region_default, flag_emoji) VALUES
  ('en',   'English',                'English',         false, true,  'US', '🇺🇸'),
  ('es',   'Spanish',                'Español',         false, false, 'ES', '🇪🇸'),
  ('pt-br','Portuguese (Brazil)',    'Português (BR)',  false, false, 'BR', '🇧🇷'),
  ('fr',   'French',                 'Français',        false, false, 'FR', '🇫🇷'),
  ('de',   'German',                 'Deutsch',         false, false, 'DE', '🇩🇪'),
  ('ja',   'Japanese',               '日本語',          false, false, 'JP', '🇯🇵'),
  ('ar',   'Arabic',                 'العربية',         true,  false, 'SA', '🇸🇦'),
  ('he',   'Hebrew',                 'עברית',           true,  false, 'IL', '🇮🇱'),
  ('fa',   'Persian',                'فارسی',           true,  false, 'IR', '🇮🇷'),
  ('ur',   'Urdu',                   'اردو',            true,  false, 'PK', '🇵🇰'),
  ('hi',   'Hindi',                  'हिन्दी',           false, false, 'IN', '🇮🇳'),
  ('zh-hans','Chinese (Simplified)', '中文(简体)',       false, false, 'CN', '🇨🇳'),
  ('zh-hant','Chinese (Traditional)','中文(繁體)',       false, false, 'TW', '🇹🇼'),
  ('ko',   'Korean',                 '한국어',          false, false, 'KR', '🇰🇷'),
  ('ru',   'Russian',                'Русский',         false, false, 'RU', '🇷🇺'),
  -- ... 35 more
;

-- seed top-50 most common error codes in English; other langs sync from Crowdin nightly
INSERT INTO i18n_messages(code, lang, text, source, reviewed) VALUES
  ('err.not_found',        'en', 'Not found.',                          'manual', true),
  ('err.unauthorized',     'en', 'You need to sign in.',                'manual', true),
  ('err.forbidden',        'en', 'You do not have permission.',         'manual', true),
  ('err.rate_limited',     'en', 'Slow down — try again in a moment.',  'manual', true),
  ('notif.mention.title',  'en', '{actor} mentioned you',               'manual', true),
  ('notif.mention.body',   'en', '{actor}: {snippet}',                  'manual', true)
  -- ...
;

COMMIT;
```

```sql
-- down
BEGIN;
ALTER TABLE profiles DROP COLUMN IF EXISTS preferred_lang;
DROP TABLE IF EXISTS i18n_translation_credits;
DROP TABLE IF EXISTS i18n_messages;
DROP TABLE IF EXISTS i18n_locales;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `i18n:msg:<code>:<lang>` | text | 10m |
| `i18n:locales:enabled` | JSON list | 5m |
| `i18n:credits:<lang>` | JSON list | 1h |
| `i18n:ai:warm:<key>:<lang>` | precomputed AI translation | 7d |

LRU in-process: 4096 entries, 60s refresh on `pg_notify('i18n_messages_changed')`.

## 6. Search Index (Meilisearch)

Not used — i18n_messages lookup is purely O(1) via Redis/LRU; full-text search not needed. (Translator-facing search is on Crowdin.)

## 7. Vector Index (Qdrant)

Not used — translations are exact-match keyed.

## 8. Object Storage (Appwrite)

- Bucket: `i18n-screenshots`
- Allowed MIME: `image/png`, `image/webp`
- Max file size: 5MB per screenshot
- Used by: Crowdin to display in-context screenshots to translators
- Permission: `read("any")`, `write("role:admin")`

## 9. Data Retention

- `i18n_messages`: keep all rows; old rows compress nicely (small text, deduplicated).
- `i18n_translation_credits`: keep forever — credit is permanent.
- `i18n_locales`: never drop a locale; toggle `enabled=false` instead.
- GDPR: `username` in credits is opt-in via Crowdin profile; if a translator requests deletion, replace with `Anonymous`.

## 10. Sample Queries

```sql
-- Resolve a single message with fallback to en
SELECT text
FROM i18n_messages
WHERE code = $1 AND lang IN ($2, 'en')
ORDER BY (lang = $2) DESC
LIMIT 1;

-- All enabled locales sorted by native name
SELECT code, native_name, rtl, flag_emoji
FROM i18n_locales
WHERE enabled = true
ORDER BY native_name;

-- Coverage report (drives daily admin email)
SELECT l.code, l.native_name,
       COUNT(*) FILTER (WHERE m.reviewed) * 100.0 / NULLIF(COUNT(*),0) AS pct_reviewed
FROM i18n_locales l
LEFT JOIN i18n_messages m ON m.lang = l.code
GROUP BY l.code, l.native_name
ORDER BY pct_reviewed DESC NULLS LAST;

-- Top translators per locale
SELECT lang, display, string_count
FROM i18n_translation_credits
ORDER BY lang, string_count DESC;
```
