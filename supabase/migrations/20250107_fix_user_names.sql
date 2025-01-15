-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_user_data_trigger ON auth.users;

-- Create or update users table
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT,
    name TEXT
);

-- Add missing columns if they don't exist
ALTER TABLE public.users 
    ADD COLUMN IF NOT EXISTS full_name TEXT,
    ADD COLUMN IF NOT EXISTS avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Set name column to not null with default from email
ALTER TABLE public.users 
    ALTER COLUMN name SET DEFAULT '',
    ALTER COLUMN name SET NOT NULL;

-- Update existing records to ensure name is not null
UPDATE public.users 
SET name = COALESCE(name, email, id::text) 
WHERE name IS NULL;

-- Create a function to sync user data
CREATE OR REPLACE FUNCTION sync_user_data()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, name, full_name, avatar_url, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(
            NEW.raw_user_meta_data->>'name',
            NEW.raw_user_meta_data->>'full_name',
            (SELECT name FROM public.users WHERE id = NEW.id),
            split_part(NEW.email, '@', 1)
        ),
        COALESCE(
            NEW.raw_user_meta_data->>'full_name',
            (SELECT full_name FROM public.users WHERE id = NEW.id),
            split_part(NEW.email, '@', 1)
        ),
        COALESCE(NEW.raw_user_meta_data->>'avatar_url', NULL),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE
    SET
        email = EXCLUDED.email,
        -- Only update name if it doesn't exist
        name = COALESCE(users.name, EXCLUDED.name),
        full_name = COALESCE(users.full_name, EXCLUDED.full_name),
        avatar_url = COALESCE(users.avatar_url, EXCLUDED.avatar_url),
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user data sync
CREATE TRIGGER sync_user_data_trigger
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_data();

-- Sync existing users
INSERT INTO public.users (id, email, name, full_name, avatar_url, updated_at)
SELECT 
    id,
    email,
    COALESCE(raw_user_meta_data->>'full_name', email),
    COALESCE(raw_user_meta_data->>'full_name', email),
    COALESCE(raw_user_meta_data->>'avatar_url', NULL),
    NOW()
FROM auth.users
ON CONFLICT (id) DO UPDATE
SET
    email = EXCLUDED.email,
    name = COALESCE(EXCLUDED.name, users.name),
    full_name = COALESCE(EXCLUDED.full_name, users.full_name),
    avatar_url = COALESCE(EXCLUDED.avatar_url, users.avatar_url),
    updated_at = NOW();

-- Ensure RLS is enabled
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Create policies for users table
DROP POLICY IF EXISTS "Users can view all users" ON users;
CREATE POLICY "Users can view all users"
    ON users FOR SELECT
    USING (true);  -- Everyone can view user profiles

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile"
    ON users FOR UPDATE
    USING (auth.uid() = id);

-- Grant necessary permissions
GRANT ALL ON public.users TO authenticated;
GRANT ALL ON public.users TO service_role; 