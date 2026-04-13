-- Add reminder tracking columns to treatment_plans
ALTER TABLE treatment_plans
  ADD COLUMN IF NOT EXISTS reminder_24h_sent  BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reminder_day_sent  BOOLEAN DEFAULT FALSE;
