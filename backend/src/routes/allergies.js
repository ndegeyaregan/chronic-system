const express = require('express');
const { body, validationResult } = require('express-validator');
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/allergiesController');

const router = express.Router();

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ message: errors.array()[0].msg });
  next();
};

const allergyValidation = [
  body('allergen').notEmpty().trim().withMessage('Allergen name is required'),
  body('allergen_type').optional().isIn(['drug', 'food', 'environmental', 'other']),
  body('severity').optional().isIn(['mild', 'moderate', 'severe', 'life_threatening']),
];

router.get('/mine', authenticate, ctrl.getMyAllergies);
router.post('/', authenticate, allergyValidation, validate, ctrl.addAllergy);
router.put('/:id', authenticate, allergyValidation, validate, ctrl.updateAllergy);
router.delete('/:id', authenticate, ctrl.deleteAllergy);
router.get('/check', authenticate, ctrl.checkAllergyConflict);
router.get('/member/:memberId', authenticate, requireAdmin, ctrl.getMemberAllergies);

module.exports = router;
