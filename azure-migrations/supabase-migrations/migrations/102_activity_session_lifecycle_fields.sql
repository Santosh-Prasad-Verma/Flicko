-- ============================================
-- Migration 102: Activity session lifecycle fields
-- ============================================
-- Story P1-E1-S1:
-- - Harden activity_sessions with host transfer metadata, ended_reason, heartbeat.
-- - Extend activity_participants with role + left_at soft-leave tracking.

-- ── activity_sessions hardening ──────────────────────────────────────────────
ALTER TABLE public.activity_sessions
  ADD COLUMN IF NOT EXISTS previous_host_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS host_transferred_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ended_reason TEXT,
  ADD COLUMN IF NOT EXISTS last_heartbeat_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'activity_sessions_ended_reason_check'
      AND conrelid = 'public.activity_sessions'::regclass
  ) THEN
    ALTER TABLE public.activity_sessions
      ADD CONSTRAINT activity_sessions_ended_reason_check
      CHECK (
        ended_reason IS NULL
        OR ended_reason IN ('host_ended', 'host_left', 'empty', 'timeout', 'error')
      );
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_activity_sessions_last_heartbeat
  ON public.activity_sessions(last_heartbeat_at);

-- ── activity_participants extension ──────────────────────────────────────────
ALTER TABLE public.activity_participants
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'participant',
  ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'activity_participants_role_check'
      AND conrelid = 'public.activity_participants'::regclass
  ) THEN
    ALTER TABLE public.activity_participants
      ADD CONSTRAINT activity_participants_role_check
      CHECK (role IN ('host', 'participant', 'spectator'));
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_activity_participants_active
  ON public.activity_participants(session_id, role)
  WHERE left_at IS NULL;
