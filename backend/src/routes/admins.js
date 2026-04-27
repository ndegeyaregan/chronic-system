const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin, requireSuperAdmin } = require('../middleware/auth');
const { listAdmins, createAdmin, updateAdmin, toggleAdminStatus, resetAdminPassword, getContentAdminPerformance } = require('../controllers/adminsController');

const idParam = [param('id').isUUID().withMessage('Invalid ID format')];
const adminRoles = ['super_admin', 'support_admin', 'content_admin'];

// Public endpoint for reports
router.get('/performance/content-admins', getContentAdminPerformance);
router.get('/', authenticate, requireSuperAdmin, listAdmins);
router.post('/', authenticate, requireSuperAdmin, [
  body('email').isEmail().normalizeEmail().withMessage('Valid email is required'),
  body('first_name').trim().notEmpty().withMessage('First name is required').isLength({ max: 100 }).withMessage('First name too long'),
  body('last_name').trim().notEmpty().withMessage('Last name is required').isLength({ max: 100 }).withMessage('Last name too long'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
  body('role').optional().isIn(adminRoles).withMessage(`Role must be one of: ${adminRoles.join(', ')}`),
], validate, createAdmin);
router.put('/:id', authenticate, requireSuperAdmin, [
  ...idParam,
  body('first_name').optional().trim().isLength({ max: 100 }).withMessage('First name too long'),
  body('last_name').optional().trim().isLength({ max: 100 }).withMessage('Last name too long'),
  body('role').optional().isIn(adminRoles).withMessage(`Role must be one of: ${adminRoles.join(', ')}`),
], validate, updateAdmin);
router.patch('/:id/status', authenticate, requireSuperAdmin, idParam, validate, toggleAdminStatus);
router.patch('/:id/reset-password', authenticate, requireSuperAdmin, idParam, validate, resetAdminPassword);

module.exports = router;
