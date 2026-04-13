const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/notificationsController');

const router = express.Router();

router.get('/', authenticate, ctrl.getMyNotifications);
router.put('/read-all', authenticate, ctrl.markAllRead);
router.put('/:id/read', authenticate, ctrl.markRead);

// Admin portal notification routes
router.get('/admin', authenticate, requireAdmin, ctrl.getAdminNotifications);
router.put('/admin/:id/read', authenticate, requireAdmin, ctrl.markAdminNotificationRead);

router.post('/campaign', authenticate, requireAdmin, ctrl.sendCampaign);
router.get('/logs', authenticate, requireAdmin, ctrl.getNotificationLogs);

module.exports = router;
