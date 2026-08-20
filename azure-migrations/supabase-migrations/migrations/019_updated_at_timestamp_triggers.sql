-- Migration: Updated_at timestamp triggers
-- Description: Automatically updates the updated_at timestamp when records are modified
-- Requirements: 1.1, 1.3, 1.4

-- Create function to handle updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on profiles table
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Create trigger on servers table
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON servers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Create trigger on channels table
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON channels
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
