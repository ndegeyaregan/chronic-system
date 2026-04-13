-- ============================================================
-- Sanlam Chronic Care — Full Database Schema
-- ============================================================

-- EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ADMINS
-- ============================================================
CREATE TABLE IF NOT EXISTS admins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'support_admin', -- super_admin | support_admin | content_admin
  is_active BOOLEAN DEFAULT TRUE,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CHRONIC CONDITIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS conditions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(150) UNIQUE NOT NULL,
  description TEXT,
  icon VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MEMBERS
-- ============================================================
CREATE TABLE IF NOT EXISTS members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_number VARCHAR(50) UNIQUE NOT NULL,  -- e.g. 333307-00
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  date_of_birth DATE NOT NULL,
  gender VARCHAR(20),
  email VARCHAR(150),
  phone VARCHAR(20),
  id_number VARCHAR(20),
  plan_type VARCHAR(100),
  password_hash VARCHAR(255),
  is_password_set BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  profile_complete BOOLEAN DEFAULT FALSE,
  fcm_token VARCHAR(255),                    -- Firebase push token
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_members_member_number ON members(member_number);
CREATE INDEX IF NOT EXISTS idx_members_last_name ON members(last_name);

-- ============================================================
-- MEMBER CONDITIONS (many-to-many)
-- ============================================================
CREATE TABLE IF NOT EXISTS member_conditions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  condition_id UUID NOT NULL REFERENCES conditions(id),
  diagnosed_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, condition_id)
);

-- ============================================================
-- MEDICATIONS LIBRARY
-- ============================================================
CREATE TABLE IF NOT EXISTS medications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL,
  generic_name VARCHAR(200),
  dosage_options TEXT[],                     -- ['250mg', '500mg']
  frequency_options TEXT[],                 -- ['Once daily', 'Twice daily']
  condition_id UUID REFERENCES conditions(id),
  interactions TEXT[],
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MEMBER MEDICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS member_medications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  medication_id UUID NOT NULL REFERENCES medications(id),
  dosage VARCHAR(100),
  frequency VARCHAR(100),                   -- e.g. 'Twice daily'
  times TEXT[],                              -- ['08:00','20:00']
  start_date DATE,
  end_date DATE,                             -- script expiry
  reminder_enabled BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MEDICATION DOSE LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS medication_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_medication_id UUID NOT NULL REFERENCES member_medications(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  scheduled_time TIMESTAMPTZ NOT NULL,
  taken_at TIMESTAMPTZ,
  status VARCHAR(20) DEFAULT 'pending',      -- pending | taken | skipped
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VITALS TRACKING
-- ============================================================
CREATE TABLE IF NOT EXISTS vitals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  blood_sugar_mmol DECIMAL(5,2),
  systolic_bp INTEGER,
  diastolic_bp INTEGER,
  heart_rate INTEGER,
  weight_kg DECIMAL(5,2),
  height_cm DECIMAL(5,2),
  o2_saturation DECIMAL(5,2),
  pain_level INTEGER CHECK (pain_level BETWEEN 0 AND 10),
  temperature_c DECIMAL(4,1),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SYMPTOM & MOOD LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_checkins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  checkin_date DATE DEFAULT CURRENT_DATE,
  mood VARCHAR(50),                          -- great | good | okay | bad | terrible
  energy_level INTEGER CHECK (energy_level BETWEEN 1 AND 5),
  symptoms TEXT[],
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(member_id, checkin_date)
);

-- ============================================================
-- HOSPITALS
-- ============================================================
CREATE TABLE IF NOT EXISTS hospitals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL,
  type VARCHAR(100),                         -- public | private | clinic
  address TEXT,
  city VARCHAR(100),
  province VARCHAR(100),
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  phone VARCHAR(20),
  email VARCHAR(150),
  contact_person VARCHAR(150),
  working_hours TEXT,
  specialties TEXT[],
  direct_booking_capable BOOLEAN DEFAULT FALSE,
  booking_api_url VARCHAR(255),
  booking_api_key VARCHAR(255),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hospital conditions served (many-to-many)
CREATE TABLE IF NOT EXISTS hospital_conditions (
  hospital_id UUID NOT NULL REFERENCES hospitals(id) ON DELETE CASCADE,
  condition_id UUID NOT NULL REFERENCES conditions(id),
  PRIMARY KEY (hospital_id, condition_id)
);

