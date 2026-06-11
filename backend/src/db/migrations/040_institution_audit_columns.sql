-- Track which admin added / suspended / reinstated each institution.
ALTER TABLE hospitals
  ADD COLUMN IF NOT EXISTS added_by         UUID REFERENCES admins(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS suspended_by     UUID REFERENCES admins(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS unsuspended_by   UUID REFERENCES admins(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS unsuspended_at   TIMESTAMPTZ;

ALTER TABLE pharmacies
  ADD COLUMN IF NOT EXISTS added_by         UUID REFERENCES admins(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS suspended_by     UUID REFERENCES admins(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS unsuspended_by   UUID REFERENCES admins(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS unsuspended_at   TIMESTAMPTZ;
