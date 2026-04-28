-- ============================================================================
-- 095: External Bot Marketplace Infrastructure
-- Adds: external_bots, bot_webhooks, bot_api_keys, bot_events, bot_stats
-- ============================================================================

-- ─── External Bots Registry ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.external_bots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    developer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    avatar_url TEXT,
    banner_url TEXT,
    website_url TEXT,
    support_server_url TEXT,
    privacy_policy_url TEXT,
    terms_of_service_url TEXT,
    webhook_url TEXT NOT NULL,
    webhook_secret TEXT NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    permissions BIGINT DEFAULT 0,
    categories TEXT[] DEFAULT '{}',
    tags TEXT[] DEFAULT '{}',
    verified BOOLEAN DEFAULT false,
    featured BOOLEAN DEFAULT false,
    public BOOLEAN DEFAULT false,
    install_count INTEGER DEFAULT 0,
    rating_average NUMERIC(3,2) DEFAULT 0.0,
    rating_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'suspended')),
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_external_bots_developer ON public.external_bots(developer_id);
CREATE INDEX idx_external_bots_status ON public.external_bots(status, public);
CREATE INDEX idx_external_bots_featured ON public.external_bots(featured, public) WHERE featured = true;

-- ─── Bot API Keys ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bot_api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    key_hash TEXT NOT NULL UNIQUE,
    key_prefix TEXT NOT NULL,
    name TEXT NOT NULL,
    scopes TEXT[] DEFAULT '{}',
    last_used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_bot_api_keys_bot ON public.bot_api_keys(bot_id);
CREATE INDEX idx_bot_api_keys_hash ON public.bot_api_keys(key_hash) WHERE revoked = false;

-- ─── Bot Installations ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bot_installations (
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    installed_by UUID NOT NULL REFERENCES auth.users(id),
    permissions BIGINT DEFAULT 0,
    enabled BOOLEAN DEFAULT true,
    config JSONB DEFAULT '{}'::jsonb,
    installed_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (bot_id, server_id)
);

CREATE INDEX idx_bot_installations_server ON public.bot_installations(server_id);
CREATE INDEX idx_bot_installations_bot ON public.bot_installations(bot_id) WHERE enabled = true;

-- ─── Bot Event Subscriptions ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bot_event_subscriptions (
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    enabled BOOLEAN DEFAULT true,
    PRIMARY KEY (bot_id, event_type)
);

CREATE INDEX idx_bot_event_subscriptions_type ON public.bot_event_subscriptions(event_type) WHERE enabled = true;

-- ─── Bot Webhook Delivery Log ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bot_webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    event_id UUID NOT NULL,
    server_id UUID,
    status_code INTEGER,
    response_time_ms INTEGER,
    success BOOLEAN DEFAULT false,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    delivered_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_bot_webhook_deliveries_bot ON public.bot_webhook_deliveries(bot_id, delivered_at DESC);
CREATE INDEX idx_bot_webhook_deliveries_event ON public.bot_webhook_deliveries(event_id);

-- Partition by month for performance
CREATE INDEX idx_bot_webhook_deliveries_time ON public.bot_webhook_deliveries(delivered_at DESC);

-- ─── Bot Statistics ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bot_stats (
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    server_count INTEGER DEFAULT 0,
    active_users INTEGER DEFAULT 0,
    command_invocations INTEGER DEFAULT 0,
    message_events INTEGER DEFAULT 0,
    webhook_success_rate NUMERIC(5,2) DEFAULT 0.0,
    avg_response_time_ms INTEGER DEFAULT 0,
    PRIMARY KEY (bot_id, date)
);

CREATE INDEX idx_bot_stats_bot_date ON public.bot_stats(bot_id, date DESC);

-- ─── Bot Reviews & Ratings ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bot_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(bot_id, user_id)
);

CREATE INDEX idx_bot_reviews_bot ON public.bot_reviews(bot_id, created_at DESC);
CREATE INDEX idx_bot_reviews_rating ON public.bot_reviews(bot_id, rating DESC);

-- ─── Bot Commands Registry ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.bot_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id UUID NOT NULL REFERENCES public.external_bots(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    options JSONB DEFAULT '[]'::jsonb,
    category TEXT,
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(bot_id, name)
);

CREATE INDEX idx_bot_commands_bot ON public.bot_commands(bot_id);

-- ─── RLS Policies ───────────────────────────────────────────────────────────

ALTER TABLE public.external_bots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_event_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_webhook_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bot_commands ENABLE ROW LEVEL SECURITY;

-- Anyone can view public bots
CREATE POLICY "Anyone can view public bots" ON public.external_bots FOR SELECT
  USING (public = true AND status = 'approved');

-- Developers can manage their own bots
CREATE POLICY "Developers can manage their bots" ON public.external_bots FOR ALL
  USING (developer_id = auth.uid());

-- Developers can view their API keys
CREATE POLICY "Developers can view their API keys" ON public.bot_api_keys FOR SELECT
  USING (EXISTS (SELECT 1 FROM external_bots WHERE external_bots.id = bot_api_keys.bot_id AND external_bots.developer_id = auth.uid()));

CREATE POLICY "Developers can manage their API keys" ON public.bot_api_keys FOR ALL
  USING (EXISTS (SELECT 1 FROM external_bots WHERE external_bots.id = bot_api_keys.bot_id AND external_bots.developer_id = auth.uid()));

-- Server members can view bot installations
CREATE POLICY "Members can view bot installations" ON public.bot_installations FOR SELECT
  USING (EXISTS (SELECT 1 FROM server_members WHERE server_members.server_id = bot_installations.server_id AND server_members.user_id = auth.uid()));

-- Server owners can manage bot installations
CREATE POLICY "Server owners can manage bot installations" ON public.bot_installations FOR ALL
  USING (EXISTS (SELECT 1 FROM servers WHERE servers.id = bot_installations.server_id AND servers.owner_id = auth.uid()));

-- Developers can view their bot subscriptions
CREATE POLICY "Developers can manage bot subscriptions" ON public.bot_event_subscriptions FOR ALL
  USING (EXISTS (SELECT 1 FROM external_bots WHERE external_bots.id = bot_event_subscriptions.bot_id AND external_bots.developer_id = auth.uid()));

-- Developers can view webhook delivery logs
CREATE POLICY "Developers can view webhook deliveries" ON public.bot_webhook_deliveries FOR SELECT
  USING (EXISTS (SELECT 1 FROM external_bots WHERE external_bots.id = bot_webhook_deliveries.bot_id AND external_bots.developer_id = auth.uid()));

-- Developers can view their bot stats
CREATE POLICY "Developers can view bot stats" ON public.bot_stats FOR SELECT
  USING (EXISTS (SELECT 1 FROM external_bots WHERE external_bots.id = bot_stats.bot_id AND external_bots.developer_id = auth.uid()));

-- Anyone can view bot reviews
CREATE POLICY "Anyone can view bot reviews" ON public.bot_reviews FOR SELECT
  USING (EXISTS (SELECT 1 FROM external_bots WHERE external_bots.id = bot_reviews.bot_id AND external_bots.public = true));

-- Users can create/update their own reviews
CREATE POLICY "Users can manage their reviews" ON public.bot_reviews FOR ALL
  USING (user_id = auth.uid());

-- Anyone can view bot commands
CREATE POLICY "Anyone can view bot commands" ON public.bot_commands FOR SELECT
  USING (EXISTS (SELECT 1 FROM external_bots WHERE external_bots.id = bot_commands.bot_id AND external_bots.public = true));

-- Developers can manage their bot commands
CREATE POLICY "Developers can manage bot commands" ON public.bot_commands FOR ALL
  USING (EXISTS (SELECT 1 FROM external_bots WHERE external_bots.id = bot_commands.bot_id AND external_bots.developer_id = auth.uid()));

-- ─── Triggers ───────────────────────────────────────────────────────────────

-- Update install_count when bot is installed/uninstalled
CREATE OR REPLACE FUNCTION update_bot_install_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE external_bots SET install_count = install_count + 1 WHERE id = NEW.bot_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE external_bots SET install_count = GREATEST(install_count - 1, 0) WHERE id = OLD.bot_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_bot_installations_count
AFTER INSERT OR DELETE ON public.bot_installations
FOR EACH ROW EXECUTE FUNCTION update_bot_install_count();

-- Update rating average when review is added/updated/deleted
CREATE OR REPLACE FUNCTION update_bot_rating()
RETURNS TRIGGER AS $$
DECLARE
    avg_rating NUMERIC(3,2);
    review_count INTEGER;
BEGIN
    SELECT AVG(rating), COUNT(*) INTO avg_rating, review_count
    FROM bot_reviews
    WHERE bot_id = COALESCE(NEW.bot_id, OLD.bot_id);
    
    UPDATE external_bots
    SET rating_average = COALESCE(avg_rating, 0.0),
        rating_count = review_count
    WHERE id = COALESCE(NEW.bot_id, OLD.bot_id);
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_bot_reviews_rating
AFTER INSERT OR UPDATE OR DELETE ON public.bot_reviews
FOR EACH ROW EXECUTE FUNCTION update_bot_rating();

-- Update updated_at timestamp
CREATE TRIGGER tr_external_bots_updated_at
BEFORE UPDATE ON public.external_bots
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_bot_installations_updated_at
BEFORE UPDATE ON public.bot_installations
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_bot_reviews_updated_at
BEFORE UPDATE ON public.bot_reviews
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
