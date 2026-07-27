-- supabase/migrations/132_creator_community_tables.sql

-- 1. Create creator community tables
CREATE TABLE IF NOT EXISTS public.creator_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content VARCHAR(1000) NOT NULL,
  media_urls TEXT[] DEFAULT '{}',
  parent_post_id UUID REFERENCES public.creator_posts(id) ON DELETE SET NULL, -- Soft orphan
  root_post_id UUID REFERENCES public.creator_posts(id) ON DELETE CASCADE,     -- Hard cascade of entire thread
  category TEXT DEFAULT 'general' CHECK (category IN ('general', 'qna', 'ideas', 'showcase')),
  title VARCHAR(200),
  accepted_answer_id UUID REFERENCES public.creator_posts(id) ON DELETE SET NULL,
  is_deleted BOOLEAN DEFAULT FALSE,
  flagged BOOLEAN DEFAULT FALSE,
  reply_count INT DEFAULT 0,
  like_count INT DEFAULT 0,
  repost_count INT DEFAULT 0,
  post_type TEXT NOT NULL CHECK (post_type IN ('tweet', 'discussion', 'qna')),
  visibility TEXT DEFAULT 'public' CHECK (visibility IN ('public', 'private')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Full-Text Search Optimization (SearchPosts)
ALTER TABLE public.creator_posts 
  ADD COLUMN search_vector TSVECTOR 
  GENERATED ALWAYS AS (to_tsvector('english', coalesce(title, '') || ' ' || content)) STORED;

CREATE TABLE IF NOT EXISTS public.creator_follows (
  follower_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'blocked', 'muted')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, following_id),
  CONSTRAINT chk_no_self_follow CHECK (follower_id <> following_id)
);

CREATE TABLE IF NOT EXISTS public.creator_post_likes (
  post_id UUID NOT NULL REFERENCES public.creator_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.creator_post_reposts (
  post_id UUID NOT NULL REFERENCES public.creator_posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

-- Track media uploads explicitly for secure presigned cleanups (Option C)
CREATE TABLE IF NOT EXISTS public.creator_media_uploads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  storage_path TEXT NOT NULL UNIQUE,
  post_id UUID REFERENCES public.creator_posts(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Indexes for performance, search and query pruning
CREATE INDEX IF NOT EXISTS idx_creator_posts_user_id        ON public.creator_posts(user_id);
CREATE INDEX IF NOT EXISTS idx_creator_posts_root_post_id   ON public.creator_posts(root_post_id);
CREATE INDEX IF NOT EXISTS idx_creator_posts_created_at     ON public.creator_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_creator_posts_search         ON public.creator_posts USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_creator_follows_follower     ON public.creator_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_creator_follows_following    ON public.creator_follows(following_id);
CREATE INDEX IF NOT EXISTS idx_creator_post_likes_post_id   ON public.creator_post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_creator_post_reposts_post_id ON public.creator_post_reposts(post_id);
CREATE INDEX IF NOT EXISTS idx_creator_media_uploads_post   ON public.creator_media_uploads(post_id);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.creator_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.creator_post_reposts ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
CREATE POLICY "Public read access for posts" ON public.creator_posts 
  FOR SELECT USING (is_deleted = FALSE AND flagged = FALSE);

CREATE POLICY "Authenticated users can create posts" ON public.creator_posts 
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authors can update/delete their own posts" ON public.creator_posts 
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Public read follows" ON public.creator_follows 
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can follow" ON public.creator_follows 
  FOR INSERT WITH CHECK (auth.uid() = follower_id);

-- UPDATE policy to support user follow block/mute actions
CREATE POLICY "Users can update their own follow status" ON public.creator_follows
  FOR UPDATE USING (auth.uid() = follower_id) WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow" ON public.creator_follows 
  FOR DELETE USING (auth.uid() = follower_id);

CREATE POLICY "Public read likes/reposts" ON public.creator_post_likes FOR SELECT USING (true);
CREATE POLICY "Public read reposts" ON public.creator_post_reposts FOR SELECT USING (true);

CREATE POLICY "Authenticated user like toggle" ON public.creator_post_likes 
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Authenticated user repost toggle" ON public.creator_post_reposts 
  FOR ALL USING (auth.uid() = user_id);

-- 5. AUTOMATIC DATABASE TRIGGERS FOR DENORMALIZED COUNTERS

-- A. Like Count Trigger
CREATE OR REPLACE FUNCTION public.handle_creator_post_like()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.creator_posts
    SET like_count = like_count + 1, updated_at = NOW()
    WHERE id = NEW.post_id AND is_deleted = FALSE;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.creator_posts
    SET like_count = GREATEST(0, like_count - 1), updated_at = NOW()
    WHERE id = OLD.post_id AND is_deleted = FALSE;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trg_creator_post_like
AFTER INSERT OR DELETE ON public.creator_post_likes
FOR EACH ROW EXECUTE FUNCTION public.handle_creator_post_like();

-- B. Repost Count Trigger
CREATE OR REPLACE FUNCTION public.handle_creator_post_repost()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.creator_posts
    SET repost_count = repost_count + 1, updated_at = NOW()
    WHERE id = NEW.post_id AND is_deleted = FALSE;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.creator_posts
    SET repost_count = GREATEST(0, repost_count - 1), updated_at = NOW()
    WHERE id = OLD.post_id AND is_deleted = FALSE;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trg_creator_post_repost
AFTER INSERT OR DELETE ON public.creator_post_reposts
FOR EACH ROW EXECUTE FUNCTION public.handle_creator_post_repost();

-- C. Reply Count Trigger (Handles INSERT, hard DELETE, and soft-delete via UPDATE of is_deleted)
CREATE OR REPLACE FUNCTION public.handle_creator_post_reply()
RETURNS TRIGGER AS $$
BEGIN
  -- Handle insertion of a new reply
  IF TG_OP = 'INSERT' AND NEW.parent_post_id IS NOT NULL THEN
    UPDATE public.creator_posts
    SET reply_count = reply_count + 1, updated_at = NOW()
    WHERE id = NEW.parent_post_id AND is_deleted = FALSE;

  -- Handle hard deletion of a reply
  ELSIF TG_OP = 'DELETE' AND OLD.parent_post_id IS NOT NULL THEN
    UPDATE public.creator_posts
    SET reply_count = GREATEST(0, reply_count - 1), updated_at = NOW()
    WHERE id = OLD.parent_post_id AND is_deleted = FALSE;

  -- Handle soft-delete via UPDATE (is_deleted changed from FALSE to TRUE)
  ELSIF TG_OP = 'UPDATE' 
    AND OLD.is_deleted = FALSE 
    AND NEW.is_deleted = TRUE 
    AND NEW.parent_post_id IS NOT NULL THEN
    UPDATE public.creator_posts
    SET reply_count = GREATEST(0, reply_count - 1), updated_at = NOW()
    WHERE id = NEW.parent_post_id AND is_deleted = FALSE;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trg_creator_post_reply
AFTER INSERT OR DELETE OR UPDATE OF is_deleted ON public.creator_posts
FOR EACH ROW EXECUTE FUNCTION public.handle_creator_post_reply();


-- 6. STORAGE BUCKET INITIALIZATION & SECURITY POLICIES

-- Initialize bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('creator-media', 'creator-media', true)
ON CONFLICT (id) DO NOTHING;

-- Enforce maximum file upload size of 50MB directly at storage level
UPDATE storage.buckets 
SET file_size_limit = 52428800  -- 50MB in bytes
WHERE id = 'creator-media';

-- Storage RLS Policies
CREATE POLICY "Public read for creator-media" ON storage.objects
  FOR SELECT USING (bucket_id = 'creator-media');

CREATE POLICY "Authenticated users can upload creator-media" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'creator-media' AND auth.role() = 'authenticated');

-- User media deletion policy to allow space cleanup when posts are deleted
CREATE POLICY "Users can delete their own creator-media" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'creator-media' 
    AND (storage.foldername(name))[2] = auth.uid()::text
  );
