-- Add media columns to treatment_plans (photo, audio, video) for existing databases
ALTER TABLE treatment_plans
  ADD COLUMN IF NOT EXISTS photo_url TEXT,
  ADD COLUMN IF NOT EXISTS audio_url TEXT,
  ADD COLUMN IF NOT EXISTS video_url TEXT;
