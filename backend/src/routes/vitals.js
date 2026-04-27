const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const { authenticate } = require('../middleware/auth');
const {
  logVitals,
  getVitalsHistory,
  getLatestVitals,
  logCheckin,
  getCheckins,
} = require('../controllers/vitalsController');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ message: errors.array()[0].msg });
  }
  next();
};

const logVitalsValidation = [
  body('systolic_bp').optional({ nullable: true })
    .isFloat({ min: 40, max: 300 }).withMessage('Systolic BP must be between 40 and 300 mmHg'),
  body('diastolic_bp').optional({ nullable: true })
    .isFloat({ min: 20, max: 200 }).withMessage('Diastolic BP must be between 20 and 200 mmHg'),
  body('blood_sugar_mmol').optional({ nullable: true })
    .isFloat({ min: 1, max: 50 }).withMessage('Blood sugar must be between 1 and 50 mmol/L'),
  body('heart_rate').optional({ nullable: true })
    .isInt({ min: 30, max: 250 }).withMessage('Heart rate must be between 30 and 250 bpm'),
  body('weight_kg').optional({ nullable: true })
    .isFloat({ min: 1, max: 500 }).withMessage('Weight must be between 1 and 500 kg'),
  body('height_cm').optional({ nullable: true })
    .isFloat({ min: 30, max: 280 }).withMessage('Height must be between 30 and 280 cm'),
  body('o2_saturation').optional({ nullable: true })
    .isFloat({ min: 50, max: 100 }).withMessage('O₂ saturation must be between 50 and 100%'),
  body('pain_level').optional({ nullable: true })
    .isInt({ min: 0, max: 10 }).withMessage('Pain level must be between 0 and 10'),
  body('temperature_c').optional({ nullable: true })
    .isFloat({ min: 30, max: 45 }).withMessage('Temperature must be between 30 and 45°C'),
  body('mood').optional({ nullable: true })
    .isIn(['great', 'good', 'okay', 'bad', 'terrible']).withMessage('Mood must be great, good, okay, bad, or terrible'),
];

router.post('/', authenticate, logVitalsValidation, validate, logVitals);
router.get('/', authenticate, getVitalsHistory);
router.get('/latest', authenticate, getLatestVitals);
router.post('/checkin', authenticate, logCheckin);
router.get('/checkins', authenticate, getCheckins);

module.exports = router;
