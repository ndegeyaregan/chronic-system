-- Allow CMS content to be targeted at a single scheme (corporate).
-- NULL means "all schemes" (general audience).
ALTER TABLE content
  ADD COLUMN IF NOT EXISTS scheme_id UUID REFERENCES schemes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_content_scheme_id ON content(scheme_id);
