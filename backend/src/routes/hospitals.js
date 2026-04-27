const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listHospitals,
  getHospital,
  createHospital,
  updateHospital,
  deleteHospital,
} = require('../controllers/hospitalsController');

const idParam = [param('id').isUUID().withMessage('Invalid ID format')];

const hospitalBody = [
  body('name').trim().notEmpty().withMessage('Hospital name is required').isLength({ max: 255 }).withMessage('Name too long'),
  body('address').trim().notEmpty().withMessage('Address is required').isLength({ max: 500 }).withMessage('Address too long'),
  body('city').trim().notEmpty().withMessage('City is required').isLength({ max: 100 }).withMessage('City too long'),
  body('type').optional().trim().isLength({ max: 100 }).withMessage('Type too long'),
  body('province').optional().trim().isLength({ max: 100 }).withMessage('Province too long'),
  body('latitude').optional({ values: 'null' }).isFloat({ min: -90, max: 90 }).withMessage('Latitude must be -90 to 90'),
  body('longitude').optional({ values: 'null' }).isFloat({ min: -180, max: 180 }).withMessage('Longitude must be -180 to 180'),
  body('phone').optional().trim().isLength({ max: 50 }).withMessage('Phone too long'),
  body('email').optional({ values: 'falsy' }).isEmail().normalizeEmail().withMessage('Valid email required'),
  body('contact_person').optional().trim().isLength({ max: 255 }).withMessage('Contact person too long'),
  body('working_hours').optional().trim().isLength({ max: 500 }).withMessage('Working hours too long'),
  body('direct_booking_capable').optional().isBoolean().withMessage('direct_booking_capable must be boolean'),
  body('condition_ids').optional().isArray().withMessage('condition_ids must be an array'),
  body('condition_ids.*').optional().isUUID().withMessage('Each condition ID must be a valid UUID'),
];

router.get('/', authenticate, listHospitals);
router.get('/:id', authenticate, idParam, validate, getHospital);
router.post('/', authenticate, requireAdmin, hospitalBody, validate, createHospital);
router.put('/:id', authenticate, requireAdmin, [...idParam, ...hospitalBody.map(v => v.optional())], validate, updateHospital);
router.delete('/:id', authenticate, requireAdmin, idParam, validate, deleteHospital);

module.exports = router;
