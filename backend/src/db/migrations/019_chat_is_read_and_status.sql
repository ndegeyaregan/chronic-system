-- Add missing is_read column to chat_messages
ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false;

-- Create chat_conversation_status table for tracking open/resolved/escalated conversations
CREATE TABLE IF NOT EXISTS chat_conversation_status (
  member_id  uuid PRIMARY KEY REFERENCES members(id) ON DELETE CASCADE,
  status     varchar(20) NOT NULL DEFAULT 'open',
  updated_at timestamp with time zone NOT NULL DEFAULT NOW()
);
