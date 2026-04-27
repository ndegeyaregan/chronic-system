const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const {
  getMemberStats,
  getAppointmentStats,
  getMedicationAdherence,
  getNotificationStats,
  getMemberHealthSummary,
  getLabTestStats,
  getAuthorizationStats,
  getVitalsPopulationStats,
  getTreatmentPlanStats,
  getTopMedications,
  getAlertSeverityStats,
  getMemberGrowthTrend,
  getMemberDemographics,
  getAdherenceTrend,
  getAgeDistribution,
  getPlanTypeDistribution,
  getEmergencyStats,
  getAppointmentQuality,
  getVitalsAlerts,
  getCostSummary,
} = require('../controllers/analyticsController');

// Admin analytics
router.get('/members',            authenticate, requireAdmin, getMemberStats);
router.get('/appointments',       authenticate, requireAdmin, getAppointmentStats);
router.get('/adherence',          authenticate, requireAdmin, getMedicationAdherence);
router.get('/adherence-trend',    authenticate, requireAdmin, getAdherenceTrend);
router.get('/notifications',      authenticate, requireAdmin, getNotificationStats);
router.get('/lab-tests',          authenticate, requireAdmin, getLabTestStats);
router.get('/authorizations',     authenticate, requireAdmin, getAuthorizationStats);
router.get('/vitals-population',  authenticate, requireAdmin, getVitalsPopulationStats);
router.get('/vitals-alerts',      authenticate, requireAdmin, getVitalsAlerts);
router.get('/treatment-plans',    authenticate, requireAdmin, getTreatmentPlanStats);
router.get('/top-medications',    authenticate, requireAdmin, getTopMedications);
router.get('/alert-severity',     authenticate, requireAdmin, getAlertSeverityStats);
router.get('/member-growth',      authenticate, requireAdmin, getMemberGrowthTrend);
router.get('/demographics',       authenticate, requireAdmin, getMemberDemographics);
router.get('/age-distribution',   authenticate, requireAdmin, getAgeDistribution);
router.get('/plan-types',         authenticate, requireAdmin, getPlanTypeDistribution);
router.get('/emergency-stats',    authenticate, requireAdmin, getEmergencyStats);
router.get('/appointment-quality',authenticate, requireAdmin, getAppointmentQuality);
router.get('/cost-summary',       authenticate, requireAdmin, getCostSummary);

// Member analytics
router.get('/my-summary', authenticate, getMemberHealthSummary);

module.exports = router;
