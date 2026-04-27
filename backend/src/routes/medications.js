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
  adminUpdateAssignment,
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

const { body, param } = require('express-validator');
const validate = require('../middleware/validate');

const idParam = [param('id').isUUID().withMessage('Invalid ID format')];

const catalogueBody = [
  body('name').trim().notEmpty().withMessage('Medication name is required').isLength({ max: 255 }).withMessage('Name too long'),
  body('generic_name').optional().trim().isLength({ max: 255 }).withMessage('Generic name too long'),
  body('condition_id').optional().isUUID().withMessage('Invalid condition ID format'),
  body('notes').optional().trim().isLength({ max: 2000 }).withMessage('Notes too long'),
];

const assignBody = [
  body('dosage').optional().trim().isLength({ max: 255 }).withMessage('Dosage too long'),
  body('frequency').optional().trim().isLength({ max: 255 }).withMessage('Frequency too long'),
  body('medication_id').optional().isUUID().withMessage('Invalid medication ID format'),
  body('pharmacy_id').optional().isUUID().withMessage('Invalid pharmacy ID format'),
  body('start_date').optional().isISO8601().withMessage('Valid start date required'),
  body('end_date').optional().isISO8601().withMessage('Valid end date required'),
  body('refill_interval_days').optional().isInt({ min: 1, max: 365 }).withMessage('Refill interval must be 1-365 days'),
];

// Public / authenticated
router.get('/admin/overview', authenticate, requireAdmin, getMedicationAdminOverview);
router.post('/admin/assign', authenticate, requireAdmin, uploadFields, [
  body('member_id').isUUID().withMessage('Valid member ID required'),
  ...assignBody,
], validate, assignMedication);
router.get('/', authenticate, listMedications);
router.get('/search', authenticate, searchMedications);

// Admin: manage medication catalogue
router.post('/', authenticate, requireAdmin, catalogueBody, validate, createMedication);
router.put('/:id', authenticate, requireAdmin, [...idParam, ...catalogueBody.map(v => v.optional())], validate, updateMedication);

// Member: personal medication management
router.get('/member/mine', authenticate, listMyMedications);
router.post('/member', authenticate, uploadFields, assignBody, validate, assignMedication);
router.put('/member/:id/stop', authenticate, idParam, validate, stopMedication);
router.delete('/member/:id', authenticate, idParam, validate, deleteMemberMedication);
router.post('/member/log', authenticate, [
  body('member_medication_id').isUUID().withMessage('Valid member medication ID required'),
], validate, logDose);
router.get('/member/logs', authenticate, getDoseLogs);

router.put('/assignment/:id/stop', authenticate, requireAdmin, idParam, validate, adminStopAssignment);
router.put('/assignment/:id', authenticate, requireAdmin, idParam, validate, adminUpdateAssignment);
router.patch('/assignment/:id/refill', authenticate, requireAdmin, idParam, validate, updateAssignmentRefill);
router.get('/admin/assignment/:id/logs', authenticate, requireAdmin, idParam, validate, getAssignmentDoseLogs);

module.exports = router;
