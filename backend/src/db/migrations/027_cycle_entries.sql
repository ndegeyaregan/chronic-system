-- Menstrual cycle / period tracking entries
-- Stored per-member; sensitive personal health data — only the owning member
-- (and admins) may read or write rows.
CREATE TABLE IF NOT EXISTS cycle_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  client_id TEXT,                                 -- client-side id for de-duplication
  start_date DATE NOT NULL,
  end_date DATE,
  flow TEXT DEFAULT 'medium',                     -- spotting | light | medium | heavy
  symptoms JSONB DEFAULT '[]'::jsonb,
  mood TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, client_id)
);

CREATE INDEX IF NOT EXISTS idx_cycle_entries_member_start
  ON cycle_entries(member_id, start_date DESC);
