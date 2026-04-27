const express = require('express');
const { body, validationResult } = require('express-validator');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/emergencyController');

const router = express.Router();

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ message: errors.array()[0].msg });
  next();
};

router.post('/ambulance', authenticate, [
  body('latitude').isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
  body('longitude').isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
], validate, ctrl.requestAmbulance);
router.get('/requests', authenticate, requireAdmin, ctrl.getEmergencyRequests);
router.patch('/requests/:id/status', authenticate, requireAdmin, [
  body('status').isIn(['pending', 'dispatched', 'resolved', 'cancelled']).withMessage('Invalid status'),
], validate, ctrl.updateEmergencyStatus);

module.exports = router;
