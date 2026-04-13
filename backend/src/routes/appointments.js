const express = require('express');
const router = express.Router();
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

// Member routes
router.get('/mine', authenticate, listMyAppointments);
router.post('/', authenticate, createAppointment);
router.patch('/:id/cancel', authenticate, cancelAppointment);
router.patch('/:id/attended', authenticate, confirmAttended);
router.patch('/:id/missed', authenticate, markMissed);

// Admin routes
router.get('/', authenticate, requireAdmin, listAllAppointments);
router.post('/admin', authenticate, requireAdmin, createAppointmentForMember);
router.patch('/:id/status', authenticate, requireAdmin, updateAppointmentStatus);

module.exports = router;
