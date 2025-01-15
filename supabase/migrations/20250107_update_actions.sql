-- Add missing columns to actions table
ALTER TABLE actions
ADD COLUMN IF NOT EXISTS urgency TEXT,
ADD COLUMN IF NOT EXISTS impact TEXT;

-- Update RLS policies to include new fields
DROP POLICY IF EXISTS "Users can view actions of their targets" ON actions;
DROP POLICY IF EXISTS "Users can manage actions of their targets" ON actions;

-- Recreate policies
CREATE POLICY "Users can view actions of their targets"
    ON actions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM targets
        WHERE targets.id = actions.target_id
        AND (targets.user_id = auth.uid() OR targets.is_public = true)
    ));

CREATE POLICY "Users can manage actions of their targets"
    ON actions FOR ALL
    USING (EXISTS (
        SELECT 1 FROM targets
        WHERE targets.id = actions.target_id
        AND targets.user_id = auth.uid()
    )); 