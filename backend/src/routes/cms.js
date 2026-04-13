const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listContent,
  getContent,
  createContent,
  updateContent,
  deleteContent,
  publishContent,
} = require('../controllers/cmsController');

// Public / authenticated (listContent handles role-based filtering internally)
router.get('/', authenticate, listContent);
router.get('/:id', authenticate, getContent);

// Admin only
router.post('/', authenticate, requireAdmin, createContent);
router.put('/:id', authenticate, requireAdmin, updateContent);
router.delete('/:id', authenticate, requireAdmin, deleteContent);
router.patch('/:id/publish', authenticate, requireAdmin, publishContent);

module.exports = router;
