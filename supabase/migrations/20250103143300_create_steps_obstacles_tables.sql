-- Create steps table
CREATE TABLE IF NOT EXISTS steps (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT CHECK (priority IN ('low', 'medium', 'high')) DEFAULT 'medium',
    completed BOOLEAN DEFAULT false,
    progress INTEGER DEFAULT 0,
    action_id UUID REFERENCES actions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create obstacles table
CREATE TABLE IF NOT EXISTS obstacles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT false,
    action_id UUID REFERENCES actions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS steps_action_id_idx ON steps(action_id);
CREATE INDEX IF NOT EXISTS steps_user_id_idx ON steps(user_id);
CREATE INDEX IF NOT EXISTS obstacles_action_id_idx ON obstacles(action_id);
CREATE INDEX IF NOT EXISTS obstacles_user_id_idx ON obstacles(user_id);

-- Add RLS policies for steps
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own steps" ON steps;
CREATE POLICY "Users can read their own steps" ON steps
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own steps" ON steps;
CREATE POLICY "Users can insert their own steps" ON steps
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own steps" ON steps;
CREATE POLICY "Users can update their own steps" ON steps
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own steps" ON steps;
CREATE POLICY "Users can delete their own steps" ON steps
    FOR DELETE
    USING (auth.uid() = user_id);

-- Add RLS policies for obstacles
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own obstacles" ON obstacles;
CREATE POLICY "Users can read their own obstacles" ON obstacles
    FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own obstacles" ON obstacles;
CREATE POLICY "Users can insert their own obstacles" ON obstacles
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own obstacles" ON obstacles;
CREATE POLICY "Users can update their own obstacles" ON obstacles
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own obstacles" ON obstacles;
CREATE POLICY "Users can delete their own obstacles" ON obstacles
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for steps table
DROP TRIGGER IF EXISTS update_steps_updated_at ON steps;
CREATE TRIGGER update_steps_updated_at
    BEFORE UPDATE ON steps
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for obstacles table
DROP TRIGGER IF EXISTS update_obstacles_updated_at ON obstacles;
CREATE TRIGGER update_obstacles_updated_at
    BEFORE UPDATE ON obstacles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
