-- Extend the claims table with the rest of the columns we know exist
-- in the Sanlam claims export. The full original row is still kept in
-- `raw` JSONB for any ad-hoc field we haven't promoted.

ALTER TABLE claims
  ADD COLUMN IF NOT EXISTS claim_no       TEXT,
  ADD COLUMN IF NOT EXISTS invoice_no     TEXT,
  ADD COLUMN IF NOT EXISTS claim_type     TEXT,   -- OutPatient / InPatient / etc
  ADD COLUMN IF NOT EXISTS illness_type   TEXT,   -- New / Chronic / etc
  ADD COLUMN IF NOT EXISTS pay_to         TEXT,
  ADD COLUMN IF NOT EXISTS corp_id        TEXT,
  ADD COLUMN IF NOT EXISTS relation       TEXT,
  ADD COLUMN IF NOT EXISTS benefit_plan   TEXT,
  ADD COLUMN IF NOT EXISTS active         TEXT,
  ADD COLUMN IF NOT EXISTS visit_reason   TEXT,
  ADD COLUMN IF NOT EXISTS diagnosis_code TEXT,
  ADD COLUMN IF NOT EXISTS base_price     NUMERIC(18,2),
  ADD COLUMN IF NOT EXISTS overcharges    NUMERIC(18,2),
  ADD COLUMN IF NOT EXISTS payable_amount NUMERIC(18,2),
  ADD COLUMN IF NOT EXISTS copay          NUMERIC(18,2),
  ADD COLUMN IF NOT EXISTS claim_status   TEXT,   -- Approved / Rejected / Pending
  ADD COLUMN IF NOT EXISTS create_at      TIMESTAMP,   -- merged Create_Date + Create_Time
  ADD COLUMN IF NOT EXISTS checkout_at    TIMESTAMP,
  ADD COLUMN IF NOT EXISTS update_at      TIMESTAMP,
  ADD COLUMN IF NOT EXISTS payment_date   DATE,
  ADD COLUMN IF NOT EXISTS created_by     TEXT,
  ADD COLUMN IF NOT EXISTS processed_by   TEXT,
  ADD COLUMN IF NOT EXISTS paid_by        TEXT,
  ADD COLUMN IF NOT EXISTS cancel_reason  TEXT,
  ADD COLUMN IF NOT EXISTS agent_note     TEXT,
  ADD COLUMN IF NOT EXISTS provider_note  TEXT;

CREATE INDEX IF NOT EXISTS idx_claims_claim_no     ON claims(claim_no);
CREATE INDEX IF NOT EXISTS idx_claims_claim_type   ON claims(claim_type);
CREATE INDEX IF NOT EXISTS idx_claims_claim_status ON claims(claim_status);
CREATE INDEX IF NOT EXISTS idx_claims_create_at    ON claims(create_at);
CREATE INDEX IF NOT EXISTS idx_claims_member_no    ON claims(member_no);
