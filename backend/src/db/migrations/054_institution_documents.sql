-- ============================================================
-- 054_institution_documents.sql
-- Store documents uploaded when adding a new institution.
-- Files are kept on disk; this table tracks metadata.
-- ============================================================

CREATE TABLE IF NOT EXISTS institution_documents (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  institution_id   UUID NOT NULL,
  institution_type VARCHAR(20) NOT NULL CHECK (institution_type IN ('hospital', 'pharmacy')),
  file_name        VARCHAR(255) NOT NULL,
  file_path        TEXT NOT NULL,
  file_size        BIGINT NOT NULL DEFAULT 0,
  mime_type        VARCHAR(150),
  uploaded_by      UUID REFERENCES admins(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_institution_docs_inst
  ON institution_documents (institution_id, institution_type);
