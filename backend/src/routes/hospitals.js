const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listHospitals,
  getHospital,
  createHospital,
  updateHospital,
  deleteHospital,
} = require('../controllers/hospitalsController');

router.get('/', authenticate, listHospitals);
router.get('/:id', authenticate, getHospital);
router.post('/', authenticate, requireAdmin, createHospital);
router.put('/:id', authenticate, requireAdmin, updateHospital);
router.delete('/:id', authenticate, requireAdmin, deleteHospital);

module.exports = router;
