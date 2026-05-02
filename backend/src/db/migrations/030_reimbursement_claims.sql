-- Reimbursement claims: members request reimbursement for care received at
-- non-network hospitals. Invoice attachment is mandatory; medical report
-- is optional. Status flow: pending -> paid (admin sets paid).
CREATE TABLE IF NOT EXISTS reimbursement_claims (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  hospital_name VARCHAR(200) NOT NULL,
  reason TEXT NOT NULL,
  amount NUMERIC(12,2),
  currency VARCHAR(10) NOT NULL DEFAULT 'UGX',
  invoice_url TEXT NOT NULL,
  invoice_filename VARCHAR(255),
  report_url TEXT,
  report_filename VARCHAR(255),
  -- Payout details: how Sanlam should pay the member back
  payout_method VARCHAR(20) NOT NULL DEFAULT 'mobile_money',
  -- 'mobile_money' | 'bank'
  payout_account_name VARCHAR(150),    -- name on the account / mobile money line
  payout_phone VARCHAR(30),            -- when payout_method = 'mobile_money'
  payout_bank_name VARCHAR(100),       -- when payout_method = 'bank'
  payout_account_number VARCHAR(50),   -- when payout_method = 'bank'
  payout_branch VARCHAR(100),
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
  -- pending | under_review | paid | rejected
  admin_notes TEXT,
  paid_at TIMESTAMPTZ,
  paid_by UUID REFERENCES admins(id),
  paid_amount NUMERIC(12,2),
  payment_reference VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reimbursement_member ON reimbursement_claims(member_id);
CREATE INDEX IF NOT EXISTS idx_reimbursement_status ON reimbursement_claims(status);
CREATE INDEX IF NOT EXISTS idx_reimbursement_created ON reimbursement_claims(created_at DESC);
