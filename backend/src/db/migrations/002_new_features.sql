-- Alter member_medications: add start_time and prescription_file_url
ALTER TABLE member_medications
  ADD COLUMN IF NOT EXISTS start_time TIME,
  ADD COLUMN IF NOT EXISTS prescription_file_url TEXT;

-- Alter meal_logs: add photo_url
ALTER TABLE meal_logs
  ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Alter psychosocial_checkins: add mood field
ALTER TABLE psychosocial_checkins
  ADD COLUMN IF NOT EXISTS mood VARCHAR(50);

-- Member providers (attending doctor / hospital)
CREATE TABLE IF NOT EXISTS member_providers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  provider_type VARCHAR(20) NOT NULL CHECK (provider_type IN ('doctor','hospital','both')),
  doctor_name VARCHAR(200),
  doctor_contact VARCHAR(50),
  hospital_id UUID REFERENCES hospitals(id),
  hospital_name VARCHAR(200),
  hospital_address TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lab tests (LFT & KFT)
CREATE TABLE IF NOT EXISTS lab_tests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  test_type VARCHAR(100) NOT NULL,   -- 'liver_function' | 'kidney_function'
  scheduled_date DATE,
  due_date DATE NOT NULL,
  completed_at TIMESTAMPTZ,
  result_file_url TEXT,
  result_notes TEXT,
  status VARCHAR(20) DEFAULT 'pending',  -- pending | completed | overdue
  alert_sent BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Treatment plans
CREATE TABLE IF NOT EXISTS treatment_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  title VARCHAR(300),
  description TEXT,
  document_url TEXT,
  photo_url TEXT,
  audio_url TEXT,
  video_url TEXT,
  cost DECIMAL(12,2),
  currency VARCHAR(10) DEFAULT 'UGX',
  plan_date DATE,
  provider_name VARCHAR(200),
  condition_id UUID REFERENCES conditions(id),
  status VARCHAR(30) DEFAULT 'active',   -- active | completed | cancelled
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Admin alerts (mood, pain, psychosocial)
CREATE TABLE IF NOT EXISTS admin_alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  alert_type VARCHAR(50) NOT NULL,   -- 'mood' | 'pain' | 'psychosocial' | 'emergency'
  severity VARCHAR(20) DEFAULT 'medium',  -- low | medium | high | critical
  value_reported DECIMAL(5,2),
  notes TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  read_by UUID REFERENCES admins(id),
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_alerts_member ON admin_alerts(member_id);
CREATE INDEX IF NOT EXISTS idx_admin_alerts_unread ON admin_alerts(is_read) WHERE is_read = FALSE;

-- Emergency requests (ambulance)
CREATE TABLE IF NOT EXISTS emergency_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  pain_level INTEGER,
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  address TEXT,
  status VARCHAR(30) DEFAULT 'pending',   -- pending | dispatched | resolved | cancelled
  notes TEXT,
  dispatched_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES admins(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_emergency_status ON emergency_requests(status);
