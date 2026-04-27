const express = require('express');
const router = express.Router();
const multer = require('multer');
const { body, validationResult } = require('express-validator');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  getProfile,
  updateProfile,
  updateConditions,
  listMembers,
  getMemberById,
  uploadMembers,
  toggleMemberStatus,
  exportMembers,
  registerMember,
  adminUpdateMember,
} = require('../controllers/membersController');

const upload = multer({ storage: multer.memoryStorage() });

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ message: errors.array()[0].msg });
  }
  next();
};

const updateProfileValidation = [
  body('email').optional({ checkFalsy: true })
    .isEmail().withMessage('Invalid email address'),
  body('phone').optional({ checkFalsy: true })
    .matches(/^\+?[0-9\s\-()]{7,20}$/).withMessage('Invalid phone number'),
  body('first_name').optional({ checkFalsy: true })
    .trim().isLength({ min: 1, max: 100 }).withMessage('First name must be 1–100 characters'),
  body('last_name').optional({ checkFalsy: true })
    .trim().isLength({ min: 1, max: 100 }).withMessage('Last name must be 1–100 characters'),
];

// Member routes
router.get('/me', authenticate, getProfile);
router.put('/me', authenticate, updateProfileValidation, validate, updateProfile);
router.put('/me/conditions', authenticate, updateConditions);

// Admin routes
router.get('/export', authenticate, requireAdmin, exportMembers);
router.get('/', authenticate, requireAdmin, listMembers);
router.post('/', authenticate, requireAdmin, registerMember);
router.get('/:id', authenticate, requireAdmin, getMemberById);
router.post('/upload', authenticate, requireAdmin, upload.single('file'), uploadMembers);
router.patch('/:id/status', authenticate, requireAdmin, toggleMemberStatus);
router.put('/:id', authenticate, requireAdmin, adminUpdateMember);

module.exports = router;
