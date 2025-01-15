-- Update existing tasks to ensure title is set if it was empty
UPDATE tasks 
SET title = COALESCE(title, description) 
WHERE title IS NULL OR title = '';

-- Make title column NOT NULL if it isn't already
ALTER TABLE tasks 
ALTER COLUMN title SET NOT NULL;

-- Drop the description column
ALTER TABLE tasks
DROP COLUMN IF EXISTS description; 