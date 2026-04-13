ALTER TABLE pharmacies
  ADD COLUMN IF NOT EXISTS contact_person VARCHAR(150),
  ADD COLUMN IF NOT EXISTS working_hours TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

UPDATE pharmacies
SET updated_at = COALESCE(updated_at, created_at, NOW())
WHERE updated_at IS NULL;
