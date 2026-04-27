CREATE TABLE IF NOT EXISTS pharmacies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL,
  address TEXT,
  city VARCHAR(100),
  phone VARCHAR(20),
  email VARCHAR(150),
  contact_person VARCHAR(150),
  working_hours TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE member_medications
  ADD COLUMN IF NOT EXISTS photo_url TEXT,
  ADD COLUMN IF NOT EXISTS audio_url TEXT,
  ADD COLUMN IF NOT EXISTS video_url TEXT,
  ADD COLUMN IF NOT EXISTS pharmacy_id UUID REFERENCES pharmacies(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS refill_interval_days INTEGER,
  ADD COLUMN IF NOT EXISTS next_refill_date DATE,
  ADD COLUMN IF NOT EXISTS refill_reminder_7d_sent BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS refill_reminder_2d_sent BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_pharmacies_city ON pharmacies(city);
CREATE INDEX IF NOT EXISTS idx_member_medications_pharmacy_id ON member_medications(pharmacy_id);
CREATE INDEX IF NOT EXISTS idx_member_medications_next_refill_date ON member_medications(next_refill_date);
