const express = require('express');
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  listServices,
  createService,
  listInstitutionServicePrices,
  createInstitutionServicePrice,
  updateInstitutionServicePrice,
  compareServiceCosts,
} = require('../controllers/servicePricesController');

const router = express.Router();

router.get('/services', authenticate, listServices);
router.post('/services', authenticate, requireAdmin, createService);
router.get('/compare', authenticate, compareServiceCosts);
router.get('/', authenticate, listInstitutionServicePrices);
router.post('/', authenticate, requireAdmin, createInstitutionServicePrice);
router.put('/:id', authenticate, requireAdmin, updateInstitutionServicePrice);

module.exports = router;
