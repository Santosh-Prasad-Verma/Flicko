-- Migration: Fix server creation RLS and add server-banners bucket
-- Fixes: "new row violates row-level security policy for table servers"
-- Adds: server-banners storage bucket, owner SELECT policy, create_server_rpc function

-- 1. Owner can always SELECT their own servers (fixes insert().select() chain)
DROP POLICY IF EXISTS "Owners can view their own servers" ON servers;
CREATE POLICY "Owners can view their own servers"
  ON servers FOR SELECT
  USING (owner_id = auth.uid());

-- 2. SECURITY DEFINER function for robust server creation (bypasses RLS)
CREATE OR REPLACE FUNCTION public.create_server_rpc(
  p_name TEXT,
  p_description TEXT DEFAULT NULL,
  p_icon TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_server RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'Server name is required';
  END IF;
  IF length(trim(p_name)) > 100 THEN
    RAISE EXCEPTION 'Server name must be 100 characters or less';
  END IF;

  INSERT INTO public.servers (name, description, icon, owner_id)
  VALUES (trim(p_name), p_description, p_icon, v_user_id)
  RETURNING * INTO v_server;

  RETURN jsonb_build_object(
    'id', v_server.id,
    'name', v_server.name,
    'description', v_server.description,
    'icon', v_server.icon,
    'banner', v_server.banner,
    'owner_id', v_server.owner_id,
    'region', v_server.region,
    'created_at', v_server.created_at,
    'updated_at', v_server.updated_at
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_server_rpc(TEXT, TEXT, TEXT) TO authenticated;

-- 3. Create server-banners storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('server-banners', 'server-banners', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Server banners are publicly accessible" ON storage.objects;
CREATE POLICY "Server banners are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'server-banners');

DROP POLICY IF EXISTS "Authenticated users can upload server banners" ON storage.objects;
CREATE POLICY "Authenticated users can upload server banners"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'server-banners' AND
  auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Users can update server banners" ON storage.objects;
CREATE POLICY "Users can update server banners"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'server-banners' AND
  auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'server-banners' AND
  auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Users can delete server banners" ON storage.objects;
CREATE POLICY "Users can delete server banners"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'server-banners' AND
  auth.role() = 'authenticated'
);
