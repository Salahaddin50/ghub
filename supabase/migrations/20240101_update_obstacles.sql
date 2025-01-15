-- Add missing columns to obstacles table
ALTER TABLE obstacles 
ADD COLUMN IF NOT EXISTS title text NOT NULL,
ADD COLUMN IF NOT EXISTS description text,
ADD COLUMN IF NOT EXISTS priority text CHECK (priority IN ('high', 'medium', 'low')) DEFAULT 'medium',
ADD COLUMN IF NOT EXISTS completed boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS action_id UUID REFERENCES actions(id) ON DELETE CASCADE;
