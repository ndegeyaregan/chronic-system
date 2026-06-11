-- 034_widen_institution_text_columns.sql
-- Sanlam returns phone numbers like "0414-345678 / 0772-123456" and
-- occasionally long postal codes / category labels that overflow the
-- original VARCHAR(20) limits. Widen these to be safe.

ALTER TABLE hospitals  ALTER COLUMN phone       TYPE VARCHAR(100);
ALTER TABLE hospitals  ALTER COLUMN postal_code TYPE VARCHAR(50);
ALTER TABLE hospitals  ALTER COLUMN category    TYPE VARCHAR(50);

ALTER TABLE pharmacies ALTER COLUMN phone       TYPE VARCHAR(100);
ALTER TABLE pharmacies ALTER COLUMN postal_code TYPE VARCHAR(50);
ALTER TABLE pharmacies ALTER COLUMN category    TYPE VARCHAR(50);
