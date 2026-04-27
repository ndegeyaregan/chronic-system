-- Replace boolean flags with timestamps for recurring lab test reminders
ALTER TABLE lab_tests ADD COLUMN IF NOT EXISTS last_push_reminder_at  TIMESTAMPTZ;
ALTER TABLE lab_tests ADD COLUMN IF NOT EXISTS last_email_reminder_at TIMESTAMPTZ;
ALTER TABLE lab_tests ADD COLUMN IF NOT EXISTS last_sms_reminder_at   TIMESTAMPTZ;