-- ============================================================
-- APPOINTMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  hospital_id UUID NOT NULL REFERENCES hospitals(id),
  condition_id UUID REFERENCES conditions(id),
  appointment_date DATE NOT NULL,
  preferred_time VARCHAR(20),
  reason TEXT,
  status VARCHAR(50) DEFAULT 'pending',      -- pending | confirmed | cancelled | completed | rescheduled
  confirmed_date DATE,
  confirmed_time VARCHAR(20),
  cancellation_reason TEXT,
  is_direct_booked BOOLEAN DEFAULT FALSE,    -- true = booked via hospital API
  reminder_24h_sent BOOLEAN DEFAULT FALSE,
  reminder_1h_sent BOOLEAN DEFAULT FALSE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LIFESTYLE — PSYCHOSOCIAL
-- ============================================================
CREATE TABLE IF NOT EXISTS psychosocial_checkins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  checkin_date DATE DEFAULT CURRENT_DATE,
  stress_level INTEGER CHECK (stress_level BETWEEN 1 AND 10),
  anxiety_level INTEGER CHECK (anxiety_level BETWEEN 1 AND 10),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LIFESTYLE — NUTRITION
-- ============================================================
CREATE TABLE IF NOT EXISTS meal_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  log_date DATE DEFAULT CURRENT_DATE,
  meal_type VARCHAR(50),                     -- breakfast | lunch | dinner | snack
  description TEXT,
  calories INTEGER,
  protein_g DECIMAL(6,2),
  carbs_g DECIMAL(6,2),
  fat_g DECIMAL(6,2),
  water_ml INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LIFESTYLE — FITNESS
-- ============================================================
CREATE TABLE IF NOT EXISTS fitness_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  log_date DATE DEFAULT CURRENT_DATE,
  activity_type VARCHAR(100),               -- walking | gym | swimming | cycling
  duration_minutes INTEGER,
  intensity VARCHAR(50),                    -- light | moderate | intense
  steps INTEGER,
  calories_burned INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LIFESTYLE PARTNERS (Gyms, Nutritionists, Counsellors)
-- ============================================================
CREATE TABLE IF NOT EXISTS lifestyle_partners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL,
  type VARCHAR(50) NOT NULL,                -- gym | nutritionist | counsellor
  address TEXT,
  city VARCHAR(100),
  province VARCHAR(100),
  latitude DECIMAL(10,7),
  longitude DECIMAL(10,7),
  phone VARCHAR(20),
  email VARCHAR(150),
  website VARCHAR(255),
  conditions TEXT[],                        -- conditions they support
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATIONS LOG
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE,
  type VARCHAR(100) NOT NULL,               -- medication_reminder | appointment_reminder | alert | campaign
  channel VARCHAR(20) NOT NULL,            -- push | sms | email
  title VARCHAR(255),
  message TEXT,
  status VARCHAR(20) DEFAULT 'pending',    -- pending | sent | delivered | failed
  sent_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  reference_id UUID,                       -- e.g. appointment_id, medication_id
  reference_type VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CONTENT (CMS)
-- ============================================================
CREATE TABLE IF NOT EXISTS content (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title VARCHAR(300) NOT NULL,
  type VARCHAR(50) NOT NULL,               -- article | tip | video
  body TEXT,
  video_url VARCHAR(255),
  condition_id UUID REFERENCES conditions(id),
  category VARCHAR(100),
  tags TEXT[],
  published BOOLEAN DEFAULT FALSE,
  published_at TIMESTAMPTZ,
  scheduled_at TIMESTAMPTZ,
  author_id UUID REFERENCES admins(id),
  views INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VITAL ALERT THRESHOLDS
-- ============================================================
CREATE TABLE IF NOT EXISTS vital_thresholds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  condition_id UUID REFERENCES conditions(id),
  metric VARCHAR(100) NOT NULL,            -- blood_sugar | systolic_bp | heart_rate etc.
  min_value DECIMAL(8,2),
  max_value DECIMAL(8,2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AUDIT LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  actor_id UUID,
  actor_type VARCHAR(20),                  -- admin | member
  action VARCHAR(100) NOT NULL,
  entity VARCHAR(100),
  entity_id UUID,
  details JSONB,
  ip_address VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SEED: DEFAULT CONDITIONS
-- ============================================================
INSERT INTO conditions (name, description) VALUES
('Diabetes', 'Chronic condition affecting blood sugar regulation'),
('Hypertension', 'High blood pressure requiring ongoing management'),
('Asthma', 'Chronic lung condition causing breathing difficulties'),
('Chronic Pain', 'Long-term pain requiring continuous management'),
('Heart Disease', 'Cardiovascular conditions requiring monitoring'),
('COPD', 'Chronic obstructive pulmonary disease'),
('Arthritis', 'Joint inflammation causing pain and stiffness'),
('HIV/AIDS', 'Chronic viral condition requiring antiretroviral therapy'),
('Epilepsy', 'Neurological disorder causing recurrent seizures'),
('Depression & Anxiety', 'Mental health conditions requiring chronic support')
ON CONFLICT (name) DO NOTHING;
