-- ============================================================
-- 053_institution_area_copays.sql
-- Add area/suburb to hospitals & pharmacies for location search.
-- Add working_hours, latitude, longitude to pharmacies.
-- Add institution_copays cache table synced from Sanlam GetInstCoPay.
-- ============================================================

-- Area/suburb for location-based filtering (e.g. "Wandegeya", "Nakasero")
ALTER TABLE hospitals
  ADD COLUMN IF NOT EXISTS area VARCHAR(150);

ALTER TABLE pharmacies
  ADD COLUMN IF NOT EXISTS area           VARCHAR(150),
  ADD COLUMN IF NOT EXISTS working_hours  TEXT,
  ADD COLUMN IF NOT EXISTS latitude       DECIMAL(10,7),
  ADD COLUMN IF NOT EXISTS longitude      DECIMAL(10,7);

CREATE INDEX IF NOT EXISTS idx_hospitals_area  ON hospitals (area);
CREATE INDEX IF NOT EXISTS idx_pharmacies_area ON pharmacies (area);

-- ============================================================
-- Cache of institution-level co-pays, sourced from Sanlam GetInstCoPay.
-- Keyed by sanlam_id; refreshed via admin-triggered sync.
-- ============================================================
CREATE TABLE IF NOT EXISTS institution_copays (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sanlam_id           VARCHAR(50) NOT NULL UNIQUE,
  institution_name    VARCHAR(200),
  short_id            VARCHAR(50),
  benefit_schemes     TEXT,
  copay_for           TEXT,
  excluded_schemes    TEXT,

  -- Flat amounts (UGX)
  out_patient         NUMERIC(14,2),
  out_patient_max     NUMERIC(14,2),
  in_patient          NUMERIC(14,2),
  in_patient_max      NUMERIC(14,2),
  dental              NUMERIC(14,2),
  optical             NUMERIC(14,2),
  pharma              NUMERIC(14,2),

  -- Percentages (0–100)
  out_patient_percent NUMERIC(6,2),
  in_patient_percent  NUMERIC(6,2),
  dental_percent      NUMERIC(6,2),
  optical_percent     NUMERIC(6,2),
  pharma_percent      NUMERIC(6,2),

  -- Full raw payload for reference
  raw_data            JSONB,

  synced_by           UUID REFERENCES admins(id) ON DELETE SET NULL,
  synced_at           TIMESTAMPTZ DEFAULT NOW(),
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_institution_copays_sanlam_id
  ON institution_copays (sanlam_id);
