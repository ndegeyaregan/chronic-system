-- Add admin note columns to admin_alerts table

ALTER TABLE admin_alerts
ADD COLUMN IF NOT EXISTS admin_note TEXT,
ADD COLUMN IF NOT EXISTS admin_note_by UUID REFERENCES admins(id),
ADD COLUMN IF NOT EXISTS admin_note_at TIMESTAMPTZ;
