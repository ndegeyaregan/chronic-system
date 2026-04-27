const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const { getAuditLogs, getMemberAuditLogs } = require('../controllers/auditLogsController');

router.get('/', authenticate, requireAdmin, getAuditLogs);
router.get('/member/:memberId', authenticate, requireAdmin, getMemberAuditLogs);

module.exports = router;
