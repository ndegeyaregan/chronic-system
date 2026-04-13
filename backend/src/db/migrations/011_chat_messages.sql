-- Migration 011: chat_messages table for member-to-admin chat
CREATE TABLE IF NOT EXISTS chat_messages (
  id           SERIAL PRIMARY KEY,
  member_id    UUID    NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  member_name  TEXT    NOT NULL,
  message      TEXT    NOT NULL,
  is_from_admin BOOLEAN NOT NULL DEFAULT false,
  admin_name   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_member_id ON chat_messages(member_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at);
