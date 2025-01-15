-- Add subject column to conversations table
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS subject TEXT;

-- Update existing conversations to use target title as subject
UPDATE conversations c
SET subject = t.title
FROM targets t
WHERE c.target_id = t.id; 