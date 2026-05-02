-- ============================================================
-- 031_sanlam_institutions.sql
-- Adds Sanlam-source identifiers + category to hospitals/pharmacies
-- so we can upsert from the Sanlam Member API `searchInstitution`
-- endpoint and filter facilities by clinical category.
-- ============================================================

ALTER TABLE hospitals
  ADD COLUMN IF NOT EXISTS sanlam_id VARCHAR(50),
  ADD COLUMN IF NOT EXISTS category   VARCHAR(20),
  ADD COLUMN IF NOT EXISTS short_id   VARCHAR(50),
  ADD COLUMN IF NOT EXISTS first_name VARCHAR(150),
  ADD COLUMN IF NOT EXISTS last_name  VARCHAR(150),
  ADD COLUMN IF NOT EXISTS title      VARCHAR(50),
  ADD COLUMN IF NOT EXISTS street     TEXT,
  ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20),
  ADD COLUMN IF NOT EXISTS m_field    VARCHAR(120);

ALTER TABLE pharmacies
  ADD COLUMN IF NOT EXISTS sanlam_id  VARCHAR(50),
  ADD COLUMN IF NOT EXISTS category   VARCHAR(20) DEFAULT 'pharmacy',
  ADD COLUMN IF NOT EXISTS short_id   VARCHAR(50),
  ADD COLUMN IF NOT EXISTS first_name VARCHAR(150),
  ADD COLUMN IF NOT EXISTS last_name  VARCHAR(150),
  ADD COLUMN IF NOT EXISTS title      VARCHAR(50),
  ADD COLUMN IF NOT EXISTS street     TEXT,
  ADD COLUMN IF NOT EXISTS postal_code VARCHAR(20),
  ADD COLUMN IF NOT EXISTS m_field    VARCHAR(120);

CREATE UNIQUE INDEX IF NOT EXISTS ux_hospitals_sanlam_id
  ON hospitals(sanlam_id) WHERE sanlam_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_pharmacies_sanlam_id
  ON pharmacies(sanlam_id) WHERE sanlam_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hospitals_category  ON hospitals(category);
CREATE INDEX IF NOT EXISTS idx_pharmacies_category ON pharmacies(category);
