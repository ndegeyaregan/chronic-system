const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/alertsController');

const router = express.Router();

// Member reports
router.post('/mood', authenticate, ctrl.reportMoodAlert);
router.post('/pain', authenticate, ctrl.reportPainAlert);
router.post('/psychosocial', authenticate, ctrl.reportPsychosocialAlert);

// Admin reads
router.get('/stats',    authenticate, requireAdmin, ctrl.getAlertStats);
router.get('/export',   authenticate, requireAdmin, ctrl.exportAlertsCsv);
router.get('/',         authenticate, requireAdmin, ctrl.getAdminAlerts);
router.patch('/:id/read', authenticate, requireAdmin, ctrl.markAlertRead);
router.patch('/read-all', authenticate, requireAdmin, ctrl.markAllAlertsRead);

module.exports = router;
