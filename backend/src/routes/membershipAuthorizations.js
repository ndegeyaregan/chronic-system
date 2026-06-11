const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/membershipAuthorizationsController');

const docsDir = path.join(__dirname, '../../uploads/membership-authorizations');
if (!fs.existsSync(docsDir)) fs.mkdirSync(docsDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, docsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const safeBase = path.basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 40);
    cb(null, `auth-doc-${Date.now()}-${Math.random().toString(36).substr(2, 6)}-${safeBase}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /pdf|jpe?g|png|webp|heic|heif|docx?/i;
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.test(ext)) cb(null, true);
    else cb(new Error('Only PDF, image or document files are allowed'));
  },
});

// Member self
router.get('/mine', authenticate, ctrl.listMyDocuments);

// Admin
router.get('/', authenticate, requireAdmin, ctrl.listAllDocuments);
router.post('/', authenticate, requireAdmin, upload.single('file'), ctrl.issueDocument);
router.delete('/:id', authenticate, requireAdmin, ctrl.deleteDocument);

module.exports = router;
