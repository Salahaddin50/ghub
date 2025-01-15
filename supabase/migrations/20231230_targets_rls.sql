-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own targets" ON targets;
DROP POLICY IF EXISTS "Users can view public targets" ON targets;
DROP POLICY IF EXISTS "Anyone can view public targets" ON targets;
DROP POLICY IF EXISTS "Users can insert their own targets" ON targets;
DROP POLICY IF EXISTS "Users can update their own targets" ON targets;
DROP POLICY IF EXISTS "Users can delete their own targets" ON targets;

-- Enable RLS for targets table
ALTER TABLE targets ENABLE ROW LEVEL SECURITY;

-- Create policies for targets table
CREATE POLICY "targets_select_policy"
    ON targets FOR SELECT
    USING (
        is_public = true   -- Allow access to all public targets
        OR 
        auth.uid() = user_id  -- Allow access to own targets
    );

CREATE POLICY "targets_insert_policy"
    ON targets FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "targets_update_policy"
    ON targets FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "targets_delete_policy"
    ON targets FOR DELETE
    USING (auth.uid() = user_id);

-- Grant access to authenticated and anonymous users
GRANT ALL ON targets TO authenticated;
GRANT SELECT ON targets TO anon;
GRANT SELECT ON users TO authenticated;
GRANT SELECT ON users TO anon;

-- Drop existing policies for related tables
DROP POLICY IF EXISTS "Anyone can view actions of public targets" ON actions;
DROP POLICY IF EXISTS "Anyone can view steps of public targets" ON steps;
DROP POLICY IF EXISTS "Anyone can view tasks of public targets" ON tasks;
DROP POLICY IF EXISTS "Anyone can view obstacles of public targets" ON obstacles;
DROP POLICY IF EXISTS "Anyone can view solutions of public targets" ON solutions;

-- Enable RLS for related tables
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;
ALTER TABLE solutions ENABLE ROW LEVEL SECURITY;

-- Create policies for actions table
CREATE POLICY "Anyone can view actions of public targets"
    ON actions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM targets 
        WHERE targets.id = actions.target_id 
        AND targets.is_public = true
    ));

-- Create policies for steps table
CREATE POLICY "Anyone can view steps of public targets"
    ON steps FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM actions 
        JOIN targets ON targets.id = actions.target_id 
        WHERE actions.id = steps.action_id 
        AND targets.is_public = true
    ));

-- Create policies for tasks table
CREATE POLICY "Anyone can view tasks of public targets"
    ON tasks FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM steps 
        JOIN actions ON actions.id = steps.action_id 
        JOIN targets ON targets.id = actions.target_id 
        WHERE steps.id = tasks.step_id 
        AND targets.is_public = true
    ));

-- Create policies for obstacles table
CREATE POLICY "Anyone can view obstacles of public targets"
    ON obstacles FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM actions 
        JOIN targets ON targets.id = actions.target_id 
        WHERE actions.id = obstacles.action_id 
        AND targets.is_public = true
    ));

-- Create policies for solutions table
CREATE POLICY "Anyone can view solutions of public targets"
    ON solutions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM obstacles 
        JOIN actions ON actions.id = obstacles.action_id 
        JOIN targets ON targets.id = actions.target_id 
        WHERE obstacles.id = solutions.obstacle_id 
        AND targets.is_public = true
    ));

-- Enable RLS for favorites table
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Create policies for favorites table
CREATE POLICY "favorites_select_policy"
    ON favorites FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "favorites_insert_policy"
    ON favorites FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites_update_policy"
    ON favorites FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "favorites_delete_policy"
    ON favorites FOR DELETE
    USING (auth.uid() = user_id);

GRANT ALL ON favorites TO authenticated;
