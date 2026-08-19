-- Migration 175: Server Subscriptions & Monetization Tiers

CREATE TABLE IF NOT EXISTS public.server_subscription_tiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    tier_name TEXT NOT NULL,
    price_cents INT NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    description TEXT,
    role_id UUID REFERENCES public.server_roles(id) ON DELETE SET NULL,
    perks TEXT[] DEFAULT ARRAY[]::TEXT[],
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.member_server_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    tier_id UUID NOT NULL REFERENCES public.server_subscription_tiers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active',
    current_period_end TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(tier_id, user_id)
);

ALTER TABLE public.server_subscription_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_server_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public view active subscription tiers" ON public.server_subscription_tiers
    FOR SELECT USING (is_active = true);

CREATE POLICY "Server owners manage subscription tiers" ON public.server_subscription_tiers
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.servers s
            WHERE s.id = server_subscription_tiers.server_id
            AND s.owner_id = auth.uid()
        )
    );

CREATE POLICY "Members view own subscriptions" ON public.member_server_subscriptions
    FOR SELECT USING (user_id = auth.uid());
