-- Adds foot sensitivity and eyesight self-rating columns to vitals.
-- Members with diabetes monitor neuropathy via foot sensitivity, and
-- eyesight self-checks help flag retinopathy or BP-related changes.
ALTER TABLE vitals
  ADD COLUMN IF NOT EXISTS foot_sensitivity TEXT,
  ADD COLUMN IF NOT EXISTS eyesight TEXT;
