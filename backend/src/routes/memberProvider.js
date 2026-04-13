const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/memberProviderController');

const router = express.Router();

router.get('/me/provider', authenticate, ctrl.getMyProvider);
router.post('/me/provider', authenticate, ctrl.saveProvider);
router.put('/me/provider', authenticate, ctrl.saveProvider);
router.get('/:memberId/provider', authenticate, requireAdmin, ctrl.getMemberProvider);

module.exports = router;
