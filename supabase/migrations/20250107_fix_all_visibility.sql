-- Update steps policies
DROP POLICY IF EXISTS "Users can view steps" ON steps;
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

-- Update tasks policies
DROP POLICY IF EXISTS "Users can view tasks" ON tasks;
CREATE POLICY "Users can view tasks"
    ON tasks FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM steps
            JOIN actions ON actions.id = steps.action_id
            JOIN targets ON targets.id = actions.target_id
            WHERE steps.id = tasks.step_id
            AND (targets.user_id = auth.uid() OR targets.is_public = true)
        )
    );

-- Update obstacles policies
DROP POLICY IF EXISTS "Users can view obstacles" ON obstacles;
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

-- Update solutions policies
DROP POLICY IF EXISTS "Users can view solutions" ON solutions;
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

-- Ensure RLS is enabled on all tables
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;
ALTER TABLE solutions ENABLE ROW LEVEL SECURITY; 