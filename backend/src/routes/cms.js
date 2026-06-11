const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listContent,
  getContent,
  createContent,
  updateContent,
  deleteContent,
  publishContent,
} = require('../controllers/cmsController');

const idParam = [param('id').isUUID().withMessage('Invalid ID format')];

const contentBody = [
  body('title').trim().notEmpty().withMessage('Title is required').isLength({ max: 255 }).withMessage('Title too long'),
  body('type').isIn(['article', 'tip', 'video', 'guide', 'news']).withMessage('Type must be article, tip, video, guide, or news'),
  body('body').optional().trim().isLength({ max: 50000 }).withMessage('Body too long'),
  body('video_url').optional({ values: 'falsy' }).isURL().withMessage('Valid video URL required'),
  body('image_url').optional({ values: 'falsy' }).isLength({ max: 1000 }).withMessage('Image URL too long'),
  body('condition_id').optional({ values: 'falsy' }).isUUID().withMessage('Invalid condition ID format'),
  body('scheme_id').optional({ values: 'falsy' }).isUUID().withMessage('Invalid scheme ID format'),
  body('category').optional().trim().isLength({ max: 100 }).withMessage('Category too long'),
  body('tags').optional().isArray().withMessage('Tags must be an array'),
  body('published').optional().isBoolean().withMessage('Published must be boolean'),
  body('scheduled_at').optional({ values: 'falsy' }).isISO8601().withMessage('Valid scheduled date required'),
];

// Public / authenticated (listContent handles role-based filtering internally)
router.get('/', authenticate, listContent);
router.get('/:id', authenticate, idParam, validate, getContent);

// Admin only
router.post('/', authenticate, requireAdmin, contentBody, validate, createContent);
router.put('/:id', authenticate, requireAdmin, [...idParam, ...contentBody.map(v => v.optional({ values: 'falsy' }))], validate, updateContent);
router.delete('/:id', authenticate, requireAdmin, idParam, validate, deleteContent);
router.patch('/:id/publish', authenticate, requireAdmin, idParam, validate, publishContent);

module.exports = router;
