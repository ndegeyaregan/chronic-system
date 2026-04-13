const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listMedications,
  createMedication,
  updateMedication,
  getMedicationAdminOverview,
  assignMedication,
  listMyMedications,
  stopMedication,
  deleteMemberMedication,
  logDose,
  getDoseLogs,
  searchMedications,
  adminStopAssignment,
  updateAssignmentRefill,
  getAssignmentDoseLogs,
} = require('../controllers/medicationsController');

const prescriptionsDir = path.join(__dirname, '../../uploads/prescriptions');
const mediaDir = path.join(__dirname, '../../uploads/media');
if (!fs.existsSync(prescriptionsDir)) fs.mkdirSync(prescriptionsDir, { recursive: true });
if (!fs.existsSync(mediaDir)) fs.mkdirSync(mediaDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dest = file.fieldname === 'prescription' ? prescriptionsDir : mediaDir;
    cb(null, dest);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.bin';
    const prefix = file.fieldname === 'prescription' ? 'rx' :
                   file.fieldname === 'audio' ? 'aud' :
                   file.fieldname === 'video' ? 'vid' : 'img';
    cb(null, `${prefix}-${Date.now()}-${Math.random().toString(36).substr(2, 6)}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 500 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.fieldname === 'prescription') {
      const allowed = /jpeg|jpg|png|pdf/;
      const ok = allowed.test(path.extname(file.originalname).toLowerCase());
      if (ok) cb(null, true); else cb(new Error('Only images and PDFs allowed for prescription'));
    } else {
      cb(null, true); // allow any type for audio/video/photo
    }
  },
});
const uploadFields = upload.fields([
  { name: 'prescription', maxCount: 1 },
  { name: 'audio', maxCount: 1 },
  { name: 'video', maxCount: 1 },
  { name: 'photo', maxCount: 1 },
]);

// Public / authenticated
router.get('/admin/overview', authenticate, requireAdmin, getMedicationAdminOverview);
router.post('/admin/assign', authenticate, requireAdmin, uploadFields, assignMedication);
router.get('/', authenticate, listMedications);
router.get('/search', authenticate, searchMedications);

// Admin: manage medication catalogue
router.post('/', authenticate, requireAdmin, createMedication);
router.put('/:id', authenticate, requireAdmin, updateMedication);

// Member: personal medication management
router.get('/member/mine', authenticate, listMyMedications);
router.post('/member', authenticate, uploadFields, assignMedication);
router.put('/member/:id/stop', authenticate, stopMedication);
router.delete('/member/:id', authenticate, deleteMemberMedication);
router.post('/member/log', authenticate, logDose);
router.get('/member/logs', authenticate, getDoseLogs);

router.put('/assignment/:id/stop', authenticate, requireAdmin, adminStopAssignment);
router.patch('/assignment/:id/refill', authenticate, requireAdmin, updateAssignmentRefill);
router.get('/admin/assignment/:id/logs', authenticate, requireAdmin, getAssignmentDoseLogs);

module.exports = router;
