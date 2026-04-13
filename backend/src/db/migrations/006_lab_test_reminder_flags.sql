-- Lab test reminder tracking columns
ALTER TABLE lab_tests ADD COLUMN IF NOT EXISTS reminder_24h_sent          BOOLEAN DEFAULT FALSE;
ALTER TABLE lab_tests ADD COLUMN IF NOT EXISTS reminder_day_morning_sent   BOOLEAN DEFAULT FALSE;
ALTER TABLE lab_tests ADD COLUMN IF NOT EXISTS reminder_day_noon_sent      BOOLEAN DEFAULT FALSE;
ALTER TABLE lab_tests ADD COLUMN IF NOT EXISTS reminder_day_afternoon_sent BOOLEAN DEFAULT FALSE;
