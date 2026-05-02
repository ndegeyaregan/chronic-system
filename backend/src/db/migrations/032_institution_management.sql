-- ============================================================
-- 032_institution_management.sql
-- Add fields for institution suspension, soft delete, and manual management
-- ============================================================

-- Add columns to hospitals table
ALTER TABLE hospitals
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_user_added BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS suspended_reason TEXT,
  ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

-- Add columns to pharmacies table
ALTER TABLE pharmacies
  ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_user_added BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS suspended_reason TEXT,
  ADD COLUMN IF NOT EXISTS suspended_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP;

-- Create indexes for filtered queries
CREATE INDEX IF NOT EXISTS idx_hospitals_suspended ON hospitals(is_suspended);
CREATE INDEX IF NOT EXISTS idx_hospitals_deleted ON hospitals(is_deleted);
CREATE INDEX IF NOT EXISTS idx_hospitals_user_added ON hospitals(is_user_added);
CREATE INDEX IF NOT EXISTS idx_pharmacies_suspended ON pharmacies(is_suspended);
CREATE INDEX IF NOT EXISTS idx_pharmacies_deleted ON pharmacies(is_deleted);
CREATE INDEX IF NOT EXISTS idx_pharmacies_user_added ON pharmacies(is_user_added);

-- Index for efficient queries filtering out deleted institutions
CREATE INDEX IF NOT EXISTS idx_hospitals_active ON hospitals(is_active, is_deleted)
  WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_pharmacies_active ON pharmacies(is_active, is_deleted)
  WHERE is_deleted = FALSE;
