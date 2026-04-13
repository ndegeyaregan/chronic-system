const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/labTestsController');

const router = express.Router();

const uploadsDir = path.join(__dirname, '../../uploads/lab-results');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `lab-${Date.now()}-${Math.random().toString(36).substr(2, 6)}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|pdf/;
    const ok = allowed.test(path.extname(file.originalname).toLowerCase());
    if (ok) cb(null, true); else cb(new Error('Only images and PDFs allowed'));
  },
});

router.get('/', authenticate, ctrl.getMyLabTests);
router.post('/', authenticate, requireAdmin, ctrl.scheduleLabTest);
router.patch('/:id/complete', authenticate, upload.single('result'), ctrl.completeLabTest);
router.get('/admin/stats', authenticate, requireAdmin, ctrl.getLabTestStats);
router.get('/admin/all', authenticate, requireAdmin, ctrl.getAllLabTests);
router.get('/admin/:memberId', authenticate, requireAdmin, ctrl.getMemberLabTests);
router.patch('/admin/:id/complete', authenticate, requireAdmin, upload.single('result'), ctrl.adminCompleteLabTest);

module.exports = router;
