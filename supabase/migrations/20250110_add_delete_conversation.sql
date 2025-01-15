-- Function to delete a conversation
CREATE OR REPLACE FUNCTION public.delete_conversation(
  p_conversation_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if user is part of the conversation
  IF NOT EXISTS (
    SELECT 1 FROM conversations 
    WHERE id = p_conversation_id 
    AND auth.uid() = ANY(participants)
  ) THEN
    RAISE EXCEPTION 'User is not part of this conversation';
  END IF;

  -- Delete the conversation and all its messages (cascade)
  DELETE FROM conversations
  WHERE id = p_conversation_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.delete_conversation(UUID) TO authenticated; 