const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/treatmentPlansController');

const router = express.Router();

const uploadsDir = path.join(__dirname, '../../uploads/treatment-plans');
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `tp-${Date.now()}-${Math.random().toString(36).substr(2, 6)}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 500 * 1024 * 1024 }, // 500 MB (covers large videos)
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase().replace('.', '');
    const allowed = ['jpeg', 'jpg', 'png', 'pdf', 'mp3', 'm4a', 'opus', 'ogg', 'wav', 'webm', 'mp4', 'mov', 'avi'];
    if (allowed.includes(ext)) cb(null, true);
    else cb(new Error(`File type .${ext} is not allowed`));
  },
});

const mediaFields = upload.fields([
  { name: 'document', maxCount: 1 },
  { name: 'photo',    maxCount: 1 },
  { name: 'audio',    maxCount: 1 },
  { name: 'video',    maxCount: 1 },
]);

// Member routes
router.get('/', authenticate, ctrl.getMyTreatmentPlans);
router.post('/', authenticate, mediaFields, ctrl.createTreatmentPlan);
router.put('/:id', authenticate, mediaFields, ctrl.updateTreatmentPlan);

// Admin routes
router.get('/admin/all', authenticate, requireAdmin, ctrl.getAllTreatmentPlans);
router.get('/admin/:memberId', authenticate, requireAdmin, ctrl.getMemberTreatmentPlans);
router.post('/admin', authenticate, requireAdmin, mediaFields, ctrl.adminCreateTreatmentPlan);
router.put('/admin/:id', authenticate, requireAdmin, mediaFields, ctrl.adminUpdateTreatmentPlan);

module.exports = router;
