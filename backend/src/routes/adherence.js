const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/adherenceController');

const router = express.Router();

router.get('/mine', authenticate, ctrl.getMyAdherence);
router.get('/overview', authenticate, requireAdmin, ctrl.getAdherenceOverview);
router.get('/member/:memberId', authenticate, requireAdmin, ctrl.getMemberAdherence);

module.exports = router;
