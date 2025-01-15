-- Drop existing policies
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can view their conversations" ON conversations;
    DROP POLICY IF EXISTS "Users can create conversations" ON conversations;
    DROP POLICY IF EXISTS "Users can mark conversations as deleted" ON conversations;
    DROP POLICY IF EXISTS "Users can delete their conversations" ON conversations;
    DROP POLICY IF EXISTS "Users can update their conversations" ON conversations;
EXCEPTION
    WHEN undefined_object THEN 
        NULL;
END $$;

-- Create function to safely mark conversation as deleted
CREATE OR REPLACE FUNCTION mark_conversation_as_deleted(conversation_id UUID, user_id UUID)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    is_participant boolean;
BEGIN
    -- Check if user is a participant
    SELECT EXISTS (
        SELECT 1 FROM conversations 
        WHERE id = conversation_id 
        AND user_id = ANY(participants)
    ) INTO is_participant;

    IF NOT is_participant THEN
        RETURN false;
    END IF;

    -- Update the deleted_by array
    UPDATE conversations 
    SET deleted_by = array_append(COALESCE(deleted_by, '{}'), user_id)
    WHERE id = conversation_id 
    AND NOT (user_id = ANY(COALESCE(deleted_by, '{}')));

    RETURN true;
END;
$$;

-- Recreate policies with proper permissions
CREATE POLICY "Users can view their conversations"
    ON conversations FOR SELECT
    USING (
        auth.uid() = ANY(participants) 
        AND NOT (auth.uid() = ANY(COALESCE(deleted_by, '{}')))
    );

CREATE POLICY "Users can create conversations"
    ON conversations FOR INSERT
    WITH CHECK (auth.uid() = ANY(participants));
