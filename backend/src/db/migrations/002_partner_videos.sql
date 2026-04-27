-- ============================================================
-- 002: Partner Videos + Logo Color + Ugandan Gym Seeds
-- ============================================================

ALTER TABLE lifestyle_partners ADD COLUMN IF NOT EXISTS logo_color VARCHAR(7) DEFAULT '#003DA5';

CREATE TABLE IF NOT EXISTS partner_videos (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partner_id    UUID NOT NULL REFERENCES lifestyle_partners(id) ON DELETE CASCADE,
  title         VARCHAR(200) NOT NULL,
  youtube_video_id VARCHAR(20) NOT NULL,
  duration_label VARCHAR(20) DEFAULT '30 min',
  difficulty    VARCHAR(20) DEFAULT 'Beginner',
  category      VARCHAR(50) DEFAULT 'Strength',
  sort_order    INTEGER DEFAULT 0,
  is_active     BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_partner_videos_partner ON partner_videos(partner_id);

-- ── Seed Ugandan gym partners ───────────────────────────────────────────────
INSERT INTO lifestyle_partners (name, type, address, city, province, latitude, longitude, phone, email, website, logo_color) VALUES
('Gold''s Gym Kampala',     'gym', 'Acacia Mall, Kisementi',               'Kampala', 'Central Region', 0.3347000, 32.5901000, '+256 312 264 200', 'info@goldsgymkampala.com',    'https://goldsgym.com',             '#C8A200'),
('Kampala Club Fitness',    'gym', 'Lugard Avenue, Nakasero',              'Kampala', 'Central Region', 0.3209000, 32.5748000, '+256 414 344 711', 'fitness@kampalaclub.org',     'https://kampalaclub.org',          '#003DA5'),
('Planet Fitness Kampala',  'gym', 'Garden City Mall, Kampala Road',      'Kampala', 'Central Region', 0.3284000, 32.5838000, '+256 414 259 000', 'kampala@planetfitness.co.ug', 'https://planetfitness.co.ug',      '#C10016'),
('Total Fitness Club',      'gym', 'Kololo Hill Drive, Kololo',            'Kampala', 'Central Region', 0.3256000, 32.5812000, '+256 782 345 678', 'info@totalfitnessug.com',     'https://totalfitness.co.ug',       '#FF6600'),
('Workout World Ntinda',    'gym', 'Ntinda Shopping Centre, Ntinda',      'Kampala', 'Central Region', 0.3421000, 32.6123000, '+256 701 234 567', 'hello@workoutworld.co.ug',    'https://workoutworld.co.ug',       '#1A7A1A'),
('Fitness World Uganda',    'gym', 'William Street, Kampala CBD',         'Kampala', 'Central Region', 0.3176000, 32.5819000, '+256 772 123 456', 'info@fitnessworldug.com',     'https://fitnessworld.co.ug',       '#7B2CBF'),
('Sheraton Fitness Centre', 'gym', 'Ternan Avenue, Nakasero',             'Kampala', 'Central Region', 0.3163000, 32.5769000, '+256 414 420 000', 'fitness@sheraton-kampala.com','https://marriott.com/klash',       '#1C1C1E'),
('Legends Sports Club',     'gym', 'Bugolobi Club Road, Bugolobi',        'Kampala', 'Central Region', 0.3150000, 32.6012000, '+256 757 456 789', 'info@legendsclub.co.ug',      'https://legendsclub.co.ug',        '#9A6700')
ON CONFLICT DO NOTHING;

-- ── Seed demo videos per gym ───────────────────────────────────────────────
DO $$
DECLARE
  golds_id    UUID; kampala_id UUID; planet_id  UUID; total_id   UUID;
  workout_id  UUID; fitness_id UUID; sheraton_id UUID; legends_id UUID;
BEGIN
  SELECT id INTO golds_id    FROM lifestyle_partners WHERE name = 'Gold''s Gym Kampala';
  SELECT id INTO kampala_id  FROM lifestyle_partners WHERE name = 'Kampala Club Fitness';
  SELECT id INTO planet_id   FROM lifestyle_partners WHERE name = 'Planet Fitness Kampala';
  SELECT id INTO total_id    FROM lifestyle_partners WHERE name = 'Total Fitness Club';
  SELECT id INTO workout_id  FROM lifestyle_partners WHERE name = 'Workout World Ntinda';
  SELECT id INTO fitness_id  FROM lifestyle_partners WHERE name = 'Fitness World Uganda';
  SELECT id INTO sheraton_id FROM lifestyle_partners WHERE name = 'Sheraton Fitness Centre';
  SELECT id INTO legends_id  FROM lifestyle_partners WHERE name = 'Legends Sports Club';

  INSERT INTO partner_videos (partner_id, title, youtube_video_id, duration_label, difficulty, category, sort_order) VALUES
  (golds_id,    '30-Min Full Body Cardio Blast',    'UBMk30rjy0o', '30 min', 'Beginner',     'Cardio',     1),
  (golds_id,    '30-Min Strength Training',          'vc1E5CfRfos', '30 min', 'Intermediate', 'Strength',   2),
  (kampala_id,  'Yoga for Complete Beginners',       'v7AYKMP6rOE', '20 min', 'Beginner',     'Yoga',       1),
  (kampala_id,  'Morning Yoga Flow',                 'RqcOCBb4arc', '30 min', 'Beginner',     'Yoga',       2),
  (planet_id,   '30-Min Full Body HIIT',             'MKmrqcoCZ-M', '30 min', 'Intermediate', 'HIIT',       1),
  (planet_id,   'HIIT for Fat Loss – Full Body',     'TkaYafQ-XC4', '35 min', 'Advanced',     'HIIT',       2),
  (total_id,    '10-Min Ab Blast',                   'ml6cT4AZdqI', '10 min', 'Intermediate', 'Strength',   1),
  (total_id,    '30-Min Strength Training',          'vc1E5CfRfos', '30 min', 'Intermediate', 'Strength',   2),
  (workout_id,  'Jump Rope Cardio Burn',             '4pKly2JojMw', '20 min', 'Intermediate', 'Cardio',     1),
  (workout_id,  'Morning Cardio Kickstart',          'cbKkB3POqaY', '25 min', 'Beginner',     'Cardio',     2),
  (fitness_id,  'Full Body Stretch Routine',         'sTANio_2E0Q', '15 min', 'Beginner',     'Stretching', 1),
  (fitness_id,  'Yoga for Complete Beginners',       'v7AYKMP6rOE', '20 min', 'Beginner',     'Yoga',       2),
  (sheraton_id, 'Morning Yoga Flow',                 'RqcOCBb4arc', '30 min', 'Beginner',     'Yoga',       1),
  (sheraton_id, '30-Min Full Body HIIT',             'MKmrqcoCZ-M', '30 min', 'Intermediate', 'HIIT',       2),
  (legends_id,  '30-Min Full Body Cardio Blast',    'UBMk30rjy0o', '30 min', 'Beginner',     'Cardio',     1),
  (legends_id,  'HIIT for Fat Loss – Full Body',     'TkaYafQ-XC4', '35 min', 'Advanced',     'HIIT',       2);
END $$;
