const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/emergencyController');

const router = express.Router();

router.post('/ambulance', authenticate, ctrl.requestAmbulance);
router.get('/requests', authenticate, requireAdmin, ctrl.getEmergencyRequests);
router.patch('/requests/:id/status', authenticate, requireAdmin, ctrl.updateEmergencyStatus);

module.exports = router;
