-- ============================================
-- Migration 107: Trusted devices and login security telemetry
-- ============================================
-- Story P2-E1-S2-T4

CREATE TABLE IF NOT EXISTS public.trusted_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_name TEXT NOT NULL,
  device_type TEXT,
  os TEXT,
  browser TEXT,
  ip_address INET,
  location TEXT,
  fingerprint_hash TEXT,
  remember_token_hash TEXT,
  trusted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trusted_devices_user_id ON public.trusted_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_trusted_devices_active ON public.trusted_devices(user_id, last_used_at DESC) WHERE revoked_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_trusted_devices_user_fingerprint_active
  ON public.trusted_devices(user_id, fingerprint_hash)
  WHERE fingerprint_hash IS NOT NULL AND revoked_at IS NULL;

DROP TRIGGER IF EXISTS tr_trusted_devices_updated_at ON public.trusted_devices;
CREATE TRIGGER tr_trusted_devices_updated_at
  BEFORE UPDATE ON public.trusted_devices
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.login_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL DEFAULT 'login_success'
    CHECK (event_type IN ('login_success', 'login_failed', 'mfa_challenge', 'mfa_failed', 'logout')),
  trusted_device_id UUID REFERENCES public.trusted_devices(id) ON DELETE SET NULL,
  ip_address INET,
  user_agent TEXT,
  location TEXT,
  risk_score DOUBLE PRECISION NOT NULL DEFAULT 0.0,
  is_suspicious BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_login_events_user_id ON public.login_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_events_suspicious ON public.login_events(user_id, is_suspicious, created_at DESC);

CREATE TABLE IF NOT EXISTS public.security_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  login_event_id UUID REFERENCES public.login_events(id) ON DELETE SET NULL,
  alert_type TEXT NOT NULL
    CHECK (alert_type IN ('suspicious_login', 'new_device_login', 'impossible_travel')),
  severity TEXT NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'acknowledged', 'resolved')),
  message TEXT NOT NULL,
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_alerts_user_id ON public.security_alerts(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_security_alerts_login_event_id ON public.security_alerts(login_event_id);

DROP TRIGGER IF EXISTS tr_security_alerts_updated_at ON public.security_alerts;
CREATE TRIGGER tr_security_alerts_updated_at
  BEFORE UPDATE ON public.security_alerts
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.trusted_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.security_alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own trusted devices" ON public.trusted_devices;
CREATE POLICY "Users can read own trusted devices"
  ON public.trusted_devices FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own trusted devices" ON public.trusted_devices;
CREATE POLICY "Users can create own trusted devices"
  ON public.trusted_devices FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own trusted devices" ON public.trusted_devices;
CREATE POLICY "Users can update own trusted devices"
  ON public.trusted_devices FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own trusted devices" ON public.trusted_devices;
CREATE POLICY "Users can delete own trusted devices"
  ON public.trusted_devices FOR DELETE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can read own login events" ON public.login_events;
CREATE POLICY "Users can read own login events"
  ON public.login_events FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own login events" ON public.login_events;
CREATE POLICY "Users can create own login events"
  ON public.login_events FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own login events" ON public.login_events;
CREATE POLICY "Users can update own login events"
  ON public.login_events FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own login events" ON public.login_events;
CREATE POLICY "Users can delete own login events"
  ON public.login_events FOR DELETE
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can read own security alerts" ON public.security_alerts;
CREATE POLICY "Users can read own security alerts"
  ON public.security_alerts FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own security alerts" ON public.security_alerts;
CREATE POLICY "Users can create own security alerts"
  ON public.security_alerts FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own security alerts" ON public.security_alerts;
CREATE POLICY "Users can update own security alerts"
  ON public.security_alerts FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own security alerts" ON public.security_alerts;
CREATE POLICY "Users can delete own security alerts"
  ON public.security_alerts FOR DELETE
  USING (user_id = auth.uid());
