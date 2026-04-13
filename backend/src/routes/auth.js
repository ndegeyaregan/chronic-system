const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const { body, validationResult } = require('express-validator');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  memberLogin,
  adminLogin,
  createPassword,
  changePassword,
  resetMemberPassword,
  requestPasswordReset,
  verifyOtp,
  resetPassword,
} = require('../controllers/authController');

// Rate limiter: max 10 login attempts per IP per 15 minutes
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many login attempts. Please try again in 15 minutes.' },
});

// Rate limiter for forgot-password: max 5 per IP per 15 minutes
const forgotLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many requests. Please try again in 15 minutes.' },
});

// Validation rules
const memberLoginValidation = [
  body('member_number').optional().trim().notEmpty().withMessage('Member number is required'),
  body('password').notEmpty().withMessage('Password is required')
    .isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
];

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ message: errors.array()[0].msg });
  }
  next();
};

router.post('/login/member', loginLimiter, memberLoginValidation, validate, memberLogin);
router.post('/login/admin', loginLimiter, adminLogin);
router.post('/create-password', authenticate, createPassword);
router.post('/change-password', authenticate, changePassword);
router.post('/admin/reset-member-password', authenticate, requireAdmin, resetMemberPassword);

// ── Forgot Password / OTP flow (public) ────────────────────────────────────
router.post('/forgot-password', forgotLimiter, requestPasswordReset);
router.post('/verify-otp', forgotLimiter, verifyOtp);
router.post('/reset-password', resetPassword);

module.exports = router;
