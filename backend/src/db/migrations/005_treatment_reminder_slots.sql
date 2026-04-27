-- Rename single day reminder flag into three time-slot flags (idempotent)
DO $$
BEGIN
  -- If old column exists but new one doesn't: rename
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'treatment_plans' AND column_name = 'reminder_day_sent'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'treatment_plans' AND column_name = 'reminder_day_morning_sent'
  ) THEN
    ALTER TABLE treatment_plans RENAME COLUMN reminder_day_sent TO reminder_day_morning_sent;
  -- If both exist (partial prior run): drop the old one
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'treatment_plans' AND column_name = 'reminder_day_sent'
  ) THEN
    ALTER TABLE treatment_plans DROP COLUMN reminder_day_sent;
  END IF;
END
$$;

ALTER TABLE treatment_plans
  ADD COLUMN IF NOT EXISTS reminder_day_morning_sent   BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reminder_day_noon_sent      BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS reminder_day_afternoon_sent BOOLEAN DEFAULT FALSE;
