-- Migration: Fix Broken Object-Level Authorization (BOLA) in Supabase Storage
-- Description: Drops permissive storage.objects policies and replaces them with checks restricting modifications to the owner's directory or verifying server permissions.

-- 1. avatars
DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;

CREATE POLICY "Users can upload their own avatar" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update their own avatar" ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own avatar" ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 2. server-icons
DROP POLICY IF EXISTS "Authenticated users can upload server icons" ON storage.objects;
DROP POLICY IF EXISTS "Users can update server icons" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete server icons" ON storage.objects;

CREATE POLICY "Authenticated users can upload server icons" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'server-icons' AND (
    EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_GUILD')
  )
);

CREATE POLICY "Users can update server icons" ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'server-icons' AND (
    EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_GUILD')
  )
)
WITH CHECK (
  bucket_id = 'server-icons' AND (
    EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_GUILD')
  )
);

CREATE POLICY "Users can delete server icons" ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'server-icons' AND (
    EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_GUILD')
  )
);

-- 3. banners
DROP POLICY IF EXISTS "Authenticated users can upload banners" ON storage.objects;
DROP POLICY IF EXISTS "Users can update banners" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete banners" ON storage.objects;

CREATE POLICY "Authenticated users can upload banners" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'banners' AND (
    (storage.foldername(name))[1] = auth.uid()::text 
    OR EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_GUILD')
  )
);

CREATE POLICY "Users can update banners" ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'banners' AND (
    (storage.foldername(name))[1] = auth.uid()::text 
    OR EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_GUILD')
  )
)
WITH CHECK (
  bucket_id = 'banners' AND (
    (storage.foldername(name))[1] = auth.uid()::text 
    OR EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_GUILD')
  )
);

CREATE POLICY "Users can delete banners" ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'banners' AND (
    (storage.foldername(name))[1] = auth.uid()::text 
    OR EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_GUILD')
  )
);

-- 4. attachments
DROP POLICY IF EXISTS "Authenticated users can upload attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own attachments" ON storage.objects;

CREATE POLICY "Authenticated users can upload attachments" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'attachments' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update their own attachments" ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'attachments' 
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'attachments' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own attachments" ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'attachments' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 5. emojis
DROP POLICY IF EXISTS "Authenticated users can upload emojis" ON storage.objects;
DROP POLICY IF EXISTS "Users can update emojis" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete emojis" ON storage.objects;

CREATE POLICY "Authenticated users can upload emojis" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'emojis' AND (
    EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_EMOJIS_AND_STICKERS')
  )
);

CREATE POLICY "Users can update emojis" ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'emojis' AND (
    EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_EMOJIS_AND_STICKERS')
  )
)
WITH CHECK (
  bucket_id = 'emojis' AND (
    EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_EMOJIS_AND_STICKERS')
  )
);

CREATE POLICY "Users can delete emojis" ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'emojis' AND (
    EXISTS (
      SELECT 1 FROM public.servers 
      WHERE id = (storage.foldername(name))[1]::uuid 
        AND owner_id = auth.uid()
    ) 
    OR public.has_server_permission(auth.uid(), (storage.foldername(name))[1]::uuid, 'MANAGE_EMOJIS_AND_STICKERS')
  )
);
