-- Drop indexes first
DROP INDEX IF EXISTS unique_conversation;
DROP INDEX IF EXISTS idx_sorted_participants;

-- Drop existing functions with all possible signatures
DROP FUNCTION IF EXISTS create_unique_conversation(uuid, uuid[], text);
DROP FUNCTION IF EXISTS create_unique_conversation(p_target_id uuid, p_participants uuid[], p_subject text);
DROP FUNCTION IF EXISTS sort_uuid_array(uuid[]);

-- Create function to sort UUID arrays
CREATE OR REPLACE FUNCTION sort_uuid_array(arr uuid[])
RETURNS uuid[] AS $$
  SELECT ARRAY(SELECT unnest($1) ORDER BY 1)
$$ LANGUAGE sql IMMUTABLE;

-- Create indexes using the new function
CREATE INDEX idx_sorted_participants 
ON conversations USING gin ((sort_uuid_array(participants)));

CREATE UNIQUE INDEX unique_conversation 
ON conversations (target_id, (sort_uuid_array(participants)));

-- Create unique conversation function with clear signature
CREATE OR REPLACE FUNCTION create_unique_conversation(
  target_id uuid,
  participants uuid[],
  subject text
) RETURNS conversations AS $$
DECLARE
  v_conversation conversations;
  v_sorted_participants uuid[];
BEGIN
  -- Sort participants array
  v_sorted_participants := sort_uuid_array(participants);

  -- First try to find an existing conversation
  SELECT c.* INTO v_conversation
  FROM conversations c
  WHERE c.target_id = target_id
    AND c.participants = v_sorted_participants
    AND NOT (c.deleted_by ?| participants);

  -- If found, return it
  IF FOUND THEN
    RETURN v_conversation;
  END IF;

  -- If not found, create a new one
  INSERT INTO conversations (
    participants,
    target_id,
    subject,
    deleted_by
  )
  VALUES (
    v_sorted_participants,
    target_id,
    COALESCE(subject, ''),
    '{}'::uuid[]
  )
  RETURNING * INTO v_conversation;

  RETURN v_conversation;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
