-- Migration: Server initialization trigger
-- Description: Automatically creates default channel, role, and adds owner as member when a server is created
-- Requirements: 6.7

-- Create function to handle new server creation
CREATE OR REPLACE FUNCTION public.handle_new_server()
RETURNS TRIGGER AS $$
DECLARE
  default_role_id UUID;
BEGIN
  -- Create default "@everyone" role
  INSERT INTO public.roles (server_id, name, permissions, position)
  VALUES (NEW.id, '@everyone', 0, 0)
  RETURNING id INTO default_role_id;
  
  -- Create default "general" text channel
  INSERT INTO public.channels (server_id, name, type, position)
  VALUES (NEW.id, 'general', 'text', 0);
  
  -- Add owner as first server member with default role
  INSERT INTO public.server_members (server_id, user_id, roles)
  VALUES (NEW.id, NEW.owner_id, ARRAY[default_role_id]);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on servers table
CREATE TRIGGER on_server_created
  AFTER INSERT ON public.servers
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_server();
