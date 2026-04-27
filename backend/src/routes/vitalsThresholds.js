const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const controller = require('../controllers/vitalsThresholdsController');

router.get('/', authenticate, requireAdmin, controller.getThresholds);

router.post('/', authenticate, requireAdmin, [
  body('metric').trim().notEmpty().withMessage('Metric is required')
    .isIn(['blood_sugar', 'systolic_bp', 'diastolic_bp', 'heart_rate', 'o2_saturation', 'temperature_c', 'pain_level', 'weight'])
    .withMessage('Invalid metric'),
  body('condition_id').optional({ nullable: true }).isUUID().withMessage('Invalid condition ID'),
  body('min_value').optional({ nullable: true }).isDecimal().withMessage('Min value must be a number'),
  body('max_value').optional({ nullable: true }).isDecimal().withMessage('Max value must be a number'),
], validate, controller.createThreshold);

router.put('/:id', authenticate, requireAdmin, [
  param('id').isUUID().withMessage('Invalid threshold ID'),
  body('metric').trim().notEmpty().withMessage('Metric is required')
    .isIn(['blood_sugar', 'systolic_bp', 'diastolic_bp', 'heart_rate', 'o2_saturation', 'temperature_c', 'pain_level', 'weight'])
    .withMessage('Invalid metric'),
  body('condition_id').optional({ nullable: true }).isUUID().withMessage('Invalid condition ID'),
  body('min_value').optional({ nullable: true }).isDecimal().withMessage('Min value must be a number'),
  body('max_value').optional({ nullable: true }).isDecimal().withMessage('Max value must be a number'),
], validate, controller.updateThreshold);

router.delete('/:id', authenticate, requireAdmin, [
  param('id').isUUID().withMessage('Invalid threshold ID'),
], validate, controller.deleteThreshold);

module.exports = router;
