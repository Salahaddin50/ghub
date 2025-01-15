-- Add subject to conversations table
ALTER TABLE conversations ADD COLUMN subject TEXT;
ALTER TABLE conversations ADD COLUMN target_id UUID REFERENCES targets(id) ON DELETE SET NULL;
