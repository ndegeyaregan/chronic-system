-- Separate tracking column for evening push so both morning and evening fire daily
ALTER TABLE lab_tests ADD COLUMN IF NOT EXISTS last_push_evening_at TIMESTAMPTZ;
