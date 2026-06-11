const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/cardReprintsController');

const router = express.Router();

const proofDir = path.join(__dirname, '../../uploads/card-reprints');
if (!fs.existsSync(proofDir)) fs.mkdirSync(proofDir, { recursive: true });

const proofStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, proofDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const safeBase = path.basename(file.originalname, ext)
      .replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 40);
    cb(null, `reprint-${Date.now()}-${Math.random().toString(36).substr(2, 6)}-${safeBase}${ext}`);
  },
});
const proofUpload = multer({
  storage: proofStorage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = /jpe?g|png|webp|heic|heif|pdf/i;
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.test(ext)) cb(null, true);
    else cb(new Error('Only image (JPG, PNG, WEBP, HEIC) or PDF files are allowed'));
  },
}).single('paymentProof');

const proofUploadMw = (req, res, next) => {
  const ct = (req.headers['content-type'] || '').toLowerCase();
  if (!ct.startsWith('multipart/form-data')) return next();
  // Multer/busboy needs an explicit boundary parameter — if the client
  // sent the bare 'multipart/form-data' content-type without `; boundary=...`
  // we treat it as a malformed upload instead of letting multer crash.
  if (!/boundary=/.test(ct)) {
    return res.status(400).json({
      message: 'Malformed upload: multipart boundary is missing. Please retry.',
    });
  }
  proofUpload(req, res, (err) => {
    if (err) return res.status(400).json({ message: err.message });
    next();
  });
};

router.post('/', authenticate, proofUploadMw, ctrl.create);
router.get('/mine', authenticate, ctrl.listMine);

// Admin
router.get('/', authenticate, requireAdmin, ctrl.listAll);
router.patch('/:id/status', authenticate, requireAdmin, ctrl.updateStatus);

module.exports = router;
