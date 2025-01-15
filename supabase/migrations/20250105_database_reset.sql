-- Reset and recreate entire database schema
-- First, drop all existing objects in correct order
DROP TRIGGER IF EXISTS validate_message_update ON messages;
DROP FUNCTION IF EXISTS validate_message_update() CASCADE;
DROP FUNCTION IF EXISTS mark_message_read() CASCADE;
DROP FUNCTION IF EXISTS send_message() CASCADE;
DROP FUNCTION IF EXISTS get_or_create_conversation() CASCADE;
DROP FUNCTION IF EXISTS sort_uuid_array() CASCADE;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Drop all tables in correct order
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TABLE IF EXISTS solutions CASCADE;
DROP TABLE IF EXISTS obstacles CASCADE;
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS steps CASCADE;
DROP TABLE IF EXISTS actions CASCADE;
DROP TABLE IF EXISTS targets CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Create base tables

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    photo TEXT,
    age INTEGER,
    country TEXT,
    degree TEXT,
    profession TEXT,
    linkedin TEXT,
    languages TEXT[],
    industry TEXT,
    experience INTEGER,
    phone TEXT,
    website TEXT,
    twitter TEXT,
    github TEXT,
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Targets table
CREATE TABLE targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category_id TEXT NOT NULL,
    subcategory_id TEXT NOT NULL,
    progress INTEGER DEFAULT 0,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

-- Actions table
CREATE TABLE actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    target_id UUID NOT NULL REFERENCES targets(id) ON DELETE CASCADE
);

-- Steps table
CREATE TABLE steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    action_id UUID NOT NULL REFERENCES actions(id) ON DELETE CASCADE
);

-- Tasks table
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    deadline TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    step_id UUID NOT NULL REFERENCES steps(id) ON DELETE CASCADE
);

-- Obstacles table
CREATE TABLE obstacles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    description TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    progress INTEGER DEFAULT 0,
    resolved BOOLEAN DEFAULT FALSE,
    resolution TEXT,
    resolution_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    action_id UUID NOT NULL REFERENCES actions(id) ON DELETE CASCADE
);

-- Solutions table
CREATE TABLE solutions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    description TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    deadline TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    obstacle_id UUID NOT NULL REFERENCES obstacles(id) ON DELETE CASCADE
);

-- Chat system tables and functions

-- Helper function for array operations
CREATE OR REPLACE FUNCTION sort_uuid_array(arr UUID[])
RETURNS UUID[] AS $$
    SELECT array_agg(x ORDER BY x)
    FROM unnest(arr) x;
$$ LANGUAGE SQL IMMUTABLE;

-- Conversations table
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

-- Messages table
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    content TEXT NOT NULL CHECK (length(trim(content)) > 0),
    read_by UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create all necessary indexes
CREATE INDEX idx_targets_user_id ON targets(user_id);
CREATE INDEX idx_actions_target_id ON actions(target_id);
CREATE INDEX idx_steps_action_id ON steps(action_id);
CREATE INDEX idx_tasks_step_id ON tasks(step_id);
CREATE INDEX idx_obstacles_action_id ON obstacles(action_id);
CREATE INDEX idx_solutions_obstacle_id ON solutions(obstacle_id);

-- Chat system indexes
CREATE INDEX idx_conversations_target ON conversations(target_id);
CREATE INDEX idx_conversations_participants ON conversations USING GIN (participants);
CREATE INDEX idx_conversations_last_message ON conversations(last_message_at DESC);
CREATE UNIQUE INDEX idx_unique_conversation ON conversations (target_id, (sort_uuid_array(participants)));

CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_created ON messages(created_at DESC);
CREATE INDEX idx_messages_read_by ON messages USING GIN (read_by);

-- Chat system functions
CREATE OR REPLACE FUNCTION get_or_create_conversation(
    p_participants UUID[],
    p_target_id UUID
) RETURNS UUID AS $$
DECLARE
    v_sorted_participants UUID[];
    v_conversation_id UUID;
BEGIN
    v_sorted_participants := sort_uuid_array(p_participants);
    
    SELECT id INTO v_conversation_id
    FROM conversations
    WHERE target_id = p_target_id
    AND participants = v_sorted_participants;
    
    IF FOUND THEN
        RETURN v_conversation_id;
    END IF;
    
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

CREATE OR REPLACE FUNCTION send_message(
    p_conversation_id UUID,
    p_content TEXT
) RETURNS messages AS $$
DECLARE
    v_message messages;
BEGIN
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
    
    UPDATE conversations
    SET last_message_at = v_message.created_at,
        updated_at = v_message.created_at
    WHERE id = p_conversation_id;
    
    RETURN v_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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

-- Message update validation
CREATE OR REPLACE FUNCTION validate_message_update()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.id != OLD.id OR
        NEW.conversation_id != OLD.conversation_id OR
        NEW.sender_id != OLD.sender_id OR
        NEW.content != OLD.content OR
        NEW.created_at != OLD.created_at OR
        NEW.metadata != OLD.metadata) THEN
        RAISE EXCEPTION 'Can only update read_by field';
    END IF;

    IF NOT (NEW.read_by @> OLD.read_by) THEN
        RAISE EXCEPTION 'Cannot remove users from read_by';
    END IF;

    IF array_length(NEW.read_by, 1) != array_length(OLD.read_by, 1) + 1 THEN
        RAISE EXCEPTION 'Can only add one user at a time to read_by';
    END IF;

    IF NOT (NEW.read_by @> ARRAY[auth.uid()]::uuid[]) THEN
        RAISE EXCEPTION 'Can only add yourself to read_by';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create message update trigger
CREATE TRIGGER validate_message_update
    BEFORE UPDATE ON messages
    FOR EACH ROW
    EXECUTE FUNCTION validate_message_update();

-- New user handling
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.users (id, email, name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO UPDATE 
    SET 
        email = EXCLUDED.email,
        name = EXCLUDED.name;
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE LOG 'Error in handle_new_user trigger: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create new user trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;
ALTER TABLE solutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policies

-- Users policies
CREATE POLICY "Users can view their own profile"
    ON users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON users FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON users FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Conversation policies
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

-- Message policies
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
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = conversation_id
            AND auth.uid() = ANY(c.participants)
        )
    );

-- Grant necessary permissions
GRANT ALL ON users TO authenticated;
GRANT ALL ON users TO anon;
GRANT ALL ON users TO service_role;

GRANT ALL ON targets TO authenticated;
GRANT ALL ON targets TO anon;
GRANT ALL ON targets TO service_role;

GRANT ALL ON actions TO authenticated;
GRANT ALL ON actions TO anon;
GRANT ALL ON actions TO service_role;

GRANT ALL ON steps TO authenticated;
GRANT ALL ON steps TO anon;
GRANT ALL ON steps TO service_role;

GRANT ALL ON tasks TO authenticated;
GRANT ALL ON tasks TO anon;
GRANT ALL ON tasks TO service_role;

GRANT ALL ON obstacles TO authenticated;
GRANT ALL ON obstacles TO anon;
GRANT ALL ON obstacles TO service_role;

GRANT ALL ON solutions TO authenticated;
GRANT ALL ON solutions TO anon;
GRANT ALL ON solutions TO service_role;

GRANT ALL ON conversations TO authenticated;
GRANT ALL ON conversations TO anon;
GRANT ALL ON conversations TO service_role;

GRANT ALL ON messages TO authenticated;
GRANT ALL ON messages TO anon;
GRANT ALL ON messages TO service_role; 