const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/reimbursementsController');

const router = express.Router();

const dir = path.join(__dirname, '../../uploads/reimbursements');
if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, dir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const safeBase = path
      .basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .slice(0, 40);
    cb(
      null,
      `reimb-${Date.now()}-${Math.random().toString(36).substr(2, 6)}-${safeBase}${ext}`
    );
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 15 * 1024 * 1024 }, // 15 MB
  fileFilter: (req, file, cb) => {
    const allowed = /pdf|jpe?g|png|webp|heic|heif/i;
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.test(ext)) cb(null, true);
    else cb(new Error('Only PDF or image files are allowed'));
  },
}).fields([
  { name: 'invoice', maxCount: 1 },
  { name: 'report', maxCount: 1 },
]);

const uploadMiddleware = (req, res, next) => {
  upload(req, res, (err) => {
    if (err) return res.status(400).json({ message: err.message });
    next();
  });
};

router.post('/', authenticate, uploadMiddleware, ctrl.create);
router.get('/mine', authenticate, ctrl.listMine);

// Admin
router.get('/', authenticate, requireAdmin, ctrl.listAll);
router.patch('/:id/status', authenticate, requireAdmin, ctrl.updateStatus);

module.exports = router;
