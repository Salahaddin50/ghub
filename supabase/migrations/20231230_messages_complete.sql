-- Create conversations table to track conversations between users
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    subject TEXT,
    target_id UUID REFERENCES targets(id) ON DELETE SET NULL,
    -- Store participants as an array of user IDs
    participants UUID[] NOT NULL,
    -- Ensure at least 2 participants
    CONSTRAINT min_participants CHECK (array_length(participants, 1) >= 2)
);

-- Create messages table
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP WITH TIME ZONE
);

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

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- RLS policies for conversations
CREATE POLICY "Users can view their conversations"
    ON conversations FOR SELECT
    USING (auth.uid() = ANY(participants));

CREATE POLICY "Users can create conversations"
    ON conversations FOR INSERT
    WITH CHECK (auth.uid() = ANY(participants));

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

-- Drop existing policies if they exist
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can read messages in their conversations" ON messages;
    DROP POLICY IF EXISTS "Users can insert messages in their conversations" ON messages;
    DROP POLICY IF EXISTS "Users can update read_by for messages in their conversations" ON messages;
EXCEPTION
    WHEN undefined_object THEN 
        NULL;
END $$;

-- Update RLS policies for messages
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read messages in their conversations"
ON messages FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND auth.uid() = ANY(c.participants)
  )
);

CREATE POLICY "Users can insert messages in their conversations"
ON messages FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = conversation_id
    AND auth.uid() = ANY(c.participants)
  )
);

CREATE POLICY "Users can update read_by for messages in their conversations"
ON messages FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND auth.uid() = ANY(c.participants)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND auth.uid() = ANY(c.participants)
  )
);

-- Add function to check if a message is unread by a user
CREATE OR REPLACE FUNCTION is_message_unread(message_row messages, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT (user_id = ANY(message_row.read_by));
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

-- Function to update conversation updated_at timestamp
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE conversations
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update conversation timestamp when new message is added
CREATE TRIGGER update_conversation_timestamp
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_timestamp();

-- Grant access to authenticated users
GRANT ALL ON conversations TO authenticated;
GRANT ALL ON messages TO authenticated;
