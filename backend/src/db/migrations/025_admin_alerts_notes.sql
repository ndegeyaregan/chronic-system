-- Add admin note columns to admin_alerts table

ALTER TABLE admin_alerts
ADD COLUMN admin_note TEXT,
ADD COLUMN admin_note_by UUID REFERENCES admins(id),
ADD COLUMN admin_note_at TIMESTAMPTZ;
