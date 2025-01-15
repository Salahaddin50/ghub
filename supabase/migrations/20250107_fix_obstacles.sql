-- Enable realtime for obstacles table (if not already enabled)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'obstacles'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE obstacles;
    END IF;
END
$$;

-- Ensure proper API access
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;
GRANT ALL ON obstacles TO authenticated;
GRANT ALL ON obstacles TO service_role;

-- First add or modify columns
ALTER TABLE obstacles 
    ADD COLUMN IF NOT EXISTS title TEXT,
    ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'medium',
    ADD COLUMN IF NOT EXISTS progress INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id),
    ALTER COLUMN completed SET DEFAULT false;

-- Update existing records with default values
UPDATE obstacles SET title = description WHERE title IS NULL;
UPDATE obstacles SET priority = 'medium' WHERE priority IS NULL;
UPDATE obstacles SET progress = 0 WHERE progress IS NULL;
UPDATE obstacles SET completed = false WHERE completed IS NULL;

-- Set user_id for existing records based on the target's user_id
UPDATE obstacles o
SET user_id = t.user_id
FROM actions a
JOIN targets t ON t.id = a.target_id
WHERE o.action_id = a.id
AND o.user_id IS NULL;

-- Drop existing constraints if they exist
ALTER TABLE obstacles 
    DROP CONSTRAINT IF EXISTS valid_priority,
    DROP CONSTRAINT IF EXISTS valid_progress;

-- Add constraints to ensure valid values
ALTER TABLE obstacles
    ADD CONSTRAINT valid_priority CHECK (priority IN ('low', 'medium', 'high')),
    ADD CONSTRAINT valid_progress CHECK (progress >= 0 AND progress <= 100),
    ALTER COLUMN title SET NOT NULL,
    ALTER COLUMN priority SET NOT NULL;

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_obstacles_action_priority;
DROP INDEX IF EXISTS idx_obstacles_completed;
DROP INDEX IF EXISTS idx_obstacles_progress;
DROP INDEX IF EXISTS idx_obstacles_user_id;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_obstacles_action_priority ON obstacles(action_id, priority);
CREATE INDEX IF NOT EXISTS idx_obstacles_completed ON obstacles(completed);
CREATE INDEX IF NOT EXISTS idx_obstacles_progress ON obstacles(progress);
CREATE INDEX IF NOT EXISTS idx_obstacles_user_id ON obstacles(user_id);

-- Create a function to get the target user_id for an action
CREATE OR REPLACE FUNCTION get_target_user_id(action_id UUID)
RETURNS UUID AS $$
    SELECT user_id FROM targets
    WHERE id = (SELECT target_id FROM actions WHERE id = $1);
$$ LANGUAGE sql SECURITY DEFINER;

-- Recreate obstacles policies
DROP POLICY IF EXISTS "Users can view obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can manage obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can create obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can update obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can delete obstacles" ON obstacles;

-- More specific policies for better control
CREATE POLICY "Users can view obstacles"
    ON obstacles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM actions
            JOIN targets ON targets.id = actions.target_id
            WHERE actions.id = obstacles.action_id
            AND (targets.user_id = auth.uid() OR targets.is_public = true)
        )
    );

CREATE POLICY "Users can create obstacles"
    ON obstacles FOR INSERT
    WITH CHECK (
        (user_id IS NULL OR user_id = auth.uid()) AND
        EXISTS (
            SELECT 1 FROM actions
            JOIN targets ON targets.id = actions.target_id
            WHERE actions.id = action_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update obstacles"
    ON obstacles FOR UPDATE
    USING (
        (user_id IS NULL OR user_id = auth.uid()) AND
        EXISTS (
            SELECT 1 FROM actions
            JOIN targets ON targets.id = actions.target_id
            WHERE actions.id = obstacles.action_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete obstacles"
    ON obstacles FOR DELETE
    USING (
        (user_id IS NULL OR user_id = auth.uid()) AND
        EXISTS (
            SELECT 1 FROM actions
            JOIN targets ON targets.id = actions.target_id
            WHERE actions.id = obstacles.action_id
            AND targets.user_id = auth.uid()
        )
    );

-- Create trigger to automatically set required fields
CREATE OR REPLACE FUNCTION set_obstacle_defaults()
RETURNS TRIGGER AS $$
BEGIN
    -- Set user_id if not provided
    IF NEW.user_id IS NULL THEN
        NEW.user_id := auth.uid();
    END IF;

    -- Set priority if not provided
    IF NEW.priority IS NULL THEN
        NEW.priority := 'medium';
    END IF;

    -- Set progress if not provided
    IF NEW.progress IS NULL THEN
        NEW.progress := 0;
    END IF;

    -- Set completed if not provided
    IF NEW.completed IS NULL THEN
        NEW.completed := false;
    END IF;

    -- Set title from description if not provided
    IF NEW.title IS NULL AND NEW.description IS NOT NULL THEN
        NEW.title := NEW.description;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS set_obstacle_defaults_trigger ON obstacles;
CREATE TRIGGER set_obstacle_defaults_trigger
    BEFORE INSERT ON obstacles
    FOR EACH ROW
    EXECUTE FUNCTION set_obstacle_defaults(); 