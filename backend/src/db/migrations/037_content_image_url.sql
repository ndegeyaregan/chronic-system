-- 037: Add image_url to CMS content for flyer/banner support
ALTER TABLE content
  ADD COLUMN IF NOT EXISTS image_url TEXT;
