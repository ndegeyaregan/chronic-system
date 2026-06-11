const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const { getAuditLogs, getMemberAuditLogs, getMemberLogins } = require('../controllers/auditLogsController');

router.get('/', authenticate, requireAdmin, getAuditLogs);
router.get('/member-logins', authenticate, requireAdmin, getMemberLogins);
router.get('/member/:memberId', authenticate, requireAdmin, getMemberAuditLogs);

module.exports = router;
