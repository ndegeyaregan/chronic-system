-- Drug interactions table
CREATE TABLE IF NOT EXISTS drug_interactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  medication_a_id UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  medication_b_id UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  severity VARCHAR(20) NOT NULL DEFAULT 'moderate' CHECK (severity IN ('mild', 'moderate', 'severe', 'contraindicated')),
  description TEXT NOT NULL,
  recommendation TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (medication_a_id, medication_b_id)
);

CREATE INDEX IF NOT EXISTS idx_drug_interactions_a ON drug_interactions(medication_a_id);
CREATE INDEX IF NOT EXISTS idx_drug_interactions_b ON drug_interactions(medication_b_id);

-- Member allergies table
CREATE TABLE IF NOT EXISTS member_allergies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  allergen VARCHAR(200) NOT NULL,
  allergen_type VARCHAR(50) DEFAULT 'drug' CHECK (allergen_type IN ('drug', 'food', 'environmental', 'other')),
  severity VARCHAR(20) DEFAULT 'moderate' CHECK (severity IN ('mild', 'moderate', 'severe', 'life_threatening')),
  reaction TEXT,
  diagnosed_date DATE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_member_allergies_member ON member_allergies(member_id);

-- Medication allergen links (which drugs trigger which allergies)
CREATE TABLE IF NOT EXISTS medication_allergens (
  medication_id UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  allergen VARCHAR(200) NOT NULL,
  PRIMARY KEY (medication_id, allergen)
);

-- Provider-patient messages (extends existing chat for provider-specific messaging)
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS provider_id UUID REFERENCES member_providers(id);
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file'));

-- Adherence analytics cache (materialized daily)
CREATE TABLE IF NOT EXISTS adherence_analytics (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  medication_id UUID REFERENCES medications(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_doses INT DEFAULT 0,
  taken_doses INT DEFAULT 0,
  skipped_doses INT DEFAULT 0,
  missed_doses INT DEFAULT 0,
  adherence_pct NUMERIC(5,2) DEFAULT 0,
  streak_current INT DEFAULT 0,
  streak_longest INT DEFAULT 0,
  computed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_adherence_member ON adherence_analytics(member_id);
CREATE INDEX IF NOT EXISTS idx_adherence_period ON adherence_analytics(period_start, period_end);
