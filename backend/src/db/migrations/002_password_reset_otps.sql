CREATE TABLE IF NOT EXISTS password_reset_otps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE,
  admin_id UUID REFERENCES admins(id) ON DELETE CASCADE,
  otp VARCHAR(6) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  is_used BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT at_least_one_user CHECK (
    (member_id IS NOT NULL AND admin_id IS NULL) OR 
    (member_id IS NULL AND admin_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_otp_member ON password_reset_otps(member_id);
CREATE INDEX IF NOT EXISTS idx_otp_admin ON password_reset_otps(admin_id);
