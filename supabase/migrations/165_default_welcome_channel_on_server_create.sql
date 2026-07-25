-- Migration 163: Default welcome channel and welcome_settings on server creation
-- Creates #welcome channel alongside #general and links welcome_settings automatically.

CREATE OR REPLACE FUNCTION public.handle_new_server()
RETURNS TRIGGER AS $$
DECLARE
  default_role_id UUID;
  general_channel_id UUID;
  welcome_channel_id UUID;
BEGIN
  -- 1. Create default "@everyone" role
  INSERT INTO public.roles (server_id, name, permissions, position)
  VALUES (NEW.id, '@everyone', 0, 0)
  RETURNING id INTO default_role_id;
  
  -- 2. Create default "general" text channel
  INSERT INTO public.channels (server_id, name, type, position)
  VALUES (NEW.id, 'general', 'text', 0)
  RETURNING id INTO general_channel_id;

  -- 3. Create default "welcome" text channel
  INSERT INTO public.channels (server_id, name, type, position)
  VALUES (NEW.id, 'welcome', 'text', 1)
  RETURNING id INTO welcome_channel_id;
  
  -- 4. Add owner as first server member with default role
  INSERT INTO public.server_members (server_id, user_id, roles)
  VALUES (NEW.id, NEW.owner_id, ARRAY[default_role_id]);
  
  -- 5. Initialize welcome_settings for the server with welcome_channel_id set to #welcome
  INSERT INTO public.welcome_settings (
    server_id,
    enabled,
    welcome_channel_id,
    welcome_message,
    welcome_card_enabled
  )
  VALUES (
    NEW.id,
    true,
    welcome_channel_id,
    'Welcome to {{server}}, {{user}}! 🎉 We are glad to have you here!',
    true
  )
  ON CONFLICT (server_id) DO UPDATE SET
    enabled = true,
    welcome_channel_id = EXCLUDED.welcome_channel_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
