-- Add admin_id column to track which admin booked the appointment
ALTER TABLE IF EXISTS appointments
ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES admins(id) ON DELETE SET NULL;

-- Create index for queries
CREATE INDEX IF NOT EXISTS idx_appointments_admin_id ON appointments(admin_id);
