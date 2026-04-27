-- Add mood column to vitals table (was only in daily_checkins)
ALTER TABLE vitals
  ADD COLUMN IF NOT EXISTS mood VARCHAR(50);
