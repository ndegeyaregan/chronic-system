const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const ctrl = require('../controllers/reportsController');

// Members
router.get('/members/data',         authenticate, requireAdmin, ctrl.getMembersReportData);
router.get('/members',              authenticate, requireAdmin, ctrl.exportMembersReport);

// Authorizations
router.get('/authorizations/data',  authenticate, requireAdmin, ctrl.getAuthorizationsReportData);
router.get('/authorizations',       authenticate, requireAdmin, ctrl.exportAuthorizationsReport);

// Lab Tests
router.get('/lab-tests/data',       authenticate, requireAdmin, ctrl.getLabTestsReportData);
router.get('/lab-tests',            authenticate, requireAdmin, ctrl.exportLabTestsReport);

// Prescriptions (member medications)
router.get('/prescriptions/data',   authenticate, requireAdmin, ctrl.getPrescriptionsReportData);
router.get('/prescriptions',        authenticate, requireAdmin, ctrl.exportPrescriptionsReport);

// Treatment Plans
router.get('/treatment-plans/data', authenticate, requireAdmin, ctrl.getTreatmentPlansReportData);
router.get('/treatment-plans',      authenticate, requireAdmin, ctrl.exportTreatmentPlansReport);

// Appointments
router.get('/appointments/data',    authenticate, requireAdmin, ctrl.getAppointmentsReportData);
router.get('/appointments',         authenticate, requireAdmin, ctrl.exportAppointmentsReport);

// Vitals
router.get('/vitals/data',          authenticate, requireAdmin, ctrl.getVitalsReportData);
router.get('/vitals',               authenticate, requireAdmin, ctrl.exportVitalsReport);

// Conditions Enrollment
router.get('/conditions/data',      authenticate, requireAdmin, ctrl.getConditionsEnrollmentData);
router.get('/conditions',           authenticate, requireAdmin, ctrl.exportConditionsReport);

module.exports = router;
