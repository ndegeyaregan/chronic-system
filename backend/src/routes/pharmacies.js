const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listPharmacies,
  getPharmacy,
  createPharmacy,
  updatePharmacy,
  deletePharmacy,
  getPharmacyMetrics,
} = require('../controllers/pharmaciesController');

router.get('/', authenticate, listPharmacies);
router.get('/metrics', authenticate, requireAdmin, getPharmacyMetrics);
router.get('/:id', authenticate, getPharmacy);
router.post('/', authenticate, requireAdmin, createPharmacy);
router.put('/:id', authenticate, requireAdmin, updatePharmacy);
router.delete('/:id', authenticate, requireAdmin, deletePharmacy);

module.exports = router;
