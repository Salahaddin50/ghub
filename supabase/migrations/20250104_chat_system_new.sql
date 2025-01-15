-- Drop existing objects
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP FUNCTION IF EXISTS sort_uuid_array CASCADE;
DROP FUNCTION IF EXISTS get_conversation CASCADE;
DROP FUNCTION IF EXISTS create_conversation CASCADE;
DROP FUNCTION IF EXISTS send_message CASCADE;
DROP FUNCTION IF EXISTS mark_message_read CASCADE;
DROP FUNCTION IF EXISTS get_or_create_conversation CASCADE;

-- Helper function for array operations
CREATE OR REPLACE FUNCTION sort_uuid_array(arr UUID[])
RETURNS UUID[] AS $$
    SELECT array_agg(x ORDER BY x)
    FROM unnest(arr) x;
$$ LANGUAGE SQL IMMUTABLE;

-- Create tables with proper constraints
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    target_id UUID NOT NULL REFERENCES targets(id) ON DELETE CASCADE,
    participants UUID[] NOT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_message_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    CONSTRAINT participants_not_empty CHECK (array_length(participants, 1) >= 2),
    CONSTRAINT participants_unique CHECK (array_length(participants, 1) = array_length(sort_uuid_array(participants), 1))
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    content TEXT NOT NULL CHECK (length(trim(content)) > 0),
    read_by UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create indexes for better performance
CREATE INDEX idx_conversations_target ON conversations(target_id);
CREATE INDEX idx_conversations_participants ON conversations USING GIN (participants);
CREATE INDEX idx_conversations_last_message ON conversations(last_message_at DESC);
CREATE UNIQUE INDEX idx_unique_conversation ON conversations (target_id, (sort_uuid_array(participants)));

CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_created ON messages(created_at DESC);
CREATE INDEX idx_messages_read_by ON messages USING GIN (read_by);

-- Function to get or create a conversation
CREATE OR REPLACE FUNCTION get_or_create_conversation(
    p_participants UUID[],
    p_target_id UUID
) RETURNS UUID AS $$
DECLARE
    v_sorted_participants UUID[];
    v_conversation_id UUID;
BEGIN
    -- Sort participants for consistent lookup
    v_sorted_participants := sort_uuid_array(p_participants);
    
    -- Check if conversation exists
    SELECT id INTO v_conversation_id
    FROM conversations
    WHERE target_id = p_target_id
    AND participants = v_sorted_participants;
    
    -- Return existing conversation
    IF FOUND THEN
        RETURN v_conversation_id;
    END IF;
    
    -- Create new conversation
    INSERT INTO conversations (
        target_id,
        participants,
        created_by,
        metadata
    )
    VALUES (
        p_target_id,
        v_sorted_participants,
        auth.uid(),
        jsonb_build_object(
            'target_title', (SELECT title FROM targets WHERE id = p_target_id)
        )
    )
    RETURNING id INTO v_conversation_id;
    
    RETURN v_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to send a message
CREATE OR REPLACE FUNCTION send_message(
    p_conversation_id UUID,
    p_content TEXT
) RETURNS messages AS $$
DECLARE
    v_message messages;
BEGIN
    -- Insert message
    INSERT INTO messages (
        conversation_id,
        sender_id,
        content,
        read_by
    )
    VALUES (
        p_conversation_id,
        auth.uid(),
        trim(p_content),
        ARRAY[auth.uid()]
    )
    RETURNING * INTO v_message;
    
    -- Update conversation last_message_at
    UPDATE conversations
    SET last_message_at = v_message.created_at,
        updated_at = v_message.created_at
    WHERE id = p_conversation_id;
    
    RETURN v_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark message as read
CREATE OR REPLACE FUNCTION mark_message_read(
    p_message_id UUID
) RETURNS messages AS $$
DECLARE
    v_message messages;
BEGIN
    UPDATE messages
    SET read_by = array_append(read_by, auth.uid())
    WHERE id = p_message_id
    AND NOT (auth.uid() = ANY(read_by))
    AND EXISTS (
        SELECT 1 FROM conversations
        WHERE conversations.id = messages.conversation_id
        AND auth.uid() = ANY(conversations.participants)
    )
    RETURNING * INTO v_message;
    
    RETURN v_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable RLS
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Conversation Policies
CREATE POLICY "Users can view conversations they're part of" ON conversations
    FOR SELECT TO authenticated
    USING (auth.uid() = ANY(participants));

CREATE POLICY "Users can create conversations they're part of" ON conversations
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = ANY(participants)
        AND auth.uid() = created_by
        AND array_length(participants, 1) >= 2
    );

CREATE POLICY "Users can update conversations they're part of" ON conversations
    FOR UPDATE TO authenticated
    USING (auth.uid() = ANY(participants))
    WITH CHECK (auth.uid() = ANY(participants));

-- Message Policies
CREATE POLICY "Users can view messages in their conversations" ON messages
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = conversation_id
            AND auth.uid() = ANY(c.participants)
        )
    );

CREATE POLICY "Users can send messages to their conversations" ON messages
    FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM conversations
            WHERE conversations.id = conversation_id
            AND auth.uid() = ANY(conversations.participants)
        )
    );

CREATE POLICY "Users can update their own messages" ON messages
    FOR UPDATE TO authenticated
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());

CREATE POLICY "Users can update read_by in their messages" ON messages
    FOR UPDATE TO authenticated
    USING (
        -- User must be in the conversation
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = conversation_id
            AND auth.uid() = ANY(c.participants)
        )
    );

-- Function to validate message updates
CREATE OR REPLACE FUNCTION validate_message_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Only allow updating read_by array
    IF (NEW.id != OLD.id OR
        NEW.conversation_id != OLD.conversation_id OR
        NEW.sender_id != OLD.sender_id OR
        NEW.content != OLD.content OR
        NEW.created_at != OLD.created_at OR
        NEW.metadata != OLD.metadata) THEN
        RAISE EXCEPTION 'Can only update read_by field';
    END IF;

    -- Ensure read_by is only being appended to
    IF NOT (NEW.read_by @> OLD.read_by) THEN
        RAISE EXCEPTION 'Cannot remove users from read_by';
    END IF;

    -- Ensure only one user is being added
    IF array_length(NEW.read_by, 1) != array_length(OLD.read_by, 1) + 1 THEN
        RAISE EXCEPTION 'Can only add one user at a time to read_by';
    END IF;

    -- Ensure the current user is the one being added
    IF NOT (NEW.read_by @> ARRAY[auth.uid()]::uuid[]) THEN
        RAISE EXCEPTION 'Can only add yourself to read_by';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for message updates
CREATE TRIGGER validate_message_update
    BEFORE UPDATE ON messages
    FOR EACH ROW
    EXECUTE FUNCTION validate_message_update();

-- Trigger to update conversation timestamps
CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE conversations
        SET updated_at = now(),
            last_message_at = (
                SELECT created_at 
                FROM messages 
                WHERE conversation_id = OLD.conversation_id 
                ORDER BY created_at DESC 
                LIMIT 1
            )
        WHERE id = OLD.conversation_id;
        RETURN OLD;
    ELSE
        UPDATE conversations
        SET updated_at = now(),
            last_message_at = NEW.created_at
        WHERE id = NEW.conversation_id;
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS update_conversation_after_message ON messages;
CREATE TRIGGER update_conversation_after_message
    AFTER INSERT OR UPDATE OR DELETE ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_timestamp();

-- Enable realtime for tables
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
