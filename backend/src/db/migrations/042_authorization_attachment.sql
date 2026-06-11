-- Optional attachment for pre-authorization requests (prescription, document, etc.)
ALTER TABLE authorization_requests
  ADD COLUMN IF NOT EXISTS attachment_url  text,
  ADD COLUMN IF NOT EXISTS attachment_name text;
