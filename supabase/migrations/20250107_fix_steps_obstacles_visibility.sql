-- Drop all existing policies for steps and obstacles
DROP POLICY IF EXISTS "Users can view steps" ON steps;
DROP POLICY IF EXISTS "Users can create steps" ON steps;
DROP POLICY IF EXISTS "Users can update steps" ON steps;
DROP POLICY IF EXISTS "Users can delete steps" ON steps;

DROP POLICY IF EXISTS "Users can view obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can create obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can update obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can delete obstacles" ON obstacles;

-- Create new policies for steps
CREATE POLICY "Users can view steps"
    ON steps FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM actions a
            JOIN targets t ON t.id = a.target_id
            WHERE a.id = steps.action_id
            AND (t.user_id = auth.uid() OR t.is_public = true)
        )
    );

CREATE POLICY "Users can create steps"
    ON steps FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM actions a
            JOIN targets t ON t.id = a.target_id
            WHERE a.id = action_id
            AND t.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update steps"
    ON steps FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM actions a
            JOIN targets t ON t.id = a.target_id
            WHERE a.id = steps.action_id
            AND t.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete steps"
    ON steps FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM actions a
            JOIN targets t ON t.id = a.target_id
            WHERE a.id = steps.action_id
            AND t.user_id = auth.uid()
        )
    );

-- Create new policies for obstacles
CREATE POLICY "Users can view obstacles"
    ON obstacles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM actions a
            JOIN targets t ON t.id = a.target_id
            WHERE a.id = obstacles.action_id
            AND (t.user_id = auth.uid() OR t.is_public = true)
        )
    );

CREATE POLICY "Users can create obstacles"
    ON obstacles FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM actions a
            JOIN targets t ON t.id = a.target_id
            WHERE a.id = action_id
            AND t.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update obstacles"
    ON obstacles FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM actions a
            JOIN targets t ON t.id = a.target_id
            WHERE a.id = obstacles.action_id
            AND t.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete obstacles"
    ON obstacles FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM actions a
            JOIN targets t ON t.id = a.target_id
            WHERE a.id = obstacles.action_id
            AND t.user_id = auth.uid()
        )
    );

-- Ensure RLS is enabled
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY; 