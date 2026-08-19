-- 001_bootstrap.sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    phone TEXT UNIQUE,
    encrypted_password TEXT NOT NULL,
    email_confirmed_at TIMESTAMPTZ,
    phone_confirmed_at TIMESTAMPTZ,
    raw_user_meta_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION current_user_id() RETURNS uuid AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_user_id', true), '')::uuid;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION current_user_role() RETURNS text AS $$
BEGIN
    RETURN COALESCE(NULLIF(current_setting('app.current_user_role', true), ''), 'authenticated');
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION current_jwt_claims() RETURNS jsonb AS $$
BEGIN
    RETURN COALESCE(NULLIF(current_setting('app.jwt_claims', true), ''), '{}')::jsonb;
END;
$$ LANGUAGE plpgsql STABLE;
