-- Add read_by column to messages table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'messages' 
        AND column_name = 'read_by'
    ) THEN
        ALTER TABLE messages ADD COLUMN read_by UUID[] DEFAULT '{}';
    END IF;
END $$;

-- Add function to check if a message is unread by a user
CREATE OR REPLACE FUNCTION is_message_unread(message_row messages, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT (user_id = ANY(COALESCE(message_row.read_by, '{}')));
END;
$$ LANGUAGE plpgsql;

-- Create function to mark message as read
CREATE OR REPLACE FUNCTION mark_message_as_read(message_id UUID, user_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE messages
  SET read_by = array_append(COALESCE(read_by, '{}'), user_id)
  WHERE id = message_id
  AND NOT (user_id = ANY(COALESCE(read_by, '{}')));
END;
$$ LANGUAGE plpgsql;

-- Remove duplicate conversations and keep one per unique combination
WITH grouped_conversations AS (
  SELECT 
    target_id,
    participants,
    COUNT(*) as cnt
  FROM conversations 
  GROUP BY target_id, participants
  HAVING COUNT(*) > 1
),
duplicates AS (
  SELECT c.id, c.target_id, c.participants
  FROM conversations c
  INNER JOIN grouped_conversations g 
    ON c.target_id = g.target_id 
    AND c.participants = g.participants
  WHERE c.id NOT IN (
    SELECT id
    FROM conversations c2
    WHERE c2.target_id = g.target_id 
    AND c2.participants = g.participants
    ORDER BY c2.created_at ASC
    LIMIT 1
  )
)
DELETE FROM conversations c
USING duplicates d
WHERE c.id = d.id;

-- Add unique constraint for conversations
ALTER TABLE conversations
ADD CONSTRAINT unique_conversation 
UNIQUE (target_id, participants);

-- Drop counterpart_id if it exists
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'conversations' 
    AND column_name = 'counterpart_id'
  ) THEN
    ALTER TABLE conversations DROP COLUMN counterpart_id;
  END IF;
END $$;
