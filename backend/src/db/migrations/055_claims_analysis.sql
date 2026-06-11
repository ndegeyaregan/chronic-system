-- Claims analysis: store uploaded claims files and their parsed rows
-- so we can run provider / scheme / diagnosis / time analytics over them.

CREATE TABLE IF NOT EXISTS claim_uploads (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  filename      TEXT NOT NULL,
  size_bytes    BIGINT NOT NULL DEFAULT 0,
  row_count     INTEGER NOT NULL DEFAULT 0,
  total_amount  NUMERIC(18,2) NOT NULL DEFAULT 0,
  status        TEXT NOT NULL DEFAULT 'processing', -- processing | ready | failed
  error         TEXT,
  columns       JSONB,                 -- detected header columns
  uploaded_by   UUID,                  -- admin user id (no FK, admins table varies)
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS claims (
  id            BIGSERIAL PRIMARY KEY,
  upload_id     UUID NOT NULL REFERENCES claim_uploads(id) ON DELETE CASCADE,
  claim_date    DATE,
  provider      TEXT,
  provider_type TEXT,
  scheme        TEXT,           -- from "Corporate" column
  member_name   TEXT,
  member_no     TEXT,
  diagnosis     TEXT,
  amount        NUMERIC(18,2) NOT NULL DEFAULT 0,
  raw           JSONB           -- full row, lowercased keys, for ad-hoc analysis
);

CREATE INDEX IF NOT EXISTS idx_claims_upload_id     ON claims(upload_id);
CREATE INDEX IF NOT EXISTS idx_claims_claim_date    ON claims(claim_date);
CREATE INDEX IF NOT EXISTS idx_claims_provider      ON claims(provider);
CREATE INDEX IF NOT EXISTS idx_claims_provider_type ON claims(provider_type);
CREATE INDEX IF NOT EXISTS idx_claims_scheme        ON claims(scheme);
CREATE INDEX IF NOT EXISTS idx_claims_diagnosis     ON claims(diagnosis);
