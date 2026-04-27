-- Add doctor_email column to member_providers table
ALTER TABLE member_providers
  ADD COLUMN IF NOT EXISTS doctor_email VARCHAR(200);
