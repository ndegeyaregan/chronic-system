-- Card reprint requests: members request a replacement card for the principal
-- or any of their dependants. Fee: UGX 20,000 paid via mobile money.
CREATE TABLE IF NOT EXISTS card_reprint_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  -- The card is for one of: the principal themselves, or a named dependant
  target_member_no VARCHAR(50) NOT NULL,
  target_member_name VARCHAR(200) NOT NULL,
  target_relation VARCHAR(50) NOT NULL,           -- 'Principal' | 'Spouse' | 'Child' | ...
  is_for_dependant BOOLEAN NOT NULL DEFAULT FALSE,
  reason VARCHAR(50) NOT NULL,                    -- 'lost' | 'damaged' | 'stolen' | 'other'
  reason_notes TEXT,
  payment_method VARCHAR(30) NOT NULL DEFAULT 'mobile_money',
  payment_phone VARCHAR(30) NOT NULL,
  amount NUMERIC(10,2) NOT NULL DEFAULT 20000,
  currency VARCHAR(10) NOT NULL DEFAULT 'UGX',
  status VARCHAR(30) NOT NULL DEFAULT 'pending_payment',
  -- pending_payment | paid | processing | fulfilled | cancelled
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  paid_at TIMESTAMPTZ,
  fulfilled_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_card_reprint_member ON card_reprint_requests(member_id);
CREATE INDEX IF NOT EXISTS idx_card_reprint_status ON card_reprint_requests(status);
CREATE INDEX IF NOT EXISTS idx_card_reprint_created ON card_reprint_requests(created_at DESC);
