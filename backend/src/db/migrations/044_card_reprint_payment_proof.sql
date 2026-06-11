-- Allow members to attach proof of mobile money payment when submitting a
-- card reprint request: a screenshot file and/or the transaction id /
-- confirmation code typed in by the member.

ALTER TABLE card_reprint_requests
  ADD COLUMN IF NOT EXISTS payment_proof_url  TEXT,
  ADD COLUMN IF NOT EXISTS payment_proof_name TEXT;
