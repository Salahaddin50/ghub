-- Create a function to handle new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  name_from_metadata text;
BEGIN
  -- Extract name from metadata
  name_from_metadata := NEW.raw_user_meta_data->>'name';
  
  -- Insert into users table
  INSERT INTO public.users (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      name_from_metadata,
      NEW.raw_user_meta_data->>'full_name',
      split_part(NEW.email, '@', 1)
    )
  );
  RETURN NEW;
END;
$$;

-- Create trigger for new user registration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Update existing users that might be missing names
UPDATE public.users
SET name = COALESCE(
  name,
  (
    SELECT raw_user_meta_data->>'name'
    FROM auth.users
    WHERE auth.users.id = public.users.id
  ),
  (
    SELECT raw_user_meta_data->>'full_name'
    FROM auth.users
    WHERE auth.users.id = public.users.id
  ),
  split_part(email, '@', 1)
)
WHERE name IS NULL; 