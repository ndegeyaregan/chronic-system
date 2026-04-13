const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const { listAdmins, createAdmin, updateAdmin, toggleAdminStatus, resetAdminPassword } = require('../controllers/adminsController');

router.get('/', authenticate, requireAdmin, listAdmins);
router.post('/', authenticate, requireAdmin, createAdmin);
router.put('/:id', authenticate, requireAdmin, updateAdmin);
router.patch('/:id/status', authenticate, requireAdmin, toggleAdminStatus);
router.patch('/:id/reset-password', authenticate, requireAdmin, resetAdminPassword);

module.exports = router;
