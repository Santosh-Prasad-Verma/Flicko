-- Create storage bucket for server-icons
INSERT INTO storage.buckets (id, name, public)
VALUES ('server-icons', 'server-icons', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for server-icons bucket
CREATE POLICY "Server icons are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'server-icons');

CREATE POLICY "Authenticated users can upload server icons"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'server-icons' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can update server icons"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'server-icons' AND
  auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'server-icons' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can delete server icons"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'server-icons' AND
  auth.role() = 'authenticated'
);

-- Create storage bucket for attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('attachments', 'attachments', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for attachments bucket
CREATE POLICY "Attachments are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'attachments');

CREATE POLICY "Authenticated users can upload attachments"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'attachments' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can update their own attachments"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'attachments' AND
  auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'attachments' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can delete their own attachments"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'attachments' AND
  auth.role() = 'authenticated'
);

-- Create storage bucket for emojis
INSERT INTO storage.buckets (id, name, public)
VALUES ('emojis', 'emojis', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for emojis bucket
CREATE POLICY "Emojis are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'emojis');

CREATE POLICY "Authenticated users can upload emojis"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'emojis' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can update emojis"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'emojis' AND
  auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'emojis' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can delete emojis"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'emojis' AND
  auth.role() = 'authenticated'
);

-- Create storage bucket for banners
INSERT INTO storage.buckets (id, name, public)
VALUES ('banners', 'banners', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for banners bucket
CREATE POLICY "Banners are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'banners');

CREATE POLICY "Authenticated users can upload banners"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'banners' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can update banners"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'banners' AND
  auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'banners' AND
  auth.role() = 'authenticated'
);

CREATE POLICY "Users can delete banners"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'banners' AND
  auth.role() = 'authenticated'
);
