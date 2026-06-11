-- 035_complaints.sql
-- Stores complaints / feedback submitted from the login screen
-- "Facing issues?" link. Submissions are also emailed to
-- it@ug.sanlamallianz.com and sancare@ug.sanlamallianz.com.

CREATE TABLE IF NOT EXISTS complaints (
  id              SERIAL PRIMARY KEY,
  category        VARCHAR(50) NOT NULL,
  description     TEXT NOT NULL,
  email           VARCHAR(160),
  phone           VARCHAR(50),
  member_number   VARCHAR(50),
  email_sent      BOOLEAN DEFAULT FALSE,
  email_error     TEXT,
  status          VARCHAR(20) DEFAULT 'open',
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_complaints_created_at ON complaints (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_complaints_category   ON complaints (category);
CREATE INDEX IF NOT EXISTS idx_complaints_status     ON complaints (status);
