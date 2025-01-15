-- Enable realtime for required tables
ALTER PUBLICATION supabase_realtime ADD TABLE actions;
ALTER PUBLICATION supabase_realtime ADD TABLE targets;

-- Ensure proper API access
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
GRANT ALL ON actions TO authenticated;
GRANT ALL ON actions TO service_role;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;

-- First add the new columns
ALTER TABLE actions 
    ADD COLUMN IF NOT EXISTS urgency TEXT,
    ADD COLUMN IF NOT EXISTS impact TEXT;

-- Update existing records with default values
UPDATE actions SET urgency = 'medium' WHERE urgency IS NULL;
UPDATE actions SET impact = 'medium' WHERE impact IS NULL;
UPDATE actions SET progress = 0 WHERE progress IS NULL;

-- Now set the default values for new records
ALTER TABLE actions 
    ALTER COLUMN urgency SET DEFAULT 'medium',
    ALTER COLUMN impact SET DEFAULT 'medium',
    ALTER COLUMN progress SET DEFAULT 0;

-- Add constraints to ensure valid values
ALTER TABLE actions
    ADD CONSTRAINT valid_urgency CHECK (urgency IN ('low', 'medium', 'high')),
    ADD CONSTRAINT valid_impact CHECK (impact IN ('low', 'medium', 'high')),
    ADD CONSTRAINT valid_progress CHECK (progress >= 0 AND progress <= 100);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_actions_target_urgency ON actions(target_id, urgency);
CREATE INDEX IF NOT EXISTS idx_actions_target_impact ON actions(target_id, impact);
CREATE INDEX IF NOT EXISTS idx_actions_progress ON actions(progress);

-- Recreate actions policies with proper access
DROP POLICY IF EXISTS "Users can view actions of their targets" ON actions;
DROP POLICY IF EXISTS "Users can manage actions of their targets" ON actions;
DROP POLICY IF EXISTS "Users can create actions" ON actions;
DROP POLICY IF EXISTS "Users can update actions" ON actions;
DROP POLICY IF EXISTS "Users can delete actions" ON actions;

-- More specific policies for better control
CREATE POLICY "Users can view actions of their targets"
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

CREATE POLICY "Users can update their actions"
    ON actions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM targets
            WHERE targets.id = actions.target_id
            AND targets.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete their actions"
    ON actions FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM targets
            WHERE targets.id = actions.target_id
            AND targets.user_id = auth.uid()
        )
    ); 