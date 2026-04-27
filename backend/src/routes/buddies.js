const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listBuddies,
  addBuddy,
  updateBuddy,
  deleteBuddy,
  adminListBuddies,
  adminAddBuddy,
  adminUpdateBuddy,
  adminDeleteBuddy,
} = require('../controllers/buddiesController');

const idParam = [param('id').isUUID().withMessage('Invalid ID format')];
const memberIdParam = [param('memberId').isUUID().withMessage('Invalid member ID format')];
const buddyIdParam = [param('buddyId').isUUID().withMessage('Invalid buddy ID format')];

const buddyBody = [
  body('name').trim().notEmpty().withMessage('Name is required').isLength({ max: 255 }).withMessage('Name too long'),
  body('phone').trim().notEmpty().withMessage('Phone is required').isLength({ max: 50 }).withMessage('Phone too long'),
  body('relationship').optional().trim().isLength({ max: 100 }).withMessage('Relationship too long'),
];

// Member routes
router.get('/', authenticate, listBuddies);
router.post('/', authenticate, buddyBody, validate, addBuddy);
router.put('/:id', authenticate, [...idParam, ...buddyBody], validate, updateBuddy);
router.delete('/:id', authenticate, idParam, validate, deleteBuddy);

// Admin routes
router.get('/admin/:memberId', authenticate, requireAdmin, memberIdParam, validate, adminListBuddies);
router.post('/admin/:memberId', authenticate, requireAdmin, [...memberIdParam, ...buddyBody], validate, adminAddBuddy);
router.put('/admin/buddy/:buddyId', authenticate, requireAdmin, [...buddyIdParam, ...buddyBody], validate, adminUpdateBuddy);
router.delete('/admin/buddy/:buddyId', authenticate, requireAdmin, buddyIdParam, validate, adminDeleteBuddy);

module.exports = router;
