-- Add read_by array to messages table to track who has read each message
ALTER TABLE messages ADD COLUMN IF NOT EXISTS read_by UUID[] DEFAULT '{}';

-- Add function to check if a message is unread by a user
CREATE OR REPLACE FUNCTION is_message_unread(message_row messages, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT (user_id = ANY(message_row.read_by));
END;
$$ LANGUAGE plpgsql;
