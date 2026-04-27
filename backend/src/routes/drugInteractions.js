const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/drugInteractionsController');

const router = express.Router();

router.get('/check', authenticate, ctrl.checkInteractions);
router.get('/', authenticate, requireAdmin, ctrl.listInteractions);
router.post('/', authenticate, requireAdmin, ctrl.addInteraction);
router.delete('/:id', authenticate, requireAdmin, ctrl.deleteInteraction);

module.exports = router;
