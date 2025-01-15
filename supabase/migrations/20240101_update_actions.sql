-- Add missing columns to actions table
ALTER TABLE actions 
ADD COLUMN IF NOT EXISTS urgency text CHECK (urgency IN ('high', 'medium', 'low')) DEFAULT 'medium',
ADD COLUMN IF NOT EXISTS impact text CHECK (impact IN ('high', 'medium', 'low')) DEFAULT 'medium',
ADD COLUMN IF NOT EXISTS steps jsonb[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS obstacles jsonb[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS progress integer DEFAULT 0;
