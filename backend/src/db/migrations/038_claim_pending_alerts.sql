-- 038: Track which pending claims have already triggered the 24h alert
-- so the cron job can re-run safely without re-notifying members.
CREATE TABLE IF NOT EXISTS claim_pending_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  visit_id VARCHAR(100) NOT NULL,
  claim_no VARCHAR(100),
  claim_type VARCHAR(100),
  alerted_channels TEXT[] NOT NULL,
  alerted_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (member_id, visit_id)
);

CREATE INDEX IF NOT EXISTS idx_claim_pending_alerts_member
  ON claim_pending_alerts(member_id);
