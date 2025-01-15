-- Enable realtime for steps table (if not already enabled)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'steps'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE steps;
    END IF;
END
$$;

-- Ensure proper API access
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
GRANT ALL ON steps TO authenticated;
GRANT ALL ON steps TO service_role;

-- First add or modify columns
ALTER TABLE steps 
    ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'medium',
    ADD COLUMN IF NOT EXISTS progress INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id),
    ALTER COLUMN completed SET DEFAULT false;

-- Update existing records with default values
UPDATE steps SET priority = 'medium' WHERE priority IS NULL;
UPDATE steps SET progress = 0 WHERE progress IS NULL;
UPDATE steps SET completed = false WHERE completed IS NULL;
-- Set user_id for existing records based on the target's user_id
UPDATE steps s
SET user_id = t.user_id
FROM actions a
JOIN targets t ON t.id = a.target_id
WHERE s.action_id = a.id
AND s.user_id IS NULL;

-- Drop existing constraints if they exist
ALTER TABLE steps 
    DROP CONSTRAINT IF EXISTS valid_priority,
    DROP CONSTRAINT IF EXISTS valid_progress;

-- Add constraints to ensure valid values
ALTER TABLE steps
    ADD CONSTRAINT valid_priority CHECK (priority IN ('low', 'medium', 'high')),
    ADD CONSTRAINT valid_progress CHECK (progress >= 0 AND progress <= 100);

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_steps_action_priority;
DROP INDEX IF EXISTS idx_steps_completed;
DROP INDEX IF EXISTS idx_steps_progress;
DROP INDEX IF EXISTS idx_steps_user_id;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_steps_action_priority ON steps(action_id, priority);
CREATE INDEX IF NOT EXISTS idx_steps_completed ON steps(completed);
CREATE INDEX IF NOT EXISTS idx_steps_progress ON steps(progress);
CREATE INDEX IF NOT EXISTS idx_steps_user_id ON steps(user_id);

-- Recreate steps policies
DROP POLICY IF EXISTS "Users can view steps" ON steps;
DROP POLICY IF EXISTS "Users can manage steps" ON steps;
DROP POLICY IF EXISTS "Users can create steps" ON steps;
DROP POLICY IF EXISTS "Users can update steps" ON steps;
DROP POLICY IF EXISTS "Users can delete steps" ON steps;

-- More specific policies for better control
CREATE POLICY "Users can view steps"
    ON steps FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM actions
            JOIN targets ON targets.id = actions.target_id
            WHERE actions.id = steps.action_id
            AND (targets.user_id = auth.uid() OR targets.is_public = true)
        )
    );

CREATE POLICY "Users can create steps"
    ON steps FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM actions
            JOIN targets ON targets.id = actions.target_id
            WHERE actions.id = action_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update steps"
    ON steps FOR UPDATE
    USING (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM actions
            JOIN targets ON targets.id = actions.target_id
            WHERE actions.id = steps.action_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete steps"
    ON steps FOR DELETE
    USING (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM actions
            JOIN targets ON targets.id = actions.target_id
            WHERE actions.id = steps.action_id
            AND targets.user_id = auth.uid()
        )
    ); 