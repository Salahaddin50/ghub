-- Drop existing triggers and functions first
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- Drop existing tables in correct order
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TABLE IF EXISTS notes CASCADE;
DROP TABLE IF EXISTS solutions CASCADE;
DROP TABLE IF EXISTS obstacles CASCADE;
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS steps CASCADE;
DROP TABLE IF EXISTS actions CASCADE;
DROP TABLE IF EXISTS targets CASCADE;
DROP TABLE IF EXISTS favorites CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Create fresh tables with proper relationships

-- Users table (core table)
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
    progress INTEGER DEFAULT 0,
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
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    action_id UUID NOT NULL REFERENCES actions(id) ON DELETE CASCADE
);

-- Solutions table
CREATE TABLE solutions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    deadline TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    obstacle_id UUID NOT NULL REFERENCES obstacles(id) ON DELETE CASCADE
);

-- Notes table
CREATE TABLE notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    entity_id UUID NOT NULL,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('step', 'obstacle', 'action')),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Favorites table
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_id UUID NOT NULL REFERENCES targets(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, target_id)
);

-- Chat system tables
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    target_id UUID NOT NULL REFERENCES targets(id) ON DELETE CASCADE,
    participants UUID[] NOT NULL,
    created_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_message_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    CONSTRAINT participants_not_empty CHECK (array_length(participants, 1) >= 2)
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
CREATE INDEX idx_targets_user_id ON targets(user_id);
CREATE INDEX idx_actions_target_id ON actions(target_id);
CREATE INDEX idx_steps_action_id ON steps(action_id);
CREATE INDEX idx_tasks_step_id ON tasks(step_id);
CREATE INDEX idx_obstacles_action_id ON obstacles(action_id);
CREATE INDEX idx_solutions_obstacle_id ON solutions(obstacle_id);
CREATE INDEX idx_favorites_user_target ON favorites(user_id, target_id);
CREATE INDEX notes_entity_id_idx ON notes(entity_id);
CREATE INDEX notes_entity_type_idx ON notes(entity_type);
CREATE INDEX notes_user_id_idx ON notes(user_id);
CREATE INDEX notes_created_at_idx ON notes(created_at DESC);

-- Chat system indexes
CREATE INDEX idx_conversations_target ON conversations(target_id);
CREATE INDEX idx_conversations_participants ON conversations USING GIN (participants);
CREATE INDEX idx_conversations_last_message ON conversations(last_message_at DESC);
CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_created ON messages(created_at DESC);
CREATE INDEX idx_messages_read_by ON messages USING GIN (read_by);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE targets ENABLE ROW LEVEL SECURITY;
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE obstacles ENABLE ROW LEVEL SECURITY;
ALTER TABLE solutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies

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

-- Targets policies
CREATE POLICY "Users can view their own targets"
    ON targets FOR SELECT
    USING (auth.uid() = user_id OR is_public = true);

CREATE POLICY "Users can create their own targets"
    ON targets FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own targets"
    ON targets FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own targets"
    ON targets FOR DELETE
    USING (auth.uid() = user_id);

-- Actions policies
CREATE POLICY "Users can view actions of their targets"
    ON actions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM targets
        WHERE targets.id = actions.target_id
        AND (targets.user_id = auth.uid() OR targets.is_public = true)
    ));

CREATE POLICY "Users can manage actions of their targets"
    ON actions FOR ALL
    USING (EXISTS (
        SELECT 1 FROM targets
        WHERE targets.id = actions.target_id
        AND targets.user_id = auth.uid()
    ));

-- Steps policies
CREATE POLICY "Users can view steps"
    ON steps FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM actions
        JOIN targets ON targets.id = actions.target_id
        WHERE actions.id = steps.action_id
        AND (targets.user_id = auth.uid() OR targets.is_public = true)
    ));

CREATE POLICY "Users can manage steps"
    ON steps FOR ALL
    USING (EXISTS (
        SELECT 1 FROM actions
        JOIN targets ON targets.id = actions.target_id
        WHERE actions.id = steps.action_id
        AND targets.user_id = auth.uid()
    ));

-- Tasks policies
CREATE POLICY "Users can view tasks"
    ON tasks FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM steps
        JOIN actions ON actions.id = steps.action_id
        JOIN targets ON targets.id = actions.target_id
        WHERE steps.id = tasks.step_id
        AND (targets.user_id = auth.uid() OR targets.is_public = true)
    ));

CREATE POLICY "Users can manage tasks"
    ON tasks FOR ALL
    USING (EXISTS (
        SELECT 1 FROM steps
        JOIN actions ON actions.id = steps.action_id
        JOIN targets ON targets.id = actions.target_id
        WHERE steps.id = tasks.step_id
        AND targets.user_id = auth.uid()
    ));

