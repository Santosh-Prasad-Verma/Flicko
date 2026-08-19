-- Migration 160: Enable Row Level Security (RLS) on public.channel_background_blob_deletions
--
-- DESCRIPTION:
-- Table is used strictly by DB triggers and the backend worker.
-- Enabling RLS with no policies denies all public client/PostgREST access
-- to prevent potential data exposure/manipulation, while allowing trigger
-- insertions and service-role/superuser operations.

ALTER TABLE public.channel_background_blob_deletions ENABLE ROW LEVEL SECURITY;
