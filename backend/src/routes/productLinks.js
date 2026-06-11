const express = require('express');
const router = express.Router();
const { body, param } = require('express-validator');
const validate = require('../middleware/validate');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listProductLinks,
  updateProductLink,
} = require('../controllers/productLinksController');

// Public: mobile login screen fetches the three product-link destinations
// without authentication so the popup works before a user signs in.
router.get('/', listProductLinks);

// Admin: update a single product link by its stable key.
router.put(
  '/:key',
  authenticate,
  requireAdmin,
  [
    param('key').isString().isLength({ min: 1, max: 64 }),
    body('url').isString().trim().notEmpty().withMessage('URL is required'),
    body('label').optional({ nullable: true }).isString().isLength({ max: 120 }),
    body('description').optional({ nullable: true }).isString().isLength({ max: 1000 }),
  ],
  validate,
  updateProductLink,
);

module.exports = router;
