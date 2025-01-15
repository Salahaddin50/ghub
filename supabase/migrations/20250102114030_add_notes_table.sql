-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can read notes for their targets" ON notes;
DROP POLICY IF EXISTS "Users can create notes for their targets" ON notes;
DROP POLICY IF EXISTS "Users can update their own notes" ON notes;
DROP POLICY IF EXISTS "Users can delete their own notes" ON notes;

-- Create notes table if it doesn't exist
CREATE TABLE IF NOT EXISTS notes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content TEXT NOT NULL,
    entity_id UUID NOT NULL,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('step', 'obstacle', 'action')),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add RLS policies
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to read notes for entities they have access to
CREATE POLICY "Users can read notes for their targets" ON notes
    FOR SELECT
    USING (
        user_id IN (
            SELECT user_id FROM targets
            WHERE id IN (
                SELECT target_id FROM actions WHERE id = entity_id
                UNION
                SELECT target_id FROM actions WHERE id IN (
                    SELECT action_id FROM steps WHERE id = entity_id
                    UNION
                    SELECT action_id FROM obstacles WHERE id = entity_id
                )
            )
        )
    );

-- Policy to allow users to create notes for entities they own
CREATE POLICY "Users can create notes for their targets" ON notes
    FOR INSERT
    WITH CHECK (
        user_id IN (
            SELECT user_id FROM targets
            WHERE id IN (
                SELECT target_id FROM actions WHERE id = entity_id
                UNION
                SELECT target_id FROM actions WHERE id IN (
                    SELECT action_id FROM steps WHERE id = entity_id
                    UNION
                    SELECT action_id FROM obstacles WHERE id = entity_id
                )
            )
        )
    );

-- Policy to allow users to update their own notes
CREATE POLICY "Users can update their own notes" ON notes
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy to allow users to delete their own notes
CREATE POLICY "Users can delete their own notes" ON notes
    FOR DELETE
    USING (auth.uid() = user_id);

-- Add indexes for better query performance
DROP INDEX IF EXISTS notes_entity_id_idx;
DROP INDEX IF EXISTS notes_entity_type_idx;
DROP INDEX IF EXISTS notes_user_id_idx;
DROP INDEX IF EXISTS notes_created_at_idx;

CREATE INDEX notes_entity_id_idx ON notes(entity_id);
CREATE INDEX notes_entity_type_idx ON notes(entity_type);
CREATE INDEX notes_user_id_idx ON notes(user_id);
CREATE INDEX notes_created_at_idx ON notes(created_at DESC);

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS update_notes_updated_at ON notes;
DROP FUNCTION IF EXISTS update_notes_updated_at();

-- Trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_notes_updated_at
    BEFORE UPDATE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION update_notes_updated_at();
