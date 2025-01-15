-- Add deleted_by column to conversations table
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS deleted_by UUID[] DEFAULT '{}';

-- Update the view policy to exclude conversations that the user has deleted
DROP POLICY IF EXISTS "Users can view their conversations" ON conversations;
CREATE POLICY "Users can view their conversations"
    ON conversations FOR SELECT
    USING (
        auth.uid() = ANY(participants) 
        AND NOT (auth.uid() = ANY(COALESCE(deleted_by, '{}')))
    );

-- No need for delete policy anymore as we'll use UPDATE to mark as deleted
DROP POLICY IF EXISTS "Users can delete their conversations" ON conversations;

-- Add policy to allow users to update deleted_by
CREATE POLICY "Users can mark conversations as deleted"
    ON conversations FOR UPDATE
    USING (auth.uid() = ANY(participants))
    WITH CHECK (
        -- Only allow updating deleted_by column
        auth.uid() = ANY(participants)
    );
