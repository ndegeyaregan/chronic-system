const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const { getDashboardSummary } = require('../controllers/dashboardController');

router.get('/summary', authenticate, requireAdmin, getDashboardSummary);

module.exports = router;
