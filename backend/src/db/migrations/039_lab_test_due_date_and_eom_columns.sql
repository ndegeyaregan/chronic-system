-- Add columns used by alertService.js cron jobs:
--   sendLabTestEndOfMonthEmail  -> last_end_of_month_email_at
--   sendLabTestDueDateSms       -> last_due_date_sms_at
ALTER TABLE lab_tests
  ADD COLUMN IF NOT EXISTS last_end_of_month_email_at TIMESTAMPTZ;

ALTER TABLE lab_tests
  ADD COLUMN IF NOT EXISTS last_due_date_sms_at TIMESTAMPTZ;
