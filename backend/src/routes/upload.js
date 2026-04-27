const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const router = express.Router();

// Create uploads directories
const uploadsDir = path.join(__dirname, '../../uploads/temp');
const logosDir = path.join(__dirname, '../../uploads/logos');

[uploadsDir, logosDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Configure multer for designs
const designStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'design-' + uniqueSuffix + path.extname(file.originalname));
  }
});

// Configure multer for logos
const logoStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, logosDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'logo-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  const allowedMimes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml'];
  if (allowedMimes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Only image files are allowed'));
  }
};

const designUpload = multer({
  storage: designStorage,
  fileFilter,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB max
});

const logoUpload = multer({
  storage: logoStorage,
  fileFilter,
  limits: { fileSize: 5 * 1024 * 1024 } // 5MB max for logos
});

// Upload design endpoint
router.post('/upload-design', designUpload.single('image'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  res.json({
    success: true,
    message: 'Design image uploaded successfully',
    filename: req.file.filename,
    path: `/uploads/temp/${req.file.filename}`,
    size: req.file.size
  });
});

// Upload logo endpoint
router.post('/upload-logo', logoUpload.single('logo'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }

  res.json({
    success: true,
    message: 'Logo uploaded successfully',
    filename: req.file.filename,
    path: `/uploads/logos/${req.file.filename}`,
    url: `https://app.sanlamallianz4u.co.ug/uploads/logos/${req.file.filename}`,
    size: req.file.size
  });
});

// Get uploaded image (for display)
router.get('/design/:filename', (req, res) => {
  const filename = req.params.filename;
  const filepath = path.join(uploadsDir, filename);

  // Security check - prevent directory traversal
  if (!filepath.startsWith(uploadsDir)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  if (fs.existsSync(filepath)) {
    res.sendFile(filepath);
  } else {
    res.status(404).json({ error: 'File not found' });
  }
});

// Get logo
router.get('/logo/:filename', (req, res) => {
  const filename = req.params.filename;
  const filepath = path.join(logosDir, filename);

  // Security check - prevent directory traversal
  if (!filepath.startsWith(logosDir)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  if (fs.existsSync(filepath)) {
    res.sendFile(filepath);
  } else {
    res.status(404).json({ error: 'File not found' });
  }
});

// List uploaded images
router.get('/list-designs', (req, res) => {
  fs.readdir(uploadsDir, (err, files) => {
    if (err) {
      return res.status(500).json({ error: 'Failed to read files' });
    }

    const imageFiles = files.filter(f => /\.(jpg|jpeg|png|webp|gif)$/i.test(f));
    res.json({
      success: true,
      files: imageFiles,
      count: imageFiles.length
    });
  });
});

// List uploaded logos
router.get('/list-logos', (req, res) => {
  fs.readdir(logosDir, (err, files) => {
    if (err) {
      return res.status(500).json({ error: 'Failed to read files' });
    }

    const imageFiles = files.filter(f => /\.(jpg|jpeg|png|webp|gif|svg)$/i.test(f));
    res.json({
      success: true,
      files: imageFiles,
      count: imageFiles.length
    });
  });
});

module.exports = router;
