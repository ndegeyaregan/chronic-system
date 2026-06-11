-- ============================================================
-- 049_institution_price_lists.sql
-- Store uploaded institution price lists (Excel/Word/PDF) with audit fields
-- ============================================================

CREATE TABLE IF NOT EXISTS institution_price_lists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL,
  institution_type VARCHAR(20) NOT NULL CHECK (institution_type IN ('hospital', 'pharmacy')),
  file_name VARCHAR(255) NOT NULL,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type VARCHAR(150) NOT NULL,
  notes TEXT,
  uploaded_by UUID REFERENCES admins(id),
  updated_by UUID REFERENCES admins(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_institution_price_lists_institution
  ON institution_price_lists (institution_id, institution_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_institution_price_lists_uploaded_by
  ON institution_price_lists (uploaded_by, created_at DESC);
