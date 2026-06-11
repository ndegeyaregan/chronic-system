-- Migration 047: Add is_chronic as a real column on members
-- Previously is_chronic was computed dynamically as EXISTS(member_conditions).
-- Now it is an explicit flag set only by admins via the portal.
-- Members who self-select conditions during onboarding do NOT become chronic
-- until an admin marks them as such.

ALTER TABLE members ADD COLUMN IF NOT EXISTS is_chronic BOOLEAN NOT NULL DEFAULT FALSE;

-- Back-fill: members that already have conditions get is_chronic = true
-- (preserves existing behaviour for members already marked by admins)
UPDATE members m
SET is_chronic = TRUE
WHERE EXISTS (
  SELECT 1 FROM member_conditions mc WHERE mc.member_id = m.id
);
