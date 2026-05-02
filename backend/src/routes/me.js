const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticate } = require('../middleware/auth');
const pool = require('../config/db');

// ── Profile picture uploads ──────────────────────────────────────────────────
const profilePicsDir = path.join(__dirname, '../../uploads/profile-pics');
if (!fs.existsSync(profilePicsDir)) {
  fs.mkdirSync(profilePicsDir, { recursive: true });
}

const profilePicStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, profilePicsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '.jpg').toLowerCase();
    const unique = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `member-${req.user.id}-${unique}${ext}`);
  },
});

const profilePicUpload = multer({
  storage: profilePicStorage,
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/heic'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Only image files are allowed'));
  },
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

// GET /api/me/chronic-status
// Returns { isChronic: boolean } — true if the authenticated member has at
// least one entry in member_conditions.
router.get('/chronic-status', authenticate, async (req, res) => {
  try {
    const memberId = req.user.id;
    const result = await pool.query(
      'SELECT 1 FROM member_conditions WHERE member_id = $1 LIMIT 1',
      [memberId],
    );
    return res.json({ isChronic: result.rows.length > 0 });
  } catch (err) {
    console.error('chronic-status error:', err);
    return res.json({ isChronic: false });
  }
});

// POST /api/me/profile-picture — upload a new profile picture (multipart "photo")
router.post(
  '/profile-picture',
  authenticate,
  profilePicUpload.single('photo'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ message: 'No image uploaded' });
      }
      const url = `/uploads/profile-pics/${req.file.filename}`;

      // Delete previous file (best effort) before overwriting.
      const prev = await pool.query(
        'SELECT profile_picture_url FROM members WHERE id = $1',
        [req.user.id],
      );
      const prevUrl = prev.rows[0]?.profile_picture_url;
      if (prevUrl && prevUrl.startsWith('/uploads/profile-pics/')) {
        const prevPath = path.join(__dirname, '../..', prevUrl);
        fs.unlink(prevPath, () => {});
      }

      await pool.query(
        `UPDATE members
            SET profile_picture_url = $1, updated_at = NOW()
          WHERE id = $2`,
        [url, req.user.id],
      );
      return res.json({ profile_picture_url: url });
    } catch (err) {
      console.error('upload profile-picture error:', err);
      return res.status(500).json({ message: 'Failed to upload picture' });
    }
  },
);

// DELETE /api/me/profile-picture — remove existing profile picture
router.delete('/profile-picture', authenticate, async (req, res) => {
  try {
    const prev = await pool.query(
      'SELECT profile_picture_url FROM members WHERE id = $1',
      [req.user.id],
    );
    const prevUrl = prev.rows[0]?.profile_picture_url;
    if (prevUrl && prevUrl.startsWith('/uploads/profile-pics/')) {
      const prevPath = path.join(__dirname, '../..', prevUrl);
      fs.unlink(prevPath, () => {});
    }
    await pool.query(
      `UPDATE members SET profile_picture_url = NULL, updated_at = NOW()
        WHERE id = $1`,
      [req.user.id],
    );
    return res.json({ profile_picture_url: null });
  } catch (err) {
    console.error('delete profile-picture error:', err);
    return res.status(500).json({ message: 'Failed to remove picture' });
  }
});

// GET /api/me/profile-picture — returns { profile_picture_url } for current member
router.get('/profile-picture', authenticate, async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT profile_picture_url FROM members WHERE id = $1',
      [req.user.id],
    );
    return res.json({ profile_picture_url: r.rows[0]?.profile_picture_url || null });
  } catch (err) {
    console.error('get profile-picture error:', err);
    return res.status(500).json({ message: 'Failed to fetch picture' });
  }
});

module.exports = router;
