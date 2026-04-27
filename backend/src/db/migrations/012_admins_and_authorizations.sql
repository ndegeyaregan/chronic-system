ALTER TABLE admins
  ADD COLUMN IF NOT EXISTS first_name VARCHAR(100),
  ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);

UPDATE admins
SET
  first_name = COALESCE(
    NULLIF(first_name, ''),
    NULLIF(split_part(COALESCE(name, ''), ' ', 1), ''),
    name
  ),
  last_name = COALESCE(
    last_name,
    NULLIF(
      btrim(regexp_replace(COALESCE(name, ''), '^\S+\s*', '')),
      ''
    )
  )
WHERE first_name IS NULL OR last_name IS NULL;

CREATE TABLE IF NOT EXISTS authorization_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  request_type VARCHAR(100) NOT NULL,
  provider_type VARCHAR(50) NOT NULL,
  provider_id UUID,
  provider_name VARCHAR(255),
  scheduled_date DATE,
  notes TEXT,
  review_note TEXT,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  member_medication_id UUID REFERENCES member_medications(id) ON DELETE SET NULL,
  treatment_plan_id UUID REFERENCES treatment_plans(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_authorization_requests_member_id
  ON authorization_requests(member_id);

CREATE INDEX IF NOT EXISTS idx_authorization_requests_status
  ON authorization_requests(status);

