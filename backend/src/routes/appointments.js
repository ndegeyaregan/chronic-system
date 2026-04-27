const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  createAppointment,
  listMyAppointments,
  updateAppointmentStatus,
  listAllAppointments,
  createAppointmentForMember,
  cancelAppointment,
  confirmAttended,
  markMissed,
} = require('../controllers/appointmentsController');

const appointmentBody = [
  body('hospital_id').isUUID().withMessage('Valid hospital ID required'),
  body('appointment_date').isISO8601().withMessage('Valid appointment date required'),
  body('condition_id').optional().isUUID().withMessage('Invalid condition ID format'),
  body('condition').optional().trim().isLength({ max: 255 }).withMessage('Condition name too long'),
  body('preferred_time').optional().trim().isLength({ max: 50 }).withMessage('Preferred time too long'),
  body('reason').optional().trim().isLength({ max: 1000 }).withMessage('Reason too long'),
];

const idParam = [
  param('id').isUUID().withMessage('Invalid ID format'),
];

// Member routes
router.get('/mine', authenticate, listMyAppointments);
router.post('/', authenticate, appointmentBody, validate, createAppointment);
router.patch('/:id/cancel', authenticate, idParam, validate, cancelAppointment);
router.patch('/:id/attended', authenticate, idParam, validate, confirmAttended);
router.patch('/:id/missed', authenticate, idParam, validate, markMissed);

// Admin routes
router.get('/', authenticate, requireAdmin, listAllAppointments);
router.post('/admin', authenticate, requireAdmin, [
  body('member_id').isUUID().withMessage('Valid member ID required'),
  ...appointmentBody,
], validate, createAppointmentForMember);
router.patch('/:id/status', authenticate, requireAdmin, [
  ...idParam,
  body('status').isIn(['pending', 'confirmed', 'completed', 'cancelled', 'missed', 'rescheduled']).withMessage('Invalid status'),
], validate, updateAppointmentStatus);

module.exports = router;
