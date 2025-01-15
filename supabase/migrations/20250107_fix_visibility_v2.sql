-- First, drop all existing policies
DROP POLICY IF EXISTS "Users can view steps" ON steps;
DROP POLICY IF EXISTS "Users can view obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can view tasks" ON tasks;
DROP POLICY IF EXISTS "Users can view solutions" ON solutions;

-- Create simplified view policies
CREATE POLICY "Users can view steps"
    ON steps FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN actions a ON a.target_id = t.id
            WHERE a.id = steps.action_id
            AND (t.is_public = true OR t.user_id = auth.uid())
        )
    );

CREATE POLICY "Users can view obstacles"
    ON obstacles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN actions a ON a.target_id = t.id
            WHERE a.id = obstacles.action_id
            AND (t.is_public = true OR t.user_id = auth.uid())
        )
    );

CREATE POLICY "Users can view tasks"
    ON tasks FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN actions a ON a.target_id = t.id
            JOIN steps s ON s.action_id = a.id
            WHERE s.id = tasks.step_id
            AND (t.is_public = true OR t.user_id = auth.uid())
        )
    );

CREATE POLICY "Users can view solutions"
    ON solutions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            JOIN actions a ON a.target_id = t.id
            JOIN obstacles o ON o.action_id = a.id
            WHERE o.id = solutions.obstacle_id
            AND (t.is_public = true OR t.user_id = auth.uid())
        )
    );

-- Grant necessary permissions
GRANT SELECT ON steps TO authenticated;
GRANT SELECT ON obstacles TO authenticated;
GRANT SELECT ON tasks TO authenticated;
GRANT SELECT ON solutions TO authenticated;

-- Ensure RLS is enabled
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE solutions ENABLE ROW LEVEL SECURITY; 