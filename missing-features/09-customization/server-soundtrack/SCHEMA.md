# SCHEMA - Server Soundtrack

Migration: `supabase/migrations/211_server_soundtrack.sql`. All tables live in the `public` schema. RLS is enabled on every table; default-deny is the baseline. Foreign keys use `ON DELETE` rules tuned to preserve audit history.

## 1. soundtrack_tracks (curated library)

```sql
CREATE TABLE public.soundtrack_tracks (
    id              text PRIMARY KEY
                    CHECK (id ~ '^trk_[a-z0-9_]{3,40}$'),
    title           text NOT NULL CHECK (length(title) BETWEEN 1 AND 80),
    artist          text NOT NULL CHECK (length(artist) BETWEEN 1 AND 80),
    duration_ms     integer NOT NULL CHECK (duration_ms BETWEEN 5000 AND 900000),
    file_id         text NOT NULL,        -- Appwrite file id in bucket "soundtracks"
    file_id_low     text,                  -- 32 kbps variant (optional)
    waveform_json   jsonb,                 -- precomputed peaks for the picker
    loudness_lufs   numeric(5,2) NOT NULL CHECK (loudness_lufs BETWEEN -40 AND -10),
    license_kind    text NOT NULL CHECK (license_kind IN ('cc0','cc-by','royalty-free')),
    attribution     text,                  -- required when license_kind='cc-by'
    source_url      text,
    tags            text[] NOT NULL DEFAULT '{}',
    is_retired      boolean NOT NULL DEFAULT false,
    created_by      uuid NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_soundtrack_tracks_active
    ON public.soundtrack_tracks (created_at DESC)
    WHERE is_retired = false;

CREATE INDEX idx_soundtrack_tracks_tags
    ON public.soundtrack_tracks USING gin (tags);

CREATE INDEX idx_soundtrack_tracks_license
    ON public.soundtrack_tracks (license_kind)
    WHERE is_retired = false;

ALTER TABLE public.soundtrack_tracks ENABLE ROW LEVEL SECURITY;

-- Any authenticated member can browse non-retired tracks.
CREATE POLICY soundtrack_tracks_read
    ON public.soundtrack_tracks FOR SELECT
    TO authenticated
    USING (is_retired = false OR public.is_platform_admin(auth.uid()));

-- Only platform admins write.
CREATE POLICY soundtrack_tracks_write
    ON public.soundtrack_tracks FOR ALL
    TO authenticated
    USING (public.is_platform_admin(auth.uid()))
    WITH CHECK (public.is_platform_admin(auth.uid()));
```

## 2. server_soundtracks (active selection per server)

```sql
CREATE TABLE public.server_soundtracks (
    server_id       uuid PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
    track_id        text REFERENCES public.soundtrack_tracks(id) ON DELETE SET NULL,
    enabled         boolean NOT NULL DEFAULT false,
    volume_db       smallint NOT NULL DEFAULT -22
                    CHECK (volume_db BETWEEN -36 AND -6),
    fade_seconds    smallint NOT NULL DEFAULT 3
                    CHECK (fade_seconds BETWEEN 0 AND 8),
    duck_under_voice boolean NOT NULL DEFAULT true,
    version         bigint NOT NULL DEFAULT 1,
    set_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    set_at          timestamptz NOT NULL DEFAULT now(),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT enabled_requires_track
        CHECK (enabled = false OR track_id IS NOT NULL)
);

CREATE INDEX idx_server_soundtracks_track
    ON public.server_soundtracks (track_id)
    WHERE track_id IS NOT NULL;

CREATE INDEX idx_server_soundtracks_enabled
    ON public.server_soundtracks (server_id)
    WHERE enabled = true;

CREATE TRIGGER trg_server_soundtracks_touch
    BEFORE UPDATE ON public.server_soundtracks
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_server_soundtracks_version
    BEFORE UPDATE ON public.server_soundtracks
    FOR EACH ROW
    WHEN (OLD.track_id IS DISTINCT FROM NEW.track_id
       OR OLD.enabled  IS DISTINCT FROM NEW.enabled
       OR OLD.volume_db IS DISTINCT FROM NEW.volume_db
       OR OLD.fade_seconds IS DISTINCT FROM NEW.fade_seconds)
    EXECUTE FUNCTION public.bump_version();

ALTER TABLE public.server_soundtracks ENABLE ROW LEVEL SECURITY;

-- Members of the server can read the active row.
CREATE POLICY server_soundtracks_read
    ON public.server_soundtracks FOR SELECT
    TO authenticated
    USING (public.is_server_member(auth.uid(), server_id));

-- Only server admins / owners can write.
CREATE POLICY server_soundtracks_write
    ON public.server_soundtracks FOR ALL
    TO authenticated
    USING (public.is_server_admin(auth.uid(), server_id))
    WITH CHECK (public.is_server_admin(auth.uid(), server_id));
```

