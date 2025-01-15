-- Drop all existing policies first
DROP POLICY IF EXISTS "Users can view actions" ON actions;
DROP POLICY IF EXISTS "Users can view steps" ON steps;
DROP POLICY IF EXISTS "Users can view obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can view tasks" ON tasks;
DROP POLICY IF EXISTS "Users can view solutions" ON solutions;
DROP POLICY IF EXISTS "Users can view notes" ON notes;

-- Drop existing update policies
DROP POLICY IF EXISTS "Users can update actions" ON actions;
DROP POLICY IF EXISTS "Users can update steps" ON steps;
DROP POLICY IF EXISTS "Users can update obstacles" ON obstacles;
DROP POLICY IF EXISTS "Users can update tasks" ON tasks;
DROP POLICY IF EXISTS "Users can update solutions" ON solutions;
DROP POLICY IF EXISTS "Users can update notes" ON notes;

-- Create unified view policy for actions
CREATE POLICY "Users can view actions"
    ON actions FOR SELECT
    USING (true);  -- Allow all authenticated users to view all actions

-- Create unified view policy for steps
CREATE POLICY "Users can view steps"
    ON steps FOR SELECT
    USING (true);  -- Allow all authenticated users to view all steps

-- Create unified view policy for obstacles
CREATE POLICY "Users can view obstacles"
    ON obstacles FOR SELECT
    USING (true);  -- Allow all authenticated users to view all obstacles

-- Create unified view policy for tasks
CREATE POLICY "Users can view tasks"
    ON tasks FOR SELECT
    USING (true);  -- Allow all authenticated users to view all tasks

-- Create unified view policy for solutions
CREATE POLICY "Users can view solutions"
    ON solutions FOR SELECT
    USING (true);  -- Allow all authenticated users to view all solutions

-- Create unified view policy for notes
CREATE POLICY "Users can view notes"
    ON notes FOR SELECT
    USING (true);  -- Allow all authenticated users to view all notes

-- Ensure RLS is enabled on all tables
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE solutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Grant SELECT permissions to authenticated users for all tables
GRANT SELECT ON actions TO authenticated;
GRANT SELECT ON steps TO authenticated;
GRANT SELECT ON obstacles TO authenticated;
GRANT SELECT ON tasks TO authenticated;
GRANT SELECT ON solutions TO authenticated;
GRANT SELECT ON notes TO authenticated;

-- Keep write policies unchanged - only owners can modify their own data
CREATE POLICY "Users can update actions"
    ON actions FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM targets t
            WHERE t.id = actions.target_id
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