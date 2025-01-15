-- First ensure actions are accessible
DROP POLICY IF EXISTS "Users can view actions" ON actions;
CREATE POLICY "Users can view actions"
    ON actions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            WHERE t.id = actions.target_id
            AND (t.is_public = true OR t.user_id = auth.uid())
        )
    );

-- Then update steps and obstacles policies
DROP POLICY IF EXISTS "Users can view steps" ON steps;
DROP POLICY IF EXISTS "Users can view obstacles" ON obstacles;

CREATE POLICY "Users can view steps"
    ON steps FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM actions a
            WHERE a.id = steps.action_id
            AND EXISTS (
                SELECT 1 FROM targets t
                WHERE t.id = a.target_id
                AND (t.is_public = true OR t.user_id = auth.uid())
            )
        )
    );

CREATE POLICY "Users can view obstacles"
    ON obstacles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM actions a
            WHERE a.id = obstacles.action_id
            AND EXISTS (
                SELECT 1 FROM targets t
                WHERE t.id = a.target_id
                AND (t.is_public = true OR t.user_id = auth.uid())
            )
        )
    );

-- Ensure RLS is enabled
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;

-- Grant necessary permissions
GRANT SELECT ON actions TO authenticated;
GRANT SELECT ON steps TO authenticated;
GRANT SELECT ON obstacles TO authenticated; 