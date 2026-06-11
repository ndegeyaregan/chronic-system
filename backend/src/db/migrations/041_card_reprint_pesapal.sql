-- Pesapal payment tracking columns for card reprint requests.
-- Order is created on Pesapal at the moment the member submits the form;
-- the reprint record stays "pending_payment" until the IPN callback or the
-- status polling endpoint confirms the payment was COMPLETED.

ALTER TABLE card_reprint_requests
  ADD COLUMN IF NOT EXISTS pesapal_tracking_id      TEXT,
  ADD COLUMN IF NOT EXISTS pesapal_merchant_ref     TEXT,
  ADD COLUMN IF NOT EXISTS pesapal_redirect_url     TEXT,
  ADD COLUMN IF NOT EXISTS payment_status           VARCHAR(30) NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS payment_method_used      TEXT,
  ADD COLUMN IF NOT EXISTS payment_confirmation_code TEXT,
  ADD COLUMN IF NOT EXISTS payment_completed_at     TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notifications_sent_at    TIMESTAMPTZ;
-- payment_status values: pending | completed | failed | reversed | invalid

CREATE UNIQUE INDEX IF NOT EXISTS idx_card_reprint_pesapal_tracking
  ON card_reprint_requests(pesapal_tracking_id)
  WHERE pesapal_tracking_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_card_reprint_pesapal_merchant_ref
  ON card_reprint_requests(pesapal_merchant_ref)
  WHERE pesapal_merchant_ref IS NOT NULL;
