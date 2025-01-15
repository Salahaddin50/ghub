-- Enable realtime for solutions table (if not already enabled)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'solutions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE solutions;
    END IF;
END
$$;

-- Ensure proper API access
ALTER TABLE solutions ENABLE ROW LEVEL SECURITY;
GRANT ALL ON solutions TO authenticated;
GRANT ALL ON solutions TO service_role;

-- First add or modify columns
ALTER TABLE solutions 
    ADD COLUMN IF NOT EXISTS title TEXT,
    ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id),
    ALTER COLUMN completed SET DEFAULT false;

-- Update existing records with default values
UPDATE solutions SET title = description WHERE title IS NULL;
UPDATE solutions SET completed = false WHERE completed IS NULL;

-- Set user_id for existing records based on the obstacle's user_id
UPDATE solutions s
SET user_id = o.user_id
FROM obstacles o
WHERE s.obstacle_id = o.id
AND s.user_id IS NULL;

-- Add constraints to ensure valid values
ALTER TABLE solutions
    ALTER COLUMN title SET NOT NULL,
    ALTER COLUMN obstacle_id SET NOT NULL;

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_solutions_obstacle_id;
DROP INDEX IF EXISTS idx_solutions_completed;
DROP INDEX IF EXISTS idx_solutions_user_id;
DROP INDEX IF EXISTS idx_solutions_deadline;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_solutions_obstacle_id ON solutions(obstacle_id);
CREATE INDEX IF NOT EXISTS idx_solutions_completed ON solutions(completed);
CREATE INDEX IF NOT EXISTS idx_solutions_user_id ON solutions(user_id);
CREATE INDEX IF NOT EXISTS idx_solutions_deadline ON solutions(deadline);

-- Recreate solutions policies
DROP POLICY IF EXISTS "Users can view solutions" ON solutions;
DROP POLICY IF EXISTS "Users can manage solutions" ON solutions;
DROP POLICY IF EXISTS "Users can create solutions" ON solutions;
DROP POLICY IF EXISTS "Users can update solutions" ON solutions;
DROP POLICY IF EXISTS "Users can delete solutions" ON solutions;

-- More specific policies for better control
CREATE POLICY "Users can view solutions"
    ON solutions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM obstacles
            JOIN actions ON actions.id = obstacles.action_id
            JOIN targets ON targets.id = actions.target_id
            WHERE obstacles.id = solutions.obstacle_id
            AND (targets.user_id = auth.uid() OR targets.is_public = true)
        )
    );

CREATE POLICY "Users can create solutions"
    ON solutions FOR INSERT
    WITH CHECK (
        (user_id IS NULL OR user_id = auth.uid()) AND
        EXISTS (
            SELECT 1 FROM obstacles
            JOIN actions ON actions.id = obstacles.action_id
            JOIN targets ON targets.id = actions.target_id
            WHERE obstacles.id = obstacle_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update solutions"
    ON solutions FOR UPDATE
    USING (
        (user_id IS NULL OR user_id = auth.uid()) AND
        EXISTS (
            SELECT 1 FROM obstacles
            JOIN actions ON actions.id = obstacles.action_id
            JOIN targets ON targets.id = actions.target_id
            WHERE obstacles.id = solutions.obstacle_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete solutions"
    ON solutions FOR DELETE
    USING (
        (user_id IS NULL OR user_id = auth.uid()) AND
        EXISTS (
            SELECT 1 FROM obstacles
            JOIN actions ON actions.id = obstacles.action_id
            JOIN targets ON targets.id = actions.target_id
            WHERE obstacles.id = solutions.obstacle_id
            AND targets.user_id = auth.uid()
        )
    );

-- Create trigger to automatically set required fields
CREATE OR REPLACE FUNCTION set_solution_defaults()
RETURNS TRIGGER AS $$
BEGIN
    -- Set user_id if not provided
    IF NEW.user_id IS NULL THEN
        NEW.user_id := auth.uid();
    END IF;

    -- Set title from description if not provided
    IF NEW.title IS NULL AND NEW.description IS NOT NULL THEN
        NEW.title := NEW.description;
    END IF;

    -- Set completed if not provided
    IF NEW.completed IS NULL THEN
        NEW.completed := false;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS set_solution_defaults_trigger ON solutions;
CREATE TRIGGER set_solution_defaults_trigger
    BEFORE INSERT ON solutions
    FOR EACH ROW
    EXECUTE FUNCTION set_solution_defaults(); 