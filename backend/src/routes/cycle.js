const express = require('express');
const { authenticate } = require('../middleware/auth');
const ctrl = require('../controllers/cycleController');

const router = express.Router();

router.get('/mine', authenticate, ctrl.getMine);
router.post('/', authenticate, ctrl.upsertEntry);
router.delete('/:clientId', authenticate, ctrl.deleteByClientId);

module.exports = router;
