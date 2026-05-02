CREATE TABLE IF NOT EXISTS preauth_events (
  id SERIAL PRIMARY KEY,
  member_no VARCHAR(50) NOT NULL,
  request_no VARCHAR(100) NOT NULL,
  status VARCHAR(50) NOT NULL,
  approved_amount NUMERIC(18,2),
  decided_at TIMESTAMPTZ,
  provider_name VARCHAR(255),
  condition VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_preauth_events_member_no ON preauth_events(member_no);
