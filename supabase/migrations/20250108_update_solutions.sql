-- First, add the title column to solutions table
ALTER TABLE solutions 
ADD COLUMN IF NOT EXISTS title TEXT;

-- Update existing solutions to have a title based on description
UPDATE solutions 
SET title = COALESCE(title, description) 
WHERE title IS NULL;

-- Make title column NOT NULL
ALTER TABLE solutions 
ALTER COLUMN title SET NOT NULL;

-- Drop the description column
ALTER TABLE solutions
DROP COLUMN IF EXISTS description;

-- Enable realtime for solutions table
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

-- Drop existing indexes if they exist
DROP INDEX IF EXISTS idx_solutions_obstacle_id;
DROP INDEX IF EXISTS idx_solutions_completed;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_solutions_obstacle_id ON solutions(obstacle_id);
CREATE INDEX IF NOT EXISTS idx_solutions_completed ON solutions(completed);

-- Add RLS policies
DROP POLICY IF EXISTS "Users can view solutions" ON solutions;
DROP POLICY IF EXISTS "Users can manage solutions" ON solutions;

CREATE POLICY "Users can view solutions"
    ON solutions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM obstacles
        JOIN actions ON actions.id = obstacles.action_id
        JOIN targets ON targets.id = actions.target_id
        WHERE obstacles.id = solutions.obstacle_id
        AND (targets.user_id = auth.uid() OR targets.is_public = true)
    ));

CREATE POLICY "Users can manage solutions"
    ON solutions FOR ALL
    USING (EXISTS (
        SELECT 1 FROM obstacles
        JOIN actions ON actions.id = obstacles.action_id
        JOIN targets ON targets.id = actions.target_id
        WHERE obstacles.id = solutions.obstacle_id
        AND targets.user_id = auth.uid()
    )); 