const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const {
  listInstitutions,
  sanlamSync,
  suspendInstitution,
  unsuspendInstitution,
  deleteInstitution,
  createInstitution,
} = require('../controllers/institutionsController');

router.get('/', authenticate, listInstitutions);
router.post('/sanlam-sync', sanlamSync); // Public endpoint for syncing
router.post('/', authenticate, createInstitution);
router.post('/:id/suspend', authenticate, suspendInstitution);
router.post('/:id/unsuspend', authenticate, unsuspendInstitution);
router.delete('/:id', authenticate, deleteInstitution);

module.exports = router;
