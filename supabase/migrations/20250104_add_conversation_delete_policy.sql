-- Add DELETE policy for conversations
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can delete their conversations" ON conversations;
EXCEPTION
    WHEN undefined_object THEN 
        NULL;
END $$;

CREATE POLICY "Users can delete their conversations"
    ON conversations FOR DELETE
    USING (auth.uid() = ANY(participants));
