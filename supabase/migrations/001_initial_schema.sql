-- Drop existing tables and triggers in correct order
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP TABLE IF EXISTS solutions CASCADE;
DROP TABLE IF EXISTS obstacles CASCADE;
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS steps CASCADE;
DROP TABLE IF EXISTS actions CASCADE;
DROP TABLE IF EXISTS targets CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    photo TEXT,
    age INTEGER,
    country TEXT,
    degree TEXT,
    profession TEXT,
    linkedin TEXT,
    languages TEXT[],
    industry TEXT,
    experience INTEGER,
    phone TEXT,
    website TEXT,
    twitter TEXT,
    github TEXT,
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own profile"
    ON users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON users FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON users FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Create targets table
CREATE TABLE targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category_id TEXT NOT NULL,
    subcategory_id TEXT NOT NULL,
    progress INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

-- Create actions table
CREATE TABLE actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    target_id UUID NOT NULL REFERENCES targets(id) ON DELETE CASCADE
);

-- Create steps table
CREATE TABLE steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    action_id UUID NOT NULL REFERENCES actions(id) ON DELETE CASCADE
);

-- Create tasks table
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    deadline TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    step_id UUID NOT NULL REFERENCES steps(id) ON DELETE CASCADE
);

-- Create obstacles table
CREATE TABLE obstacles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    description TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    progress INTEGER DEFAULT 0,
    resolved BOOLEAN DEFAULT FALSE,
    resolution TEXT,
    resolution_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    action_id UUID NOT NULL REFERENCES actions(id) ON DELETE CASCADE
);

-- Create solutions table
CREATE TABLE solutions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    description TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    deadline TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    obstacle_id UUID NOT NULL REFERENCES obstacles(id) ON DELETE CASCADE
);

-- Add indexes for better query performance
CREATE INDEX idx_targets_user_id ON targets(user_id);
CREATE INDEX idx_actions_target_id ON actions(target_id);
CREATE INDEX idx_steps_action_id ON steps(action_id);
CREATE INDEX idx_tasks_step_id ON tasks(step_id);
CREATE INDEX idx_obstacles_action_id ON obstacles(action_id);
CREATE INDEX idx_solutions_obstacle_id ON solutions(obstacle_id);

-- Disable RLS temporarily for debugging
ALTER TABLE targets DISABLE ROW LEVEL SECURITY;
ALTER TABLE actions DISABLE ROW LEVEL SECURITY;
ALTER TABLE steps DISABLE ROW LEVEL SECURITY;
ALTER TABLE tasks DISABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles DISABLE ROW LEVEL SECURITY;
ALTER TABLE solutions DISABLE ROW LEVEL SECURITY;

-- Grant permissions
GRANT ALL ON users TO authenticated;
GRANT ALL ON users TO anon;
GRANT ALL ON users TO service_role;

GRANT ALL ON targets TO authenticated;
GRANT ALL ON targets TO anon;
GRANT ALL ON targets TO service_role;

GRANT ALL ON actions TO authenticated;
GRANT ALL ON actions TO anon;
GRANT ALL ON actions TO service_role;

GRANT ALL ON steps TO authenticated;
GRANT ALL ON steps TO anon;
GRANT ALL ON steps TO service_role;

GRANT ALL ON tasks TO authenticated;
GRANT ALL ON tasks TO anon;
GRANT ALL ON tasks TO service_role;

GRANT ALL ON obstacles TO authenticated;
GRANT ALL ON obstacles TO anon;
GRANT ALL ON obstacles TO service_role;

GRANT ALL ON solutions TO authenticated;
GRANT ALL ON solutions TO anon;
GRANT ALL ON solutions TO service_role;

-- Create trigger function for handling new users
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, email, name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO UPDATE 
    SET 
        email = EXCLUDED.email,
        name = EXCLUDED.name;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
