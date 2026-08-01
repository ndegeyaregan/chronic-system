const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/cardReprintsController');

const router = express.Router();

router.post('/', authenticate, ctrl.create);
router.get('/mine', authenticate, ctrl.listMine);
router.get('/:id/payment-status', authenticate, ctrl.getPaymentStatus);

// Admin
router.get('/', authenticate, requireAdmin, ctrl.listAll);
router.patch('/:id/status', authenticate, requireAdmin, ctrl.updateStatus);

module.exports = router;
