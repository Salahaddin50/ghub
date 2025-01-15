-- First drop all policies
DROP POLICY IF EXISTS "Users can view their conversations" ON conversations;
DROP POLICY IF EXISTS "Users can create conversations they're part of" ON conversations;
DROP POLICY IF EXISTS "Users can update conversations they're part of" ON conversations;
DROP POLICY IF EXISTS "Users can view their messages" ON messages;
DROP POLICY IF EXISTS "Users can create messages in their conversations" ON messages;
DROP POLICY IF EXISTS "Users can update their messages" ON messages;

-- Drop constraints and indexes
ALTER TABLE IF EXISTS conversations DROP CONSTRAINT IF EXISTS unique_conversation;
DROP INDEX IF EXISTS idx_unique_conversation;
DROP INDEX IF EXISTS idx_sorted_participants;
DROP INDEX IF EXISTS idx_conversations_participants;
DROP INDEX IF EXISTS idx_conversations_target;
DROP INDEX IF EXISTS idx_messages_conversation;
DROP INDEX IF EXISTS idx_messages_sender;
DROP INDEX IF EXISTS idx_messages_read_by;

-- Drop existing functions
DROP FUNCTION IF EXISTS create_unique_conversation(uuid, uuid[], text) CASCADE;
DROP FUNCTION IF EXISTS create_unique_conversation(p_target_id uuid, p_participants uuid[], p_subject text) CASCADE;
DROP FUNCTION IF EXISTS get_or_create_conversation(uuid, uuid[], text) CASCADE;
DROP FUNCTION IF EXISTS mark_message_as_read(uuid) CASCADE;
DROP FUNCTION IF EXISTS sort_uuid_array(uuid[]) CASCADE;

-- Drop and recreate tables
DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS conversations;

CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    participants UUID[] NOT NULL,
    target_id UUID NOT NULL REFERENCES targets(id) ON DELETE CASCADE,
    subject TEXT NOT NULL DEFAULT '',
    deleted_by UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT participants_not_empty CHECK (array_length(participants, 1) > 0)
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    read_by UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create helper function for array operations
CREATE OR REPLACE FUNCTION sort_uuid_array(arr UUID[])
RETURNS UUID[] AS $$
    SELECT array_agg(x ORDER BY x)
    FROM unnest(arr) x;
$$ LANGUAGE SQL IMMUTABLE;

-- Create indexes
CREATE INDEX idx_conversations_participants ON conversations USING GIN (participants);
CREATE INDEX idx_conversations_target ON conversations(target_id);
CREATE UNIQUE INDEX idx_unique_conversation ON conversations (target_id, (sort_uuid_array(participants)));
CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_read_by ON messages USING GIN (read_by);

-- Function to create or get unique conversation
CREATE OR REPLACE FUNCTION get_or_create_conversation(
    target_id UUID,
    participants UUID[],
    subject TEXT DEFAULT ''
) RETURNS conversations AS $$
DECLARE
    v_conversation conversations;
    v_sorted_participants UUID[];
BEGIN
    -- Sort participants for consistent lookup
    v_sorted_participants := sort_uuid_array(participants);
    
    -- Try to find existing conversation
    SELECT * INTO v_conversation
    FROM conversations
    WHERE conversations.target_id = get_or_create_conversation.target_id
    AND conversations.participants = v_sorted_participants
    AND NOT (conversations.deleted_by && get_or_create_conversation.participants);
    
    -- Return if found
    IF FOUND THEN
        RETURN v_conversation;
    END IF;
    
    -- Create new conversation if not found
    INSERT INTO conversations (participants, target_id, subject)
    VALUES (v_sorted_participants, target_id, subject)
    RETURNING * INTO v_conversation;
    
    RETURN v_conversation;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark message as read
CREATE OR REPLACE FUNCTION mark_message_as_read(
    message_id UUID
) RETURNS messages AS $$
DECLARE
    v_message messages;
BEGIN
    UPDATE messages
    SET read_by = array_append(read_by, auth.uid())
    WHERE id = message_id
    AND NOT (auth.uid() = ANY(read_by))
    AND EXISTS (
        SELECT 1 FROM conversations
        WHERE conversations.id = messages.conversation_id
        AND auth.uid() = ANY(conversations.participants)
        AND NOT (auth.uid() = ANY(conversations.deleted_by))
    )
    RETURNING * INTO v_message;
    
    RETURN v_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Conversation Policies
CREATE POLICY "Users can view their conversations"
ON conversations FOR SELECT
TO authenticated
USING (
    auth.uid() = ANY(participants)
    AND NOT (auth.uid() = ANY(deleted_by))
);

CREATE POLICY "Users can create conversations they're part of"
ON conversations FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = ANY(participants)
);

CREATE POLICY "Users can update conversations they're part of"
ON conversations FOR UPDATE
TO authenticated
USING (
    auth.uid() = ANY(participants)
)
WITH CHECK (
    auth.uid() = ANY(participants)
);

-- Message Policies
CREATE POLICY "Users can view their messages"
ON messages FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM conversations
        WHERE conversations.id = messages.conversation_id
        AND auth.uid() = ANY(conversations.participants)
        AND NOT (auth.uid() = ANY(conversations.deleted_by))
    )
);

CREATE POLICY "Users can create messages in their conversations"
ON messages FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM conversations
        WHERE conversations.id = messages.conversation_id
        AND auth.uid() = ANY(conversations.participants)
        AND NOT (auth.uid() = ANY(conversations.deleted_by))
    )
    AND sender_id = auth.uid()
);

CREATE POLICY "Users can update their messages"
ON messages FOR UPDATE
TO authenticated
USING (
    sender_id = auth.uid()
)
WITH CHECK (
    sender_id = auth.uid()
);
