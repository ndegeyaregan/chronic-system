-- Create schemes table
CREATE TABLE IF NOT EXISTS schemes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL UNIQUE,
  code VARCHAR(20),
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed initial schemes
INSERT INTO schemes (name, code) VALUES
  ('NEMA', 'NEMA'),
  ('URA', 'URA'),
  ('AIRTEL', 'AIRTEL'),
  ('MTN', 'MTN')
ON CONFLICT (name) DO NOTHING;

-- Add scheme_id FK to members (nullable for backward compatibility)
ALTER TABLE members ADD COLUMN IF NOT EXISTS scheme_id UUID REFERENCES schemes(id) ON DELETE SET NULL;

-- Migrate existing plan_type data to scheme_id where possible
UPDATE members m
SET scheme_id = s.id
FROM schemes s
WHERE LOWER(m.plan_type) = LOWER(s.name)
  AND m.scheme_id IS NULL;
