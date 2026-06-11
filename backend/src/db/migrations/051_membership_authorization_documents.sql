-- Authorization documents issued by Sanlam admins to specific members.
-- Surfaced in the member app on the Membership Card screen.
CREATE TABLE IF NOT EXISTS membership_authorization_documents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id       uuid NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  title           text NOT NULL,
  description     text,
  file_url        text NOT NULL,
  file_name       text,
  mime_type       text,
  file_size       bigint,
  issued_by       uuid REFERENCES admins(id) ON DELETE SET NULL,
  issued_at       timestamptz NOT NULL DEFAULT NOW(),
  created_at      timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_membership_auth_docs_member
  ON membership_authorization_documents (member_id, issued_at DESC);
