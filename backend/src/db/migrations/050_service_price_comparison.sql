-- ============================================================
-- 050_service_price_comparison.sql
-- Structured service catalog + institution service prices
-- ============================================================

CREATE TABLE IF NOT EXISTS services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(200) NOT NULL UNIQUE,
  category VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS institution_service_prices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id UUID NOT NULL,
  institution_type VARCHAR(20) NOT NULL CHECK (institution_type IN ('hospital', 'pharmacy')),
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  price NUMERIC(14,2) NOT NULL CHECK (price >= 0),
  currency VARCHAR(10) NOT NULL DEFAULT 'UGX',
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  source_price_list_id UUID REFERENCES institution_price_lists(id) ON DELETE SET NULL,
  notes TEXT,
  uploaded_by UUID REFERENCES admins(id),
  updated_by UUID REFERENCES admins(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (institution_id, institution_type, service_id, effective_from, currency)
);

CREATE INDEX IF NOT EXISTS idx_services_name
  ON services (name);

CREATE INDEX IF NOT EXISTS idx_institution_service_prices_service
  ON institution_service_prices (service_id, effective_from DESC);

CREATE INDEX IF NOT EXISTS idx_institution_service_prices_institution
  ON institution_service_prices (institution_id, institution_type, effective_from DESC);
