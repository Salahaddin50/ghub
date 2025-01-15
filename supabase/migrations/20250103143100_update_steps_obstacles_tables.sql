-- Update steps table
ALTER TABLE IF EXISTS steps
ADD COLUMN IF NOT EXISTS target_id UUID REFERENCES targets(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Update obstacles table
ALTER TABLE IF EXISTS obstacles
ADD COLUMN IF NOT EXISTS target_id UUID REFERENCES targets(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS steps_target_id_idx ON steps(target_id);
CREATE INDEX IF NOT EXISTS steps_user_id_idx ON steps(user_id);
CREATE INDEX IF NOT EXISTS obstacles_target_id_idx ON obstacles(target_id);
CREATE INDEX IF NOT EXISTS obstacles_user_id_idx ON obstacles(user_id);

-- Update RLS policies for steps
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

-- Update RLS policies for obstacles
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
