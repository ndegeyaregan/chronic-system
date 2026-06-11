-- 046_preauth_events_unique.sql
-- Make (member_no, request_no, status) unique so we can use ON CONFLICT
-- DO NOTHING to dedupe webhook + polled inserts and only notify the
-- member ONCE per status transition (Open / Approved / Rejected).

-- 1. Remove any pre-existing duplicates, keeping the earliest row per tuple.
DELETE FROM preauth_events a
USING preauth_events b
WHERE a.id > b.id
  AND a.member_no  = b.member_no
  AND a.request_no = b.request_no
  AND a.status     = b.status;

-- 2. Enforce uniqueness going forward.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'preauth_events_member_request_status_uk'
  ) THEN
    ALTER TABLE preauth_events
      ADD CONSTRAINT preauth_events_member_request_status_uk
      UNIQUE (member_no, request_no, status);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_preauth_events_request_no
  ON preauth_events(request_no);