## 3. user_soundtrack_overrides (per-member mute / volume)

```sql
CREATE TABLE public.user_soundtrack_overrides (
    user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    server_id       uuid NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    is_muted        boolean NOT NULL DEFAULT false,
    relative_db     smallint NOT NULL DEFAULT 0
                    CHECK (relative_db BETWEEN -60 AND 0),
    mute_all_servers boolean NOT NULL DEFAULT false,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, server_id)
);

CREATE INDEX idx_user_soundtrack_overrides_user
    ON public.user_soundtrack_overrides (user_id)
    WHERE is_muted = true OR mute_all_servers = true;

CREATE TRIGGER trg_user_soundtrack_overrides_touch
    BEFORE UPDATE ON public.user_soundtrack_overrides
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

ALTER TABLE public.user_soundtrack_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_soundtrack_overrides_self
    ON public.user_soundtrack_overrides FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
```

## 4. Helper functions referenced above

These already exist for other features and are reused; included here for completeness.

```sql
-- Returns true if the user has admin or owner role on the server.
-- public.is_server_admin(uuid, uuid) -> boolean
-- public.is_server_member(uuid, uuid) -> boolean
-- public.is_platform_admin(uuid) -> boolean
-- public.touch_updated_at() trigger fn
-- public.bump_version() trigger fn that does NEW.version := OLD.version + 1
```

## 5. Redis cache

Key: `soundtrack:server:{server_id}`
Encoding: JSON, gzip-compressed when > 2 KB.
TTL: 300 seconds.
Invalidation: `DEL` on every write to `server_soundtracks` (after `COMMIT`, in the same Go handler).
Stampede protection: single-flight per server_id using a SETNX lock `soundtrack:lock:{server_id}` (TTL 5s). Concurrent fetchers block on a 50ms poll loop, max 1s.

Payload shape:

```json
{
  "server_id": "...",
  "version": 7,
  "enabled": true,
  "track": {
    "id": "trk_lofi_rain",
    "title": "Rainy Window Lofi",
    "artist": "Kestrel",
    "duration_ms": 204000,
    "file_id": "aw_file_abcd",
    "file_id_low": "aw_file_abcd_low",
    "loudness_lufs": -22.0,
    "license_kind": "cc0"
  },
  "volume_db": -22,
  "fade_seconds": 3,
  "duck_under_voice": true,
  "cached_at": "2026-05-29T10:14:33Z"
}
```

Signed URLs are not cached in Redis (member-scoped, short-lived). They are computed at request time and returned only in the HTTP response.

Secondary key: `soundtrack:track:{track_id}` caches a track row for 1 hour to avoid joining `soundtrack_tracks` on every server lookup. Invalidated on track update or retirement.

## 6. Appwrite bucket configuration

Bucket id: `soundtracks`
Region: same as primary Appwrite project (matches API region).
Permissions:
- Read: role `users` (any authenticated) - granted at file level only via signed URLs.
- Write: role `team:platform-admins`.

Settings:
- Maximum file size: 10 MB.
- Allowed file extensions: `ogg`, `opus`.
- Encryption: enabled.
- Antivirus: enabled.
- Compression: none (audio is already compressed).
- File security: enabled (per-file ACLs override bucket).

Filename convention: `{track_id}.{variant}.opus` where variant is `hi` (48 kbps) or `lo` (32 kbps). The high-quality file id is stored in `file_id`, low-quality in `file_id_low`.

Signed URL parameters:
- TTL: 3600s.
- Project + JWT signed by the API service account.
- Returned only in `GET /servers/:id/soundtrack` and never logged in plaintext.

Upload flow (admin tooling):
1. Normalize source to -22 LUFS, encode 48 kbps Opus mono.
2. Encode 32 kbps low variant.
3. Compute waveform peaks (256 buckets) -> `waveform_json`.
4. POST file to Appwrite bucket; capture file ids.
5. INSERT into `soundtrack_tracks` with all metadata.
6. Smoke-test by previewing in the picker before announcing.

## 7. Down migration

```sql
DROP TABLE IF EXISTS public.user_soundtrack_overrides;
DROP TABLE IF EXISTS public.server_soundtracks;
DROP TABLE IF EXISTS public.soundtrack_tracks;
```

Down does not remove the Appwrite bucket; bucket lifecycle is managed out-of-band so re-applying the migration does not lose curated assets.
