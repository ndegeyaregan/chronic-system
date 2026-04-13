ALTER TABLE medications
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

UPDATE medications
SET updated_at = COALESCE(updated_at, created_at, NOW())
WHERE updated_at IS NULL;
