-- Identifies hospitals that have a custom integration (e.g. 'tmr' for TMR Telehealth).
-- NULL means generic direct-booking or admin-approval flow.
ALTER TABLE hospitals
  ADD COLUMN IF NOT EXISTS integration_type VARCHAR(50);

-- Store the reference ID returned by an external booking system.
ALTER TABLE appointments
  ADD COLUMN IF NOT EXISTS external_booking_id VARCHAR(255),
  ADD COLUMN IF NOT EXISTS external_system VARCHAR(50);

-- Tag TMR hospital so the booking engine can route it correctly.
-- This updates any existing hospital whose name contains 'TMR'.
UPDATE hospitals
SET integration_type = 'tmr',
    direct_booking_capable = TRUE
WHERE LOWER(name) LIKE '%tmr%';
