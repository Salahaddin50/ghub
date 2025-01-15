-- Add is_favorite column to favorites table
ALTER TABLE favorites ADD COLUMN is_favorite BOOLEAN DEFAULT true NOT NULL;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_favorites_is_favorite ON favorites(is_favorite);

-- Update existing rows to have is_favorite = true
UPDATE favorites SET is_favorite = true WHERE is_favorite IS NULL; 