const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin, requireSuperAdmin } = require('../middleware/auth');
const { listSchemes, createScheme, updateScheme, deleteScheme, getSchemePerformance } = require('../controllers/schemesController');

const idParam = [param('id').isUUID().withMessage('Invalid ID format')];

// Public endpoints for reports
router.get('/performance/all', getSchemePerformance);
router.get('/', authenticate, listSchemes);
router.post('/', authenticate, requireAdmin, [
  body('name').trim().notEmpty().withMessage('Scheme name is required').isLength({ max: 255 }).withMessage('Name too long'),
  body('code').optional().trim().isLength({ max: 50 }).withMessage('Code too long'),
  body('description').optional().trim().isLength({ max: 1000 }).withMessage('Description too long'),
], validate, createScheme);
router.put('/:id', authenticate, requireAdmin, [
  ...idParam,
  body('name').optional().trim().isLength({ max: 255 }).withMessage('Name too long'),
  body('code').optional().trim().isLength({ max: 50 }).withMessage('Code too long'),
  body('description').optional().trim().isLength({ max: 1000 }).withMessage('Description too long'),
  body('is_active').optional().isBoolean().withMessage('is_active must be boolean'),
], validate, updateScheme);
router.delete('/:id', authenticate, requireAdmin, idParam, validate, deleteScheme);

module.exports = router;
