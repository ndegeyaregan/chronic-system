-- Onafriq (MFS Africa) push-payment integration for card reprints: the
-- member enters their mobile money number and approves a USSD PIN prompt,
-- replacing the old manual USSD-dial + screenshot-proof flow.
-- payment_status (from migration 041) is reused to track the pay-in result.

ALTER TABLE card_reprint_requests
  ADD COLUMN IF NOT EXISTS onafriq_request_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_card_reprint_onafriq_request
  ON card_reprint_requests(onafriq_request_id)
  WHERE onafriq_request_id IS NOT NULL;