-- Obstacles policies
CREATE POLICY "Users can view obstacles"
    ON obstacles FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM actions
        JOIN targets ON targets.id = actions.target_id
        WHERE actions.id = obstacles.action_id
        AND (targets.user_id = auth.uid() OR targets.is_public = true)
    ));

CREATE POLICY "Users can manage obstacles"
    ON obstacles FOR ALL
    USING (EXISTS (
        SELECT 1 FROM actions
        JOIN targets ON targets.id = actions.target_id
        WHERE actions.id = obstacles.action_id
        AND targets.user_id = auth.uid()
    ));

-- Solutions policies
CREATE POLICY "Users can view solutions"
    ON solutions FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM obstacles
        JOIN actions ON actions.id = obstacles.action_id
        JOIN targets ON targets.id = actions.target_id
        WHERE obstacles.id = solutions.obstacle_id
        AND (targets.user_id = auth.uid() OR targets.is_public = true)
    ));

CREATE POLICY "Users can manage solutions"
    ON solutions FOR ALL
    USING (EXISTS (
        SELECT 1 FROM obstacles
        JOIN actions ON actions.id = obstacles.action_id
        JOIN targets ON targets.id = actions.target_id
        WHERE obstacles.id = solutions.obstacle_id
        AND targets.user_id = auth.uid()
    ));

-- Notes policies
CREATE POLICY "Users can read notes for their targets" ON notes
    FOR SELECT
    USING (
        user_id IN (
            SELECT user_id FROM targets
            WHERE id IN (
                SELECT target_id FROM actions WHERE id = entity_id
                UNION
                SELECT target_id FROM actions WHERE id IN (
                    SELECT action_id FROM steps WHERE id = entity_id
                    UNION
                    SELECT action_id FROM obstacles WHERE id = entity_id
                )
            )
        )
    );

CREATE POLICY "Users can create notes for their targets" ON notes
    FOR INSERT
    WITH CHECK (
        user_id IN (
            SELECT user_id FROM targets
            WHERE id IN (
                SELECT target_id FROM actions WHERE id = entity_id
                UNION
                SELECT target_id FROM actions WHERE id IN (
                    SELECT action_id FROM steps WHERE id = entity_id
                    UNION
                    SELECT action_id FROM obstacles WHERE id = entity_id
                )
            )
        )
    );

CREATE POLICY "Users can update their own notes" ON notes
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notes" ON notes
    FOR DELETE
    USING (auth.uid() = user_id);

-- Create trigger for notes updated_at
CREATE OR REPLACE FUNCTION update_notes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_notes_updated_at
    BEFORE UPDATE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION update_notes_updated_at();

-- Favorites policies
CREATE POLICY "Users can view their own favorites"
    ON favorites FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own favorites"
    ON favorites FOR ALL
    USING (auth.uid() = user_id);

-- Conversation policies
CREATE POLICY "Users can view conversations they're part of"
    ON conversations FOR SELECT
    USING (auth.uid() = ANY(participants));

CREATE POLICY "Users can create conversations they're part of"
    ON conversations FOR INSERT
    WITH CHECK (
        auth.uid() = ANY(participants)
        AND auth.uid() = created_by
        AND array_length(participants, 1) >= 2
    );

CREATE POLICY "Users can update conversations they're part of"
    ON conversations FOR UPDATE
    USING (auth.uid() = ANY(participants));

-- Message policies
CREATE POLICY "Users can view messages in their conversations"
    ON messages FOR SELECT
    USING (EXISTS (
        SELECT 1 FROM conversations
        WHERE conversations.id = messages.conversation_id
        AND auth.uid() = ANY(conversations.participants)
    ));

CREATE POLICY "Users can send messages to their conversations"
    ON messages FOR INSERT
    WITH CHECK (
        sender_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM conversations
            WHERE conversations.id = conversation_id
            AND auth.uid() = ANY(conversations.participants)
        )
    );

CREATE POLICY "Users can update message read status"
    ON messages FOR UPDATE
    USING (EXISTS (
        SELECT 1 FROM conversations
        WHERE conversations.id = conversation_id
        AND auth.uid() = ANY(conversations.participants)
    ));

-- Grant necessary permissions
GRANT ALL ON users TO authenticated;
GRANT ALL ON targets TO authenticated;
GRANT ALL ON actions TO authenticated;
GRANT ALL ON steps TO authenticated;
GRANT ALL ON tasks TO authenticated;
GRANT ALL ON obstacles TO authenticated;
GRANT ALL ON solutions TO authenticated;
GRANT ALL ON favorites TO authenticated;
GRANT ALL ON conversations TO authenticated;
GRANT ALL ON messages TO authenticated;
GRANT ALL ON notes TO authenticated;

-- Create trigger for new user handling
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

-- Create trigger for new user registration
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user(); 