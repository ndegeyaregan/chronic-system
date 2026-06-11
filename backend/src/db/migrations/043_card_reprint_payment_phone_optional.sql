-- Allow NULL payment_phone now that USSD Mobile Money is the only option;
-- members enter their Member Number as the reference rather than a phone number.
ALTER TABLE card_reprint_requests ALTER COLUMN payment_phone DROP NOT NULL;
