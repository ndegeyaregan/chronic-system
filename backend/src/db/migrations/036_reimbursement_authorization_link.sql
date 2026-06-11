-- Reimbursement gate: every new claim must be backed by a Sancare
-- authorization. Two paths are accepted:
--   1. in_app  -> linked to an approved authorization_requests row
--   2. email   -> the member uploaded the Sancare approval email/letter
--                 plus a short reference (officer name / email subject)
--
-- Existing rows pre-dating this gate keep approval_path = NULL.

ALTER TABLE reimbursement_claims
  ADD COLUMN IF NOT EXISTS approval_path        VARCHAR(20),
  ADD COLUMN IF NOT EXISTS authorization_id     UUID REFERENCES authorization_requests(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approval_email_url      TEXT,
  ADD COLUMN IF NOT EXISTS approval_email_filename VARCHAR(255),
  ADD COLUMN IF NOT EXISTS approval_reference   VARCHAR(200);

CREATE INDEX IF NOT EXISTS idx_reimbursement_authorization
  ON reimbursement_claims(authorization_id);
