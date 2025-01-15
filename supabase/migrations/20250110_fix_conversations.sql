-- Drop existing constraints if they exist
ALTER TABLE conversations 
  DROP CONSTRAINT IF EXISTS conversations_subject_not_empty,
  DROP CONSTRAINT IF EXISTS conversations_target_unique;

-- Delete conversations without a target or subject
DELETE FROM conversations
WHERE target_id IS NULL OR subject IS NULL;

-- For targets with multiple conversations, keep only the one with the most messages
WITH ranked_conversations AS (
  SELECT c.id,
         ROW_NUMBER() OVER (PARTITION BY c.target_id ORDER BY COUNT(m.id) DESC) as rn
  FROM conversations c
  LEFT JOIN messages m ON m.conversation_id = c.id
  GROUP BY c.id
)
DELETE FROM conversations c
WHERE c.id IN (
  SELECT id FROM ranked_conversations WHERE rn > 1
);

-- Add NOT NULL constraints
ALTER TABLE conversations 
  ALTER COLUMN target_id SET NOT NULL,
  ALTER COLUMN subject SET NOT NULL;

-- Add check constraint to ensure subject is not empty
ALTER TABLE conversations 
  ADD CONSTRAINT conversations_subject_not_empty 
  CHECK (length(trim(subject)) > 0);

-- Add unique constraint to ensure only one conversation per target
ALTER TABLE conversations
  ADD CONSTRAINT conversations_target_unique 
  UNIQUE (target_id); 