const express = require('express');
const { body, validationResult } = require('express-validator');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/memberProviderController');

const router = express.Router();

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ message: errors.array()[0].msg });
  next();
};

const providerValidation = [
  body('doctor_name').optional().isString().trim().isLength({ max: 200 }),
  body('doctor_email').optional().isEmail().withMessage('Invalid doctor email'),
  body('doctor_phone').optional().isString().trim().isLength({ max: 20 }),
  body('hospital_id').optional().isUUID().withMessage('Invalid hospital ID'),
];

router.get('/me/provider', authenticate, ctrl.getMyProvider);
router.post('/me/provider', authenticate, providerValidation, validate, ctrl.saveProvider);
router.put('/me/provider', authenticate, providerValidation, validate, ctrl.saveProvider);
router.get('/:memberId/provider', authenticate, requireAdmin, ctrl.getMemberProvider);

module.exports = router;
