-- Stores the destination URLs surfaced from the "Other Sanlam Allianz Products"
-- card on the mobile login screen. Each row is identified by a stable `key`
-- so the mobile app and admin portal can look them up without relying on row
-- ids. Admins (super admin role) can edit the URL via the portal at any time.
CREATE TABLE IF NOT EXISTS product_links (
  key VARCHAR(64) PRIMARY KEY,
  label VARCHAR(120) NOT NULL,
  description TEXT,
  url TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID
);

-- Seed the three options shown in the login-screen popup.
INSERT INTO product_links (key, label, description, url) VALUES
  ('microinsurance',
   'Micro Insurance',
   'Affordable cover for everyday risks',
   'https://ug.sanlamallianz.com/'),
  ('existing_customer',
   'Existing Customer',
   'Log in to your existing Sanlam Allianz account',
   'https://app.ug.sanlamallianz.com/login'),
  ('other_life_products',
   'Other Life Products',
   'Life cover, education plans & family protection',
   'https://ug.sanlamallianz.com/life-insurance/individuals')
ON CONFLICT (key) DO NOTHING;
