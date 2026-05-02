const express = require('express');
const { authenticate } = require('../middleware/auth');
const ctrl = require('../controllers/cardReprintsController');

const router = express.Router();

router.post('/', authenticate, ctrl.create);
router.get('/mine', authenticate, ctrl.listMine);

module.exports = router;
