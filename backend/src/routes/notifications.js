const express = require('express');
const { body, param, query } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/notificationsController');

const router = express.Router();

const idParam = [param('id').isUUID().withMessage('Invalid ID format')];

router.get('/', authenticate, [
  query('limit').optional().isInt({ min: 1, max: 200 }).toInt(),
  query('offset').optional().isInt({ min: 0 }).toInt(),
], validate, ctrl.getMyNotifications);
router.put('/read-all', authenticate, ctrl.markAllRead);
router.put('/:id/read', authenticate, idParam, validate, ctrl.markRead);

// Admin portal notification routes
router.get('/admin', authenticate, requireAdmin, [
  query('limit').optional().isInt({ min: 1, max: 200 }).toInt(),
], validate, ctrl.getAdminNotifications);
router.put('/admin/:id/read', authenticate, requireAdmin, idParam, validate, ctrl.markAdminNotificationRead);

router.post('/campaign', authenticate, requireAdmin, [
  body('title').trim().notEmpty().withMessage('Title is required').isLength({ max: 255 }).withMessage('Title too long'),
  body('message').trim().notEmpty().withMessage('Message is required').isLength({ max: 5000 }).withMessage('Message too long'),
  body('channel').isArray({ min: 1 }).withMessage('At least one channel is required'),
  body('channel.*').isIn(['push', 'sms', 'email']).withMessage('Channel must be push, sms, or email'),
  body('condition_id').optional().isUUID().withMessage('Invalid condition ID format'),
], validate, ctrl.sendCampaign);
router.get('/logs', authenticate, requireAdmin, [
  query('limit').optional().isInt({ min: 1, max: 200 }).toInt(),
], validate, ctrl.getNotificationLogs);

module.exports = router;
