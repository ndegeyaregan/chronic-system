-- Add profile picture URL to members.
ALTER TABLE members
  ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;
