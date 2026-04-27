const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listPharmacies,
  getPharmacy,
  createPharmacy,
  updatePharmacy,
  deletePharmacy,
  getPharmacyMetrics,
} = require('../controllers/pharmaciesController');

const idParam = [param('id').isUUID().withMessage('Invalid ID format')];

const pharmacyBody = [
  body('name').trim().notEmpty().withMessage('Pharmacy name is required').isLength({ max: 255 }).withMessage('Name too long'),
  body('city').trim().notEmpty().withMessage('City is required').isLength({ max: 100 }).withMessage('City too long'),
  body('address').optional().trim().isLength({ max: 500 }).withMessage('Address too long'),
  body('phone').optional().trim().isLength({ max: 50 }).withMessage('Phone too long'),
  body('email').optional({ values: 'falsy' }).isEmail().normalizeEmail().withMessage('Valid email required'),
  body('contact_person').optional().trim().isLength({ max: 255 }).withMessage('Contact person too long'),
  body('working_hours').optional().trim().isLength({ max: 500 }).withMessage('Working hours too long'),
];

router.get('/', authenticate, listPharmacies);
router.get('/metrics', authenticate, requireAdmin, getPharmacyMetrics);
router.get('/:id', authenticate, idParam, validate, getPharmacy);
router.post('/', authenticate, requireAdmin, pharmacyBody, validate, createPharmacy);
router.put('/:id', authenticate, requireAdmin, [...idParam, ...pharmacyBody.map(v => v.optional())], validate, updatePharmacy);
router.delete('/:id', authenticate, requireAdmin, idParam, validate, deletePharmacy);

module.exports = router;
