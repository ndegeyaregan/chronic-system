ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS created_by_admin BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS no_show_reason TEXT;

UPDATE appointments
SET created_by_admin = COALESCE(created_by_admin, FALSE)
WHERE created_by_admin IS NULL;
