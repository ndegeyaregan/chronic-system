const express = require('express');
const fs = require('fs');
const multer = require('multer');
const path = require('path');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listInstitutions,
  sanlamSync,
  suspendInstitution,
  unsuspendInstitution,
  deleteInstitution,
  createInstitution,
  updateInstitution,
  listInstitutionPriceLists,
  createInstitutionPriceList,
  updateInstitutionPriceList,
  syncInstitutionCopays,
  listInstitutionCopays,
} = require('../controllers/institutionsController');

const uploadDir = path.join(__dirname, '../../uploads/institution-price-lists');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const docsUploadDir = path.join(__dirname, '../../uploads/institution-documents');
if (!fs.existsSync(docsUploadDir)) fs.mkdirSync(docsUploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const safeBase = path
      .basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .slice(0, 60);
    cb(null, `inst-price-${Date.now()}-${Math.random().toString(36).slice(2, 8)}-${safeBase}${ext}`);
  },
});

const docsStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, docsUploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const safeBase = path
      .basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .slice(0, 80);
    cb(null, `inst-doc-${Date.now()}-${Math.random().toString(36).slice(2, 8)}-${safeBase}${ext}`);
  },
});

const allowedMimes = new Set([
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/csv',
]);

const allowedExts = new Set(['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.csv']);

// Allowed types for institution support documents (wider — includes images)
const docAllowedMimes = new Set([
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'image/jpeg', 'image/png', 'image/gif', 'image/webp',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
]);
const docAllowedExts = new Set(['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.gif', '.webp', '.xls', '.xlsx']);

const priceListUpload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 }, // 20MB
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const isAllowedMime = allowedMimes.has(file.mimetype);
    const isAllowedExt = allowedExts.has(ext);
    if (isAllowedMime || isAllowedExt) {
      cb(null, true);
      return;
    }
    cb(new Error('Only Excel, Word, CSV, or PDF files are allowed'));
  },
});

const institutionDocsUpload = multer({
  storage: docsStorage,
  limits: { fileSize: 10 * 1024 * 1024, files: 5 }, // 10MB each, max 5 files
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (docAllowedMimes.has(file.mimetype) || docAllowedExts.has(ext)) {
      cb(null, true);
      return;
    }
    cb(new Error('Only PDF, Word, Excel, or image files are allowed'));
  },
});

const priceListUploadMiddleware = (req, res, next) => {
  priceListUpload.single('priceList')(req, res, (err) => {
    if (err) return res.status(400).json({ message: err.message });
    next();
  });
};

const institutionDocsMiddleware = (req, res, next) => {
  institutionDocsUpload.array('documents', 5)(req, res, (err) => {
    if (err) return res.status(400).json({ message: err.message });
    next();
  });
};

router.get('/', authenticate, listInstitutions);
router.get('/price-lists', authenticate, listInstitutionPriceLists);
router.get('/copays', authenticate, listInstitutionCopays);
router.post('/price-lists', authenticate, priceListUploadMiddleware, createInstitutionPriceList);
router.put('/price-lists/:id', authenticate, priceListUploadMiddleware, updateInstitutionPriceList);
router.post('/sanlam-sync', authenticate, sanlamSync);
router.post('/copays/sync', authenticate, requireAdmin, syncInstitutionCopays);
router.post('/', authenticate, institutionDocsMiddleware, createInstitution);
router.put('/:id', authenticate, requireAdmin, updateInstitution);
router.post('/:id/suspend', authenticate, suspendInstitution);
router.post('/:id/unsuspend', authenticate, unsuspendInstitution);
router.delete('/:id', authenticate, deleteInstitution);

module.exports = router;
