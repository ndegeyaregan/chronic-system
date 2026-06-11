const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  uploadClaims, listUploads, getUpload, previewUpload, deleteUpload,
} = require('../controllers/claimsAnalysisController');
const { overview, providerDrilldown } = require('../controllers/claimsAnalyticsController');

const router = express.Router();

const tempDir = path.join(__dirname, '../../uploads/claims-tmp');
if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, tempDir),
  filename: (_req, file, cb) => {
    const suffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, 'claims-' + suffix + path.extname(file.originalname));
  },
});

const fileFilter = (_req, file, cb) => {
  const ok = /\.(xlsx|xls|csv)$/i.test(file.originalname);
  if (!ok) return cb(new Error('Only .xlsx, .xls and .csv files are allowed'));
  cb(null, true);
};

const upload = multer({
  storage,
  fileFilter,
  // 250 MB cap — claims files routinely run 50–100 MB.
  limits: { fileSize: 250 * 1024 * 1024 },
});

router.use(authenticate, requireAdmin);

router.get('/', listUploads);
router.post('/', upload.single('file'), uploadClaims);
router.get('/:id', getUpload);
router.get('/:id/preview', previewUpload);
router.get('/:id/analytics/overview', overview);
router.get('/:id/analytics/provider', providerDrilldown);
router.delete('/:id', deleteUpload);

module.exports = router;
