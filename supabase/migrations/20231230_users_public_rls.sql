-- Drop existing policy
DROP POLICY IF EXISTS "Anyone can view user profiles of public targets" ON users;

-- Create policy to allow viewing user profiles of public targets
CREATE POLICY "Anyone can view user profiles of public targets"
    ON users FOR SELECT
    USING (
        EXISTS (
            SELECT 1
            FROM targets
            WHERE targets.user_id = users.id
            AND targets.is_public = true
        )
    );
