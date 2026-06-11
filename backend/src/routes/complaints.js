const express = require('express');
const rateLimit = require('express-rate-limit');
const ctrl = require('../controllers/complaintsController');

const router = express.Router();

const submitLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many submissions. Please try again later.' },
});

router.post('/', submitLimiter, ctrl.create);

module.exports = router;

