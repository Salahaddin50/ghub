-- Drop existing policies
DROP POLICY IF EXISTS "Users can view actions" ON actions;
DROP POLICY IF EXISTS "Users can create actions" ON actions;
DROP POLICY IF EXISTS "Users can update actions" ON actions;
DROP POLICY IF EXISTS "Users can delete actions" ON actions;

-- Create updated policies
CREATE POLICY "Users can view actions"
    ON actions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM targets
            WHERE targets.id = actions.target_id
            AND (targets.user_id = auth.uid() OR targets.is_public = true)
        )
    );

CREATE POLICY "Users can create actions"
    ON actions FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM targets
            WHERE targets.id = target_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update actions"
    ON actions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM targets
            WHERE targets.id = actions.target_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete actions"
    ON actions FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM targets
            WHERE targets.id = actions.target_id
            AND targets.user_id = auth.uid()
        )
    );

-- Ensure RLS is enabled
ALTER TABLE actions ENABLE ROW LEVEL SECURITY; 